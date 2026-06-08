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

function fix_website_permission() {
    local domain owner owner_folder

    run_prompt_or_exit prompt_select_website domain "website_menu"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    set_site_dir_permission --owner "${owner}" --owner_folder "${owner_folder}" --domain "${domain}"
    msg "$ICON_SUCCESS Da cap nhat quyen cho website ${domain}" "green"
    website_menu
}
