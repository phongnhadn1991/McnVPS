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

_is_redis_installed() {
    systemctl is-active redis-server &>/dev/null || systemctl is-active redis &>/dev/null
}

_get_redis_service_name() {
    if systemctl list-units --type=service 2>/dev/null | grep -q 'redis-server'; then
        echo "redis-server"
    else
        echo "redis"
    fi
}

install_redis_server() {
    if _is_redis_installed; then
        msg "${ICON_CHECK} Redis da duoc cai dat va dang chay"
        press_enter_to_continue; return 0
    fi

    msg "$ICON_TOOL Dang cai dat Redis Server..."
    safe_apt_install "redis-server" redis-server

    local redis_conf="/etc/redis/redis.conf"
    if [[ -f "$redis_conf" ]]; then
        # Gioi han RAM su dung
        local mem_total
        mem_total=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo)
        local redis_max_mem=64
        if [[ "$mem_total" -ge 4096 ]]; then
            redis_max_mem=256
        elif [[ "$mem_total" -ge 2048 ]]; then
            redis_max_mem=128
        fi

        sed -i "s/^# maxmemory .*/maxmemory ${redis_max_mem}mb/" "$redis_conf"
        sed -i "s/^maxmemory .*/maxmemory ${redis_max_mem}mb/" "$redis_conf"
        grep -q "^maxmemory " "$redis_conf" || echo "maxmemory ${redis_max_mem}mb" >> "$redis_conf"

        sed -i "s/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/" "$redis_conf"
        sed -i "s/^maxmemory-policy .*/maxmemory-policy allkeys-lru/" "$redis_conf"
        grep -q "^maxmemory-policy " "$redis_conf" || echo "maxmemory-policy allkeys-lru" >> "$redis_conf"
    fi

    local redis_service
    redis_service=$(_get_redis_service_name)
    systemctl enable "$redis_service"
    systemctl restart "$redis_service"

    if _is_redis_installed; then
        msg "${ICON_SUCCESS} Cai dat Redis Server thanh cong! (maxmemory: ${redis_max_mem}MB)"
    else
        msg "${ICON_EXIT} Cai dat Redis Server that bai!"
    fi
    press_enter_to_continue; return 0
}

enable_redis_object_cache() {
    local domain php_version php_user wp_path

    if ! _is_redis_installed; then
        msg "${ICON_EXIT} Redis Server chua duoc cai dat. Vui long cai dat Redis truoc!"
        press_enter_to_continue; return 0
    fi

    run_prompt_or_exit prompt_select_website domain "wp_cache_plugin_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    local settings_file="${WEB_DATA_DIR}/${domain}/.settings.conf"
    # shellcheck disable=SC1090
    source "$settings_file" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    wp_path="/home/${owner_folder}/${domain}/public_html"

    if [[ ! -f "${wp_path}/wp-config.php" ]]; then
        msg "${ICON_EXIT} Khong tim thay WordPress tai ${wp_path}"
        press_enter_to_continue; return 0
    fi

    php_user="$owner"

    # Cai plugin Redis Object Cache qua WP-CLI
    msg "$ICON_TOOL Dang cai plugin Redis Object Cache..."
    sudo -u "$php_user" wp --path="$wp_path" plugin install redis-cache --activate --allow-root 2>/dev/null || \
        wp --path="$wp_path" --allow-root plugin install redis-cache --activate 2>/dev/null

    # Them WP_REDIS_HOST vao wp-config.php neu chua co
    if ! grep -q "WP_REDIS_HOST" "${wp_path}/wp-config.php"; then
        sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i define('WP_REDIS_HOST', '127.0.0.1');\ndefine('WP_REDIS_PORT', 6379);\ndefine('WP_REDIS_DATABASE', 0);\ndefine('WP_REDIS_TIMEOUT', 1);\ndefine('WP_REDIS_READ_TIMEOUT', 1);\n" \
            "${wp_path}/wp-config.php"
    fi

    # Enable Redis cache
    sudo -u "$php_user" wp --path="$wp_path" redis enable --allow-root 2>/dev/null || \
        wp --path="$wp_path" --allow-root redis enable 2>/dev/null

    local redis_status
    redis_status=$(wp --path="$wp_path" --allow-root redis status 2>/dev/null | grep -i "status\|connect")

    msg "${ICON_SUCCESS} Redis Object Cache da duoc kich hoat cho ${GREEN}${domain}${NC}"
    [[ -n "$redis_status" ]] && msg "$redis_status"
    press_enter_to_continue; return 0
}

disable_redis_object_cache() {
    local domain wp_path

    run_prompt_or_exit prompt_select_website domain "wp_cache_plugin_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    local settings_file="${WEB_DATA_DIR}/${domain}/.settings.conf"
    # shellcheck disable=SC1090
    source "$settings_file" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    wp_path="/home/${owner_folder}/${domain}/public_html"

    wp --path="$wp_path" --allow-root redis disable 2>/dev/null

    msg "${ICON_SUCCESS} Da tat Redis Object Cache cho ${GREEN}${domain}${NC}"
    press_enter_to_continue; return 0
}

redis_server_status() {
    if _is_redis_installed; then
        local redis_service
        redis_service=$(_get_redis_service_name)
        msg "${ICON_CHECK} Redis Server dang chay"
        redis-cli info memory 2>/dev/null | grep -E 'used_memory_human|maxmemory_human|mem_fragmentation_ratio'
    else
        msg "${ICON_EXIT} Redis Server chua duoc cai dat hoac khong chay"
    fi
    press_enter_to_continue; return 0
}
