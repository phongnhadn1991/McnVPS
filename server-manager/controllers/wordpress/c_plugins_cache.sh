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

_enable_wp_cache_plugin() {
    local plugin_name conf_file conf_remove domain vhost

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plugin_name) plugin_name="$2"; shift 2 ;;
            --conf_file)   conf_file="$2"; shift 2 ;;
            --conf_remove) conf_remove="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$plugin_name" || -z "$conf_file" || -z "$conf_remove" ]]; then
        msg "$ICON_EXIT enable_wp_cache_plugin error: Thieu tham so bat buoc!"
        exit 1
    fi

    run_prompt_or_exit prompt_select_website domain "wp_cache_plugin_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    vhost="${SITE_ENABLED_DIR}/${domain}.conf"
    if [[ ! -e "$vhost" ]]; then
        msg "$ICON_EXIT Khong tim thay vhost cua website ${domain}"
        exit 1
    fi

    if [[ ! -e "$conf_file" ]]; then
        msg "$ICON_EXIT Khong tim thay file cau hinh ${plugin_name}"
        exit 1
    fi

    if ! grep -q "$(basename "$conf_file")" "$vhost"; then
        if grep -q "$conf_file" "$vhost"; then
            sed -i "/$conf_remove/d" "$vhost"
        fi

        run_or_exit "Them cau hinh ${plugin_name}" \
            sed -i "/#CACHE_PLUGINS/a\    include ${conf_file};" "$vhost"
    fi

    msg "$ICON_SUCCESS ${plugin_name} da duoc kich hoat tren website ${domain}"
    wp_cache_plugin_menu
    press_enter_to_continue; return 0
}

enable_wp_rocket() {
    _enable_wp_cache_plugin \
        --plugin_name "WP Rocket" \
        --conf_file "${NGINX_CONF_DIR}/wp-rocket/conf.d/wp-rocket.conf" \
        --conf_remove "w3-total-cache.conf"
}

enable_w3_total_cache() {
    _enable_wp_cache_plugin \
        --plugin_name "W3 Total Cache" \
        --conf_file "${NGINX_EXTRA_CONF_DIR}/w3-total-cache.conf" \
        --conf_remove "wp-rocket.conf"
}
