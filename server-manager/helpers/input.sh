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

is_valid_domain() {
    [[ "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

is_valid_php_version() {
    local version="$1"
    [[ -x "/usr/sbin/php-fpm${version}" || -x "/usr/bin/php${version}" ]]
}

ask_until_valid() {
    local prompt="$1"
    local validate_func="$2"
    local value=""
    while true; do
        read -rp "$prompt" value
        if "$validate_func" "$value"; then
            echo "$value"
            return
        else
            echo "$ICON_EXIT Du lieu khong hop le, vui long thu lai."
        fi
    done
}
