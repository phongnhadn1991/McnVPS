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

if ! declare -f prompt_select_website >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/prompt.sh"
fi

if ! declare -f nginx_reload >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_nginx.sh"
fi

if ! declare -f clear_opcache >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_php.sh"
fi

if ! declare -f format_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

toggle_wp_config() {
    local constant
    local enable_msg
    local disable_msg
    local enable_prompt
    local disable_prompt
    local callback_menu

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --constant)       constant="$2"; shift 2 ;;
            --enable_msg)     enable_msg="$2"; shift 2 ;;
            --disable_msg)    disable_msg="$2"; shift 2 ;;
            --enable_prompt)  enable_prompt="$2"; shift 2 ;;
            --disable_prompt) disable_prompt="$2"; shift 2 ;;
            --callback_menu)  callback_menu="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$constant" || -z "$enable_msg" || -z "$disable_msg" || -z "$enable_prompt" || -z "$disable_prompt" ]]; then
        msg "$ICON_EXIT Thieu tham so bat buoc!"
        msg "Can truyen: --constant, --enable_msg, --disable_msg, --enable_prompt, --disable_prompt"
        exit 1
    fi

    local domain base_dir
    run_prompt_or_exit prompt_select_website domain "wordpress_sec_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    local current_status
    current_status="$(wp config get "$constant" --allow-root --path="${base_dir}/public_html" 2>/dev/null || echo "0")"

    if [[ "$current_status" == "1" ]]; then
        if prompt_yes_no "$disable_prompt cho website $domain ?"; then
            wp config set "$constant" false --raw --allow-root --path="${base_dir}/public_html"
            # shellcheck disable=SC2154
            clear_opcache "$owner" "$php_version"
            msg "$ICON_SUCCESS $disable_msg: ${domain}" 'green'
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    else
        if prompt_yes_no "$enable_prompt cho website $domain ?"; then
            wp config set "$constant" true --raw --allow-root --path="${base_dir}/public_html"
            # shellcheck disable=SC2154
            clear_opcache "$owner" "$php_version"
            msg "$ICON_SUCCESS $enable_msg: ${domain}" 'green'
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    fi

    if [[ "$constant" == 'DISABLE_WP_CRON' && "$current_status" == "1" ]]; then
        touch "${WP_CRON_DIR}/${domain}"
    else
        rm -f "${WP_CRON_DIR}/${domain}"
    fi

    $callback_menu
}

toggle_wp_vhost() {
    local domain vhost_file conf_file enable_prompt disable_prompt

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --conf_file)      conf_file="$2"; shift 2 ;;
            --enable_prompt)  enable_prompt="$2"; shift 2 ;;
            --disable_prompt) disable_prompt="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$conf_file" || -z "$enable_prompt" || -z "$disable_prompt" ]]; then
        msg "$ICON_EXIT Thieu tham so bat buoc!"
        msg "Can truyen: --conf_file, --enable_prompt, --disable_prompt"
        exit 1
    fi

    run_prompt_or_exit prompt_select_website domain 'wordpress_sec_menu' "$WEB_DATA_DIR" 'd' 'wordpress'
    vhost_file="${SITE_AVAILABLE_DIR}/${domain}.conf"

    if ! grep -q "$conf_file" "$vhost_file"; then
        if ! prompt_yes_no "$enable_prompt"; then
            msg "$ICON_EXIT Huy thao tac"
        else
            run_or_exit "" sed -i "/#BEGIN_WP_SEC/a include /etc/nginx/conf.d/wordpress/$conf_file;" "$vhost_file"
            format_nginx_config "$vhost_file"
            nginx_reload
            msg "${GREEN}$ICON_SUCCESS Thuc hien thanh cong!${NC}" 'green'
        fi
    else
        if ! prompt_yes_no "$disable_prompt"; then
            msg "$ICON_EXIT Huy thao tac"
        else
            run_or_exit "" sed -i "/$conf_file/d" "$vhost_file"
            format_nginx_config "$vhost_file"
            nginx_reload
            msg "${GREEN}$ICON_SUCCESS Thuc hien thanh cong!${NC}" 'green'
        fi
    fi

    wordpress_sec_menu
}
