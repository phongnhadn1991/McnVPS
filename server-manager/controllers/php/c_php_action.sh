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

source "${MENU_DIR}/models/m_php.sh"

php_reload() {
    local php_version
    run_prompt_or_exit prompt_select_php_version php_version "" ""

    reload_specific_php_ver "${php_version}"
    msg "$ICON_SUCCESS Da reload PHP ${php_version} thanh cong" "green"
    php_menu
}

php_restart() {
    local php_version
    run_prompt_or_exit prompt_select_php_version php_version "php_menu" "false"

    if restart_specific_php_ver "$php_version"; then
        msg "$ICON_SUCCESS Da restart PHP ${php_version} thanh cong" "green"
    else
        exit 1
    fi

    php_menu
}

php_stop() {
    local php_version
    run_prompt_or_exit prompt_select_php_version php_version "php_menu" "false"

    systemctl stop php"${php_version}"-fpm
    msg "$ICON_SUCCESS Da restart PHP ${php_version} thanh cong" "green"
    php_menu
}
