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

if ! declare -f delete_file >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/file.sh"
fi

if ! declare -f test_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_nginx.sh"
fi

if ! declare -f delete_vhost >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_vhost.sh"
fi

_rollback_nginx_cache_config() {
    local domain="$1"
    local vhost_file_backup="$2"
    local exit_code="$3"

    if [[ "$exit_code" -eq 0 ]]; then
        press_enter_to_continue; return 0
    fi

    countdown_timer 3 "$ICON_WARNING Da xay ra loi. Dang tien hanh rollback..."

    delete_vhost "${domain}"
    run_or_exit "Phuc hoi cau hinh vhost" mv "${vhost_file_backup}" "${SITE_AVAILABLE_DIR}/${domain}.conf"
    ln -s "${SITE_AVAILABLE_DIR}/${domain}.conf" "${SITE_ENABLED_DIR}/${domain}.conf"
    nginx_reload
    msg "${ICON_SUCCESS} Da phuc hoi cau hinh vhost cho website ${GREEN}${domain}${NC}"
    sleep 3
    nginx_cache_menu
}

_check_cache_plugins() {
     local vhost_file="$1"
     local domain="$2"

     local plugins=(
         "WP-Rocket:wp-rocket.conf"
         "W3 Total Cache:w3-total-cache.conf"
     )

     for entry in "${plugins[@]}"; do
         local plugin="${entry%%:*}"
         local conf="${entry##*:}"

         if grep -q "$conf" "$vhost_file"; then
             msg "${ICON_EXIT} Website $domain dang su dung $plugin. Vui long tắt $plugin truoc khi bat Nginx Cache"
             website_menu
             press_enter_to_continue; return 0
         fi
     done

     press_enter_to_continue; return 0
 }

_enable_nginx_cache() {
    local domain="$1"
    local vhost_file="$2"

    local keys_zone cache_dir owner_folder

    if ! prompt_yes_no "${RED}Ban muon bat Nginx Cache cho website $domain ?${NC}"; then
        msg "${ICON_EXIT} Huy bat Nginx Cache cho website $domain"
        website_menu
    fi

    _check_cache_plugins "$vhost_file" "$domain" || return 1

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    cache_dir="/home/${owner_folder}/${domain}/cache"

    mkdir -p "$cache_dir"
    chown -R nginx:nginx "$cache_dir"

    keys_zone=$(generate_cache_zone "$domain")

    run_or_exit "Them cau hinh Fastcgi Cache" sed -i "/#BEGIN_FASTCGI_CACHE/r ${TEMPLATES_DIR}/nginx/fast-cgi-cache.conf" "$vhost_file"
    run_or_exit "" sed -i "/#INIT_FASTCGI_CACHE/a fastcgi_cache_path ${cache_dir} levels=1:2 keys_zone=${keys_zone}:100m inactive=4h use_temp_path=off" "$vhost_file"
    run_or_exit "" sed -i "s|__CACHE_ZONE__|${keys_zone}|g" "$vhost_file"

    format_nginx_config "$vhost_file"

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        exit 1
    fi
}

_disable_nginx_cache() {
    local domain="$1"
    local vhost_file="$2"

    if ! prompt_yes_no "${RED}Ban muon tat Nginx Cache cho website $domain ?${NC}"; then
        msg "${ICON_EXIT} Huy bat Nginx Cache cho website $domain"
        website_menu
    fi

    run_or_exit "Xoa cau hinh Fastcgi Cache" sed -i '/fastcgi_cache_path/d' "${vhost_file}"
    remove_block_between_flags --file "${vhost_file}" --start_flag "#BEGIN_FASTCGI_CACHE" --end_flag "#END_FASTCGI_CACHE"

    format_nginx_config "$vhost_file"

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        exit 1
    fi
}

nginx_fast_cgi_cache() {
    local domain vhost_file keys_zone cache_dir vhost_file_backup

    run_prompt_or_exit prompt_select_website domain "website_menu"

    vhost_file="${SITE_AVAILABLE_DIR}/${domain}.conf"

    if [ ! -e "$vhost_file" ]; then
        msg "${ICON_EXIT} khong tim thay vhost $domain"
    else
        vhost_file_backup="${vhost_file}.bak.$(date +"%d-%m-%Y")"
        delete_file "$vhost_file_backup"
        cp "$vhost_file" "${vhost_file_backup}"

        trap '_rollback_nginx_cache_config "$domain" "$vhost_file_backup" "$?"' EXIT

        if ! grep -q "fastcgi_cache_path" "$vhost_file"; then
            _enable_nginx_cache "$domain" "$vhost_file"
        else
            _disable_nginx_cache "$domain" "$vhost_file"
        fi

        delete_file "${vhost_file}.bak.$(date +"%d-%m-%Y")"
        nginx_reload
        trap - EXIT
        msg "${ICON_SUCCESS} Thao tac thanh cong"
    fi

    nginx_cache_menu
}

delete_nginx_cache() {
    local domain cache_dir owner_folder

    run_prompt_or_exit prompt_select_website domain "website_menu"

    if ! grep -q "fastcgi_cache_path" "${SITE_AVAILABLE_DIR}/${domain}.conf"; then
        msg "${ICON_EXIT} Website $domain chua duoc kich hoat Nginx Cache"
    else
        # shellcheck disable=SC1090
        source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
            msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
            press_enter_to_continue; return 0
        }

        cache_dir="/home/${owner_folder}/${domain}/cache"

        if [ -d "${cache_dir}" ]; then
            rm -rf "${cache_dir:?}"/*
            nginx_reload
        fi

        msg "${ICON_SUCCESS} Da xoa toan bo cache cho website ${GREEN}${domain}${NC}" 'green'
    fi

    nginx_cache_menu
}
