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

if ! declare -f nginx_reload >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_nginx.sh"
fi

function http_to_https() {
    local domain

    run_prompt_or_exit prompt_select_website domain "website_menu"

    local vhost="${SITE_AVAILABLE_DIR}/${domain}.conf"

    if [ ! -f "$vhost" ]; then
        msg "$ICON_ERROR Khong tim thay file cau hinh vhost cho ${domain}"
        press_enter_to_continue; return 0
    fi

    if ! grep -q 'http_to_https.conf' "$vhost"; then
        if prompt_yes_no 'Ban muon bat redirect HTTP to HTTPs ?'; then
            run_or_exit 'Bat redirect HTTP to HTTPs' \
                    sed -i "/#HTTP_TO_HTTPS/a\    include ${NGINX_EXTRA_CONF_DIR}/http_to_https.conf;" "$vhost"

            systemctl reload nginx
            msg "$ICON_SUCCESS Da bat redirect HTTP to HTTPs cho ${domain}" "green"
        fi
    else
        if prompt_yes_no 'Ban muon tat redirect HTTP to HTTPs ?'; then
            run_or_exit 'Tat redirect HTTP to HTTPs' sed -i '/http_to_https.conf/d' "$vhost"

            systemctl reload nginx
            msg "$ICON_SUCCESS Da tat redirect HTTP to HTTPs cho ${domain}" "green"
        fi
    fi

    nginx_reload || {
        msg "$ICON_ERROR Khong the tai lai cau hinh Nginx. Vui long kiem tra lai!"
        exit 1
    }

    website_menu
}
