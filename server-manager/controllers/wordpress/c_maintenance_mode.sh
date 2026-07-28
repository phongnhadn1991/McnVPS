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

wp_maintenance_mode() {
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

    local current_status
    current_status=$(wp maintenance-mode status --allow-root --path="${public_html}" 2>/dev/null | grep -c "enabled" || echo "0")

    if [[ "$current_status" -gt 0 ]]; then
        if prompt_yes_no "Website ${domain} dang o che do Maintenance. Tat Maintenance mode?"; then
            wp maintenance-mode deactivate --allow-root --path="${public_html}"
            msg "$ICON_SUCCESS Da tat Maintenance mode cho ${domain}" 'green'
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    else
        if prompt_yes_no "Bat Maintenance mode cho website ${domain}?"; then
            wp maintenance-mode activate --allow-root --path="${public_html}"
            msg "$ICON_SUCCESS Da bat Maintenance mode cho ${domain}" 'green'
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    fi

    press_enter_to_continue; return 0
}
