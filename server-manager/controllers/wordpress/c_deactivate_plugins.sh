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

deactivate_plugins() {
    local domain
    local base_dir
    local plugins

    run_prompt_or_exit prompt_select_website domain "wordpress_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    run_prompt_or_exit prompt_select_wordpress_plugins plugins "wordpress_menu" "${base_dir}"

    if prompt_yes_no "Ban muon huy kich hoat plugin $plugins ?"; then
        wp plugin deactivate "$plugins" --path="${base_dir}/public_html" --allow-root
        msg "$ICON_SUCCESS Da huy kich hoat plugin $plugins kich hoat tren website ${domain}"
    else
        msg "$ICON_EXIT Huy thao tac"
    fi

    wordpress_menu
}
