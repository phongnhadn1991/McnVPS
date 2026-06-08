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

source "${MENU_DIR}/models/m_linux_user.sh"
source "${MENU_DIR}/models/m_vhost.sh"
source "${MENU_DIR}/helpers/file.sh"
source "${MENU_DIR}/validate/rule.sh"

_find_all_domains() {
    local all_domains=()
    local domain

    shopt -s nullglob
    for path in "$WEB_DATA_DIR"/*; do
        [[ -d "$path" ]] && all_domains+=("$(basename "$path")")
    done

    for path in /home/*/*; do
        if [ -d "$path" ]; then
            domain="$(basename "$path")"

            if is_valid_domain "$domain"; then
                # shellcheck disable=SC2076
                [[ ! " ${all_domains[*]} " =~ " ${domain} " ]] && all_domains+=("$domain")
            fi
        fi
    done

    for file in "$SITE_AVAILABLE_DIR"/*.conf; do
        domain="$(basename "$file" .conf)"
        if is_valid_domain "$domain"; then
            # shellcheck disable=SC2076
            [[ ! " ${all_domains[*]} " =~ " ${domain} " ]] && all_domains+=("$domain")
        fi
    done

    for pool in "$PHP_BASE_DIR"/*/fpm/pool.d/*.conf; do
        domain="$(basename "$pool" .conf)"
        if is_valid_domain "$domain"; then
            # shellcheck disable=SC2076
            [[ ! " ${all_domains[*]} " =~ " ${domain} " ]] && all_domains+=("$domain")
        fi
    done

    shopt -u nullglob
    echo "${all_domains[@]}"
}

_check_orphaned_websites () {
    SITE_HOME_BASE="/home"
    NGINX_AVAILABLE="/etc/nginx/sites-available"
    NGINX_ENABLED="/etc/nginx/sites-enabled"
    WEBSITE_DATA="/var/mcnvps/data/websites"
    PHP_FPM_POOL_DIR="/etc/php"

    domains_from_home=$(find "$SITE_HOME_BASE" -mindepth 2 -maxdepth 2 -type d -printf "%f\n" 2>/dev/null)
    domains_from_nginx_available=$(find "$NGINX_AVAILABLE" -type f -name "*.conf" -printf "%f\n" 2>/dev/null | sed 's/\.conf$//')
    domains_from_nginx_enabled=$(find "$NGINX_ENABLED" -type l -name "*.conf" \
        -exec sh -c '
            target=$(readlink -f -- "$1") || exit
            case "$target" in
                '"$NGINX_AVAILABLE"'/*) basename "$target" .conf ;;
            esac
        ' sh {} \; 2>/dev/null)
    domains_from_data=$(find "$WEBSITE_DATA" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null)
    domains_from_php=$(find "$PHP_FPM_POOL_DIR" -type f -path "*/fpm/pool.d/*.conf" -printf "%f\n" 2>/dev/null \
        | grep -v '^www\.conf$'  | sed 's/\.conf$//')

    mapfile -t all_domains < <(printf "%s\n%s\n%s\n%s\n%s\n" \
        "$domains_from_home" \
        "$domains_from_nginx_available" \
        "$domains_from_nginx_enabled" \
        "$domains_from_data" \
        "$domains_from_php" \
        | grep -v '^$' | sort -u)

    if [[ ${#all_domains[@]} -eq 0 ]]; then
        msg "${ICON_CHECK} Khong tim thay cau hinh mo coi." "green"
        return 1
    fi

    for domain in "${all_domains[@]}"; do
        if ! is_valid_domain "$domain"; then
            continue
        fi

        local missing='false'

        web_owner_folder=$(generate_web_owner_folder "$domain")
        msg "============================================" 'green'
        msg "$ICON_SEARCH Kiem tra website: $domain" 'green'
        msg "============================================" 'green'

        # 1. Home directory
        if [ ! -d "$SITE_HOME_BASE/$web_owner_folder/$domain" ]; then
            missing='true'
            msg "$ICON_EXIT Thieu thu muc: $SITE_HOME_BASE/$web_owner_folder/$domain"
        fi

        # 2. Nginx available
        if [ ! -f "$NGINX_AVAILABLE/$domain.conf" ]; then
            missing='true'
            msg "$ICON_EXIT Thieu file: $NGINX_AVAILABLE/$domain.conf"
        fi

        # 3. Nginx enabled symlink
        if [ ! -L "$NGINX_ENABLED/$domain.conf" ]; then
            missing='true'
            msg "$ICON_EXIT Thieu symlink: $NGINX_ENABLED/$domain.conf"
        else

            target=$(readlink "$NGINX_ENABLED/$domain.conf")
            if [ "$target" != "$NGINX_AVAILABLE/$domain.conf" ]; then
                missing='true'
                msg "$ICON_EXIT Symlink sai: $NGINX_ENABLED/$domain.conf -> $target"
            fi
        fi

        # 4. settings.conf
        if [ ! -f "$WEBSITE_DATA/$domain/.settings.conf" ]; then
            missing='true'
            msg "$ICON_EXIT Thieu file: $WEBSITE_DATA/$domain/.settings.conf"
        fi

        # 5. PHP pool
        php_pool_found=false
        while IFS= read -r pool_file; do
            if [ -f "$pool_file" ]; then
                php_pool_found=true
                break
            fi
        done < <(find "$PHP_FPM_POOL_DIR" -type f -path "*/fpm/pool.d/$domain.conf" 2>/dev/null)

        if [ "$php_pool_found" == false ]; then
            missing='true'
            msg "$ICON_EXIT Thieu file PHP pool: $PHP_FPM_POOL_DIR/*/fpm/pool.d/$domain.conf"
        fi

        # 6. Linux user
        if [[ "$missing" == 'true' && -e "${WEBSITE_DATA}/${domain}/.settings.conf" ]]; then
            # shellcheck disable=SC1090
            source "${WEBSITE_DATA}/${domain}/.settings.conf"
            if [ -n "$owner" ] && id -u "$owner" &>/dev/null; then
                msg "$ICON_EXIT Linux user orphaned: $owner"
            fi
        fi
    done
}

find_orphaned_config() {
    print_header "$ICON_SEARCH Tim kiem cau hinh website mo coi"
    _check_orphaned_websites
    press_enter_to_continue; return 0
}
