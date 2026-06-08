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

source /var/mcnvps/server-manager/config/variables.sh

if ! declare -f trim >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

if ! declare -f is_valid_domain >/dev/null 2>&1; then
    source "${MENU_DIR}/validate/rule.sh"
fi

run_wp_cron_safely() {
    local domain="$1"
    local wp_cron_path="/wp-cron.php?doing_wp_cron"
    local https_url="https://$domain$wp_cron_path"
    local http_url="http://$domain$wp_cron_path"

    if ! is_valid_domain "$domain" || ! is_domain_points_to_vps "$domain"; then
        return 1
    fi

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || return 1

    # shellcheck disable=SC2154
    if [ ! -e "${base_dir}/public_html/wp-cron.php" ]; then
        return 1
    fi

    local user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'

    if wget -q --timeout=3 --user-agent="$user_agent" --no-check-certificate -O - "$https_url" > /dev/null 2>&1; then
        return 0
    fi

    if wget -q --timeout=3 --user-agent="$user_agent" -O - "$http_url" > /dev/null 2>&1; then
        return 0
    fi

    return 1
}

for domain in /var/mcnvps/data/wp-cron/*; do
    domain=$(basename "$domain")
    domain=$(trim "$domain")

    [[ -z "$domain" ]] && continue

    run_wp_cron_safely "$domain"
done
