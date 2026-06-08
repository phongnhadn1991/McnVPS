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

source "${MENU_DIR}/models/m_ssl.sh"

sign_ssl_free() {
    # shellcheck disable=SC2034
    SSL_NEED_RELOAD_NGINX='false'
    local domain

    run_prompt_or_exit prompt_select_website domain "website_menu" "$SITE_ENABLED_DIR" "f"
    sleep 0.5;

    msg "$ICON_TOOL Bat dau tien trinh ky SSL. Vui long khong thao tac cho toi khi qua trinh ket thuc"
    ssl_process_all_pending_domains --scan-type domain --domains "$domain"
    press_enter_to_continue; return 0
}
