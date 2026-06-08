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

delete_site() {
    clear_screen
    local domain=''
    local confirm_delete_web='n'
    local confirm_delete_db='n'

    run_prompt_or_exit prompt_select_website domain "website_menu"

    if prompt_yes_no "${RED}Ban co muon xoa ca Database khong?${NC}"; then
        confirm_delete_db="y"
    fi

    if prompt_yes_no "${RED}Ban chac chan muon xoa website${NC} ${BLUE}${domain}${NC} ? ${RED}Se khong the phuc hoi neu khong co backup${NC}"; then
        confirm_delete_web="y"
    fi

    if [ "$confirm_delete_web" != 'y' ]; then
        website_menu
        press_enter_to_continue; return 0
    fi

    destroy_website "$domain" "$confirm_delete_db"
    nginx_reload

    echo "Xoa website ${BLUE}${domain}${NC} thanh cong"
    website_menu
}
