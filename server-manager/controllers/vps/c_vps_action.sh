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

if ! declare -f bytes_for_humans >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

if ! declare -f prompt_ssh_port_input >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/prompt.sh"
fi

vps_info(){
    local mem_total mem_free swap_total swap_free cpu_speed cpu_model
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_free=$(awk '/MemFree/ { print $2 }' /proc/meminfo)
    swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    swap_free=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
    cpu_speed="$(awk -F: '/cpu MHz/{print $2}' /proc/cpuinfo | sort | uniq -c | sed -e s'|      ||g' | xargs) MHz";
    cpu_model=$(awk -F: '/model name/{print $2}' /proc/cpuinfo | sort | uniq -c | xargs);

    echo ""
    printf "CPU Speed       : %s\n" "${cpu_speed}"
    printf "CPU Model       : %s\n" "${cpu_model}"
    printf "Core            : %s\n" "$(nproc) core"
    printf "Uptime          : %s\n" "$(uptime | xargs)"
    printf "CPU loading     : %s\n" "$(top -b -n1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
    printf "Ram             : %s\n" "$(bytes_for_humans "${mem_total}") (Con trong: $(bytes_for_humans "${mem_free}"))"
    printf "Swap            : %s\n" "$(bytes_for_humans "${swap_total}") (Con trong: $(bytes_for_humans "${swap_free}") )"
    printf "Disk da su dung : %s\n" "$(df -lh | awk '{if ($6 == "/") { print $5 }}' | head -1 | cut -d'%' -f1)%"
    printf "Inode da su dung: %s\n" "$(df -hi | awk '{if ($6 == "/") { print $5 }}' | head -1 | cut -d'%' -f1)%"
    echo ""
    press_enter_to_continue; return 0
}

vps_find_large_file() {
    msg "$ICON_SEARCH Finding large files in the system..." 'green'

    find /home -type f -print0 | xargs -0 du | sort -n | tail -10 | cut -f2 | xargs -I{} du -sh {}
    find /var/log -type f -print0 | xargs -0 du | sort -n | tail -10 | cut -f2 | xargs -I{} du -sh {}
    find /var/logs -type f -print0 | xargs -0 du | sort -n | tail -10 | cut -f2 | xargs -I{} du -sh {}
    press_enter_to_continue; return 0
}

vps_find_process_occupying_ram_cpu() {
    msg "$ICON_SEARCH Finding processes occupying RAM and CPU..." 'green'
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head
    press_enter_to_continue; return 0
}

vps_change_ssh_port() {
    local new_ssh_port old_ssh_port

    old_ssh_port="$(detect_ssh_port)"
    run_prompt_or_exit prompt_ssh_port_input new_ssh_port "vps_tools_menu"

    if prompt_yes_no "Ban muon doi port SSH thanh $new_ssh_port?"; then
        local ssh_bin="${HVN_BIN_DIR:-/usr/local/bin}/change_ssh_port"
        chmod +x "$ssh_bin"

        if [ ! -e "${ssh_bin}" ]; then
            msg "$ICON_ERROR Khong tim thay bin file: ${ssh_bin}"
            exit 1
        fi

        "${ssh_bin}" "$old_ssh_port" "$new_ssh_port"
    fi

    vps_tools_menu
}

notify_service() {
    local notify_status notify_telegram_bot_token notify_telegram_chat_id
    local global_config_file="${HOSTVN_DIR}/.mcnvps.conf"

    # shellcheck disable=SC1090
    source "${global_config_file}" || {
        msg "$ICON_EXIT Khong the load file cau hinh"
        exit 1
    }

    if [[ -z "$notify_status" || "$notify_status" == 'no' ]]; then
        if prompt_yes_no 'Ban muon bat notify?'; then
            run_prompt_or_exit prompt_telegram_token_input notify_telegram_bot_token "vps_tools_menu"
            run_prompt_or_exit prompt_telegram_chat_id_input notify_telegram_chat_id "vps_tools_menu"
            notify_status='yes'
            msg "$ICON_SUCCESS Notify da duoc bat!" 'green'
        else
            msg "$ICON_EXIT Huy thao tac!" 'red'
        fi
    else
        if prompt_yes_no 'Ban muon tat notify?'; then
            notify_status='no'
            msg "$ICON_SUCCESS Notify da duoc tat!" 'green'
        else
            msg "$ICON_EXIT Huy thao tac!" 'red'
        fi
    fi

    run_or_exit "Update config" update_conf_vars "$global_config_file" \
            "notify_status=${notify_status}" \
            "notify_telegram_chat_id=${notify_telegram_chat_id}" \
            "notify_telegram_bot_token=${notify_telegram_bot_token}"

    if [[ "$notify_status" == 'yes' && -f '/var/mcnvps/server-manager/bin/ssh_notify' ]]; then
        cat >'/etc/profile.d/ssh-notify.sh'<<END
#!/bin/bash

source /var/mcnvps/.mcnvps.conf || {
    press_enter_to_continue; return 0
}

if [[ -z "\$notify_status" || "\$notify_status" == 'no' ]]; then
    press_enter_to_continue; return 0
fi

if [ ! -f '/var/mcnvps/server-manager/bin/ssh_notify' ]; then
    press_enter_to_continue; return 0
fi

chmod +x /var/mcnvps/server-manager/bin/ssh_notify
/var/mcnvps/server-manager/bin/ssh_notify --bot-token "\$notify_telegram_bot_token" --chat-id "\$notify_telegram_chat_id"
END
    else
        rm -f '/etc/profile.d/ssh-notify.sh'
    fi

    vps_tools_menu
    press_enter_to_continue; return 0
}
