#!/bin/bash

##############################################################################################################
#                             Auto Install & Optimize LEMP Stack on Ubuntu                                   #
#                                                                                                            #
#                                    Author: Sanvv - MCN Technical                                        #
#                                        Website: https://mcnvps.net                                          #
#                                                                                                            #
#                                  Please do not remove copyright. Thank!                                    #
#  Copying or using this content for any commercial purpose is strictly prohibited under all circumstances!  #
##############################################################################################################

if ! declare -f is_ssh_login_ok >/dev/null 2>&1; then
    source "${MENU_DIR}/validate/rule.sh"
fi

if ! declare -f prompt_select_backup_scope >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/prompt.sh"
fi

_get_valid_ssh_password() {
    local user host port password
    user="$1"; host="$2"; port="$3"

    while true; do
        run_prompt_or_exit prompt_ssh_password_input password "backup_menu"

        if is_ssh_login_ok --user "$user" --host "$host" --port "$port" --password "$password"; then
            echo "$password"
            return
        fi

        msg "$ICON_EXIT Mat khau khong dung, vui long kiem tra lai"
    done
}

_ensure_ssh_keys() {
    local __result_var=$1
    local pub pri

    if [[ ! -e /root/.ssh/id_rsa.pub && ! -e /root/.ssh/id_ed25519.pub ]]; then
        if ! prompt_yes_no "Ban chua co SSH Key. Ban co muon tao key moi khong?"; then
            msg "$ICON_WARNING Ban can phai co SSH key de su dung phuong thuc xac thuc nay!"
            backup_menu
        fi

        ssh-keygen -t ed25519 -C "root@${IP_ADDRESS}" -f ~/.ssh/id_ed25519 -N ""
        clear
        if [ ! -e /root/.ssh/id_ed25519.pub ]; then
            msg "$ICON_ERROR Tạo SSH key that bai"
            exit 1
        fi
    fi

    if [[ -e /root/.ssh/id_ed25519.pub && -e /root/.ssh/id_ed25519 ]]; then
        pub='/root/.ssh/id_ed25519.pub'
        pri='/root/.ssh/id_ed25519'
    elif [[ -e /root/.ssh/id_rsa.pub && -e /root/.ssh/id_rsa ]]; then
        pub='/root/.ssh/id_rsa.pub'
        pri='/root/.ssh/id_rsa'
    else
        msg "$ICON_ERROR Khong tim thay SSH Key"
        exit 1
    fi

    eval "$__result_var=\"$pub|$pri\""
}

_check_ssh_key_login() {
    local user host port pub
    user="$1"; host="$2"; port="$3"; pub="$4";

    if ! is_ssh_login_ok --user "$user" --host "$host" --port "$port"; then
        clear
        echo; echo
        msg "$ICON_TOOL Them SSH public key duoi day vao file /root/.ssh/authorized_keys"
        msg "tren may chu SFTP sau do tao lai ket noi"
        echo; echo
        cat "$pub"
        echo; echo
        press_enter_to_continue; return 0
    fi
}

_enable_backup() {
    local backup_scope backup_remote_name backup_num
    local bk_sftp_host bk_sftp_username bk_sftp_auth_type bk_sftp_port bk_sftp_password
    local ssh_pri_key_file ssh_pub_key_file
    local telegram_bot_token telegram_chat_id
    local global_config_file='/var/mcnvps/.mcnvps.conf'

    run_prompt_or_exit prompt_select_backup_scope backup_scope "backup_menu"

    if [ "$backup_scope" != 'telegram' ]; then
        run_prompt_or_exit prompt_input_remote_name backup_remote_name "backup_menu"
        run_prompt_or_exit prompt_backup_num_input backup_num "backup_menu"
    fi

    case "$backup_scope" in
        drive)
            msg "$ICON_TOOL Vui long xem huong dan sau: https://blog.hostvn.net/chia-se/ubuntu-huong-dan-backup-du-lieu-len-google-drive-tren-hostvn-scripts.html"
            echo
            rclone config create "$backup_remote_name" drive config_is_local true scope drive use_trash false
            echo
            ;;
        telegram)
            run_prompt_or_exit prompt_telegram_token_input telegram_bot_token "backup_menu"
            run_prompt_or_exit prompt_telegram_chat_id_input telegram_chat_id "backup_menu"
            ;;
        sftp)
            run_prompt_or_exit prompt_select_ssh_auth_type bk_sftp_auth_type "backup_menu"
            run_prompt_or_exit prompt_ssh_host_input bk_sftp_host "backup_menu"
            run_prompt_or_exit prompt_ssh_username_input bk_sftp_username "backup_menu"
            run_prompt_or_exit prompt_ssh_port_input bk_sftp_port "backup_menu"

            if [ "$bk_sftp_auth_type" = 'password' ]; then
                bk_sftp_password=$(_get_valid_ssh_password "$bk_sftp_username" "$bk_sftp_host" "$bk_sftp_port")
            else
                local keys
                _ensure_ssh_keys keys
                ssh_pub_key_file="${keys%%|*}"
                ssh_pri_key_file="${keys##*|}"
                _check_ssh_key_login "$bk_sftp_username" "$bk_sftp_host" "$bk_sftp_port" "$ssh_pub_key_file"
            fi

            check_remote_shell_clean --user "$bk_sftp_username" \
                --host "$bk_sftp_host" \
                --port "$bk_sftp_port" \
                --password "$bk_sftp_password"

            rclone config create "$backup_remote_name" sftp host "$bk_sftp_host" \
                user "$bk_sftp_username" port "$bk_sftp_port" \
                pass "$bk_sftp_password" key_file "$ssh_pri_key_file"
            ;;
    esac

    run_or_exit "Update config" update_conf_vars "$global_config_file" \
        "hvn_backup=yes" \
        "backup_scope=$backup_scope" \
        "backup_remote_name=$backup_remote_name" \
        "backup_num=$backup_num" \
        "telegram_chat_id=$telegram_chat_id" \
        "telegram_bot_token=$telegram_bot_token"

    msg "$ICON_SUCCESS Backup tu dong da duoc bat thanh cong!" 'green'
    backup_menu
}

_disable_backup() {
    if prompt_yes_no 'Ban muon vo hieu hoa backup tu dong ?'; then
        local global_config_file="${HOSTVN_DIR}/.mcnvps.conf"

        run_or_exit "Delete config" update_conf_vars "$global_config_file" \
                "hvn_backup=" \
                "backup_scope=" \
                "backup_remote_name=" \
                "backup_num="

        msg "$ICON_SUCCESS Backup tu dong da duoc tat!" 'green'
    fi

    backup_menu
}

backup_action() {
    local hvn_backup

    source "${HOSTVN_DIR}/.mcnvps.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh"
        exit 1
    }

    if [[ -z "$hvn_backup" || "$hvn_backup" == 'no'  ]]; then
        _enable_backup
    else
        _disable_backup
    fi
}
