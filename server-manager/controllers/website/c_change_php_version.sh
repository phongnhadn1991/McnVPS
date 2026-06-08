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

source "${MENU_DIR}/helpers/prompt.sh"
source "${MENU_DIR}/models/m_website.sh"

php_selector() {
    local domain
    local new_php_version

    msg "$ICON_GLOBE Lua chon Website muon thay doi phien ban PHP"
    run_prompt_or_exit prompt_select_website domain "website_menu"

    msg "$ICON_GLOBE Lua chon phien ban moi"
    run_prompt_or_exit prompt_select_php_version new_php_version "website_menu"

    if [[ -z "$domain" || -z "$new_php_version" ]]; then
        msg "$ICON_EXIT Domain hoac PHP Version khong hop le. Huy hanh dong"
        exit 1
    fi

    file_settings="${WEB_DATA_DIR}/${domain}/.settings.conf"

    # shellcheck disable=SC1090
    source "$file_settings" || {
        trap - EXIT
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    # shellcheck disable=SC2154
    if ! prompt_yes_no "${RED}Ban muon doi phien ban PHP cua website $domain tu${NC} ${BLUE}${php_version}${NC} ${RED}sang${NC} ${BLUE}${new_php_version}${NC} ${RED}?${NC}"; then
        msg "$ICON_EXIT Huy hanh dong"
        press_enter_to_continue; return 0
    fi

    if [ ! -e "${PHP_BASE_DIR}/${php_version}/fpm/pool.d/${domain}.conf" ]; then
        msg "$ICON_EXIT PHP Pool $domain khong ton tai. Huy hanh dong"
        press_enter_to_continue; return 0
    fi

    change_website_php_version "$domain" "${php_version}" "$new_php_version"
    clear_screen
    msg "$ICON_CHECK Thay doi phien ban PHP cho website $domain thanh cong!" 'blue'
    sleep 2
    website_menu
}
