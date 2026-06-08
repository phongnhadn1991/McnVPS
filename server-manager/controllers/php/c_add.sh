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
source "${MENU_DIR}/models/m_php.sh"

add_new_php_ver(){
    local php_new_version

    run_prompt_or_exit prompt_select_new_php_ver php_new_version "php_menu"
    sleep 0.5

    if [ -z "$php_new_version" ]; then
        msg "$ICON_EXIT PHP Version is invalid"
        exit 1
    fi

    if ! prompt_yes_no "Ban muon cai dat PHP $php_new_version?"; then
        msg "$ICON_EXIT Huy cai dat"
        sleep 1
        php_menu
    fi

    install_php "$php_new_version";
}
