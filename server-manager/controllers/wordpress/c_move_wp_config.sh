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

move_wp_config() {
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
    local src="${public_html}/wp-config.php"
    local dest="${base_dir}/wp-config.php"

    if [[ -f "$dest" ]]; then
        msg "$ICON_WARNING wp-config.php da nam o thu muc cha roi (${dest})"
        press_enter_to_continue; return 0
    fi

    if [[ ! -f "$src" ]]; then
        msg "$ICON_EXIT Khong tim thay ${src}"
        press_enter_to_continue; return 0
    fi

    if prompt_yes_no "Di chuyen wp-config.php ra khoi public_html cho ${domain}?"; then
        mv "$src" "$dest"
        chown "${owner}:${owner}" "$dest"
        chmod 600 "$dest"
        msg "$ICON_SUCCESS Da di chuyen wp-config.php thanh cong!" 'green'
        echo "${GREEN}Vi tri moi: ${dest}${NC}"
    else
        msg "$ICON_EXIT Huy thao tac"
    fi

    press_enter_to_continue; return 0
}
