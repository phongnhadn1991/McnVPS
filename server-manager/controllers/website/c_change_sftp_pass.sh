#!/bin/bash

##############################################################################################################
#                             Auto Install & Optimize LEMP Stack on Ubuntu                                   #
#                                                                                                            #
#                                    Author: Sanvv - MCN Technical                                           #
#                                        Website: https://mcnvps.net                                         #
#                                                                                                            #
#                                  Please do not remove copyright. Thank!                                    #
#  Copying or using this content for any commercial purpose is strictly prohibited under all circumstances!  #
##############################################################################################################

change_sftp_password() {
    clear_screen
    local domain base_dir db_name db_user db_pass owner owner_folder php_version
    local sftp_user sftp_pass

    msg "$ICON_GLOBE Chon Website muon doi mat khau SFTP"
    run_prompt_or_exit prompt_select_website domain "website_menu"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    if [[ -z "$sftp_user" ]]; then
        msg "$ICON_EXIT Website ${domain} khong co SFTP user"
        press_enter_to_continue; return 0
    fi

    if ! id "$sftp_user" &>/dev/null; then
        msg "$ICON_EXIT User ${sftp_user} khong ton tai tren he thong"
        press_enter_to_continue; return 0
    fi

    local new_pass
    msg "$ICON_TOOL Nhap mat khau moi cho SFTP user: ${sftp_user}"
    read -rp "Mat khau moi (toi thieu 8 ky tu, bo trong de tu tao): " new_pass

    if [[ -z "$new_pass" ]]; then
        new_pass=$(gen_pass)
        msg "$ICON_SUCCESS Da tu dong tao mat khau" 'green'
    fi

    if [[ ${#new_pass} -lt 8 ]]; then
        msg "$ICON_EXIT Mat khau phai co toi thieu 8 ky tu"
        press_enter_to_continue; return 0
    fi

    chpasswd <<< "${sftp_user}:${new_pass}"

    if [[ $? -eq 0 ]]; then
        update_site_setting_vars "${WEB_DATA_DIR}/${domain}/.settings.conf" "sftp_pass" "${new_pass}"

        echo ""
        msg "$ICON_SUCCESS Doi mat khau SFTP thanh cong!" 'green'
        echo "${GREEN}-----------------------------------${NC}"
        echo "${GREEN}SFTP Host        :${NC} ${RED}${IP_ADDRESS}${NC}"
        echo "${GREEN}SFTP Port        :${NC} ${RED}$(detect_ssh_port)${NC}"
        echo "${GREEN}SFTP User        :${NC} ${RED}${sftp_user}${NC}"
        echo "${GREEN}SFTP Password    :${NC} ${RED}${new_pass}${NC}"
        echo "${GREEN}SFTP Directory   :${NC} ${RED}/${domain}/public_html${NC}"
        echo "${GREEN}-----------------------------------${NC}"
    else
        msg "$ICON_EXIT Doi mat khau that bai"
    fi

    press_enter_to_continue; return 0
}
