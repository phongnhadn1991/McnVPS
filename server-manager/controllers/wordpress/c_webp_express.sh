#!/bin/bash

##############################################################################################################
#                             Auto Install & Optimize LEMP Stack on Ubuntu                                   #
#                                                                                                            #
#                                    Author: Sanvv - MCN Technical                                           #
#                                        Website: https://mcnvps.net                                         #
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

webp_express() {
    clear_screen
    local domain base_dir owner php_version

    msg "$ICON_GLOBE Chon WordPress Website"
    run_prompt_or_exit prompt_select_website domain "wordpress_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    local public_html="${base_dir}/public_html"

    if [[ ! -f "${public_html}/wp-config.php" && ! -f "${base_dir}/wp-config.php" ]]; then
        msg "$ICON_EXIT Khong tim thay wp-config.php cho ${domain}"
        press_enter_to_continue; return 0
    fi

    local plugin_status
    plugin_status=$(wp plugin list --allow-root --path="${public_html}" --format=csv 2>/dev/null | grep "webp-express" || echo "")

    if [[ -n "$plugin_status" ]] && echo "$plugin_status" | grep -q "active"; then
        if prompt_yes_no "WebP Express dang bat cho ${domain}. Tat WebP Express?"; then
            wp plugin deactivate webp-express --allow-root --path="${public_html}" 2>/dev/null
            msg "$ICON_SUCCESS Da tat WebP Express cho ${domain}" 'green'
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    else
        if prompt_yes_no "Cai dat va kich hoat WebP Express cho ${domain}?"; then
            msg "$ICON_TOOL Dang cai dat WebP Express..."

            if ! command -v cwebp &>/dev/null; then
                apt-get install -y webp >/dev/null 2>&1
            fi

            wp plugin install webp-express --activate --allow-root --path="${public_html}" 2>/dev/null

            if wp plugin is-active webp-express --allow-root --path="${public_html}" 2>/dev/null; then
                find "${public_html}/wp-content/plugins/webp-express" -type d -exec chmod 0755 {} \; 2>/dev/null
                find "${public_html}/wp-content/plugins/webp-express" -type f -exec chmod 0644 {} \; 2>/dev/null
                chown -R "${owner}:${owner}" "${public_html}/wp-content/plugins/webp-express" 2>/dev/null

                msg "$ICON_SUCCESS Da cai dat va kich hoat WebP Express cho ${domain}" 'green'
                echo "${GREEN}Luu y: Vao WordPress Dashboard > Settings > WebP Express de cau hinh${NC}"
            else
                msg "$ICON_EXIT Cai dat WebP Express that bai"
            fi
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    fi

    press_enter_to_continue; return 0
}
