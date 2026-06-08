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
source "${MENU_DIR}/models/m_nginx.sh"

change_domain_website() {
    clear_screen
    local old_domain=''
    local new_domain=''
    local confirm_change_domain='n'

    msg "$ICON_GLOBE Lua chon Website muon doi ten mien"
    run_prompt_or_exit prompt_select_website old_domain "website_menu"

    msg "Nhap ten mien moi ban muon su dung"
    run_prompt_or_exit prompt_domain_input new_domain "website_menu"

    if prompt_yes_no "${RED}Ban muon doi ten mien tu${NC} ${BLUE}${old_domain}${NC} ${RED}sang${NC} ${BLUE}${new_domain}${NC} ${RED}?${NC}"; then
        confirm_change_domain="y"
    fi

    if [ "$confirm_change_domain" != 'y' ]; then
        website_menu
        press_enter_to_continue; return 0
    fi

    change_website_domain "$old_domain" "$new_domain"
    nginx_reload

    msg "$ICON_CHECK Thay doi ten mien thanh cong: ${old_domain} -> ${new_domain}" "green"
    press_enter_to_continue; return 0
}
