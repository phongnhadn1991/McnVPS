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

if ! declare -f prompt_select_website >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/prompt.sh"
fi

if ! declare -f clear_opcache >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_php.sh"
fi

clear_php_opcache() {
    local domain

    msg "$ICON_TOOL Lua chon website ban muon clear opcache" "green"
    run_prompt_or_exit prompt_select_website domain "website_menu"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    # shellcheck disable=SC2154
    clear_opcache "$owner" "$php_version"
    msg "$ICON_SUCCESS Clear opcache thanh cong" 'green'
    website_menu
}
