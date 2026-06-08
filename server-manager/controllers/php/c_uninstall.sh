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

fore_remove_php() {
    local php_version

    run_prompt_or_exit prompt_select_php_version php_version "php_menu" 'false'
    sleep 0.5

    if [ -z "$php_version" ]; then
        msg "$ICON_EXIT PHP Version is invalid"
        exit 1
    fi

    if is_php_version_in_use "${php_version}"; then
        msg "$ICON_EXIT Khong the go bo PHP ${php_version} do dang co cac website sau su dung: ${PHP_IN_USER_REPLY}"
        exit 1
    fi

    if ! prompt_yes_no "Ban muon go bo phien ban PHP $php_version. Tat ca cac cau hinh se bi mat ?"; then
        msg "$ICON_EXIT Huy hanh dong"
        sleep 1
        php_menu
    fi

    uninstall_php "$php_version"

    PHP_CLI_MAJOR_VERSION=$(php -r 'echo PHP_MAJOR_VERSION;')
    PHP_CLI_MINOR_VERSION=$(php -r 'echo PHP_MINOR_VERSION;')
    PHP_CLI_VERSION="${PHP_CLI_MAJOR_VERSION}.${PHP_CLI_MINOR_VERSION}"

    sed -i "s|php${php_version}-fpm.sock|php${PHP_CLI_VERSION}-fpm.sock|g" '/etc/nginx/nginx-vhosts.conf'

    clear_screen
    msg "$ICON_CHECK Go bo PHP $php_version thanh cong!" 'green'
    press_enter_to_continue; return 0
}
