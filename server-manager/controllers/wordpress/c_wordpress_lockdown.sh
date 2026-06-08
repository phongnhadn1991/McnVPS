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

source "${MENU_DIR}/models/m_website.sh"

_un_lockdown() {
    local domain="$1"
    local site_base_dir="$2"
    chattr -R -i "${site_base_dir}/public_html"

    declare -A site_setting_vars=(
        [lock_folder]="no"
        [updated_at]="$(date "+%F %T")"
    )

    run_or_exit "" update_site_setting_vars "${WEB_DATA_DIR}/${domain}/.settings.conf" site_setting_vars

    press_enter_to_continue; return 0
}

_lockdown() {
    local domain="$1"
    local site_base_dir="$2"

    chattr -R +i "${site_base_dir}/public_html"
    chattr -R -i "${site_base_dir}/public_html/wp-content"
    chattr -R +i "${site_base_dir}/public_html/wp-content/plugins"
    chattr -R +i "${site_base_dir}/public_html/wp-content/themes"
    chattr +i "${site_base_dir}/public_html/wp-content/index.php"

    # shellcheck disable=SC2034
    declare -A site_setting_vars=(
        [lock_folder]="yes"
        [updated_at]="$(date "+%F %T")"
    )

    run_or_exit "" update_site_setting_vars "${WEB_DATA_DIR}/${domain}/.settings.conf" site_setting_vars

    press_enter_to_continue; return 0
}

wp_lockdown() {
    local domain
    local base_dir

    run_prompt_or_exit prompt_select_website domain "wordpress_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    local wp_file="${base_dir}/public_html/wp-load.php"
    local lockdown_active=0

    if lsattr "$wp_file" 2>/dev/null | awk '{print $1}' | grep -q 'i'; then
        lockdown_active=1
    fi

    if (( lockdown_active )); then
        if ! prompt_yes_no "Ban muon tat WordPress Lockdown cho site: $domain ?"; then
            msg "$ICON_EXIT Huy hanh dong!"
        else
            _un_lockdown "$domain" "$base_dir"
            msg "$ICON_SUCCESS Da tat WordPress Lockdown cho site: $domain" 'green'
        fi
    else
        if ! prompt_yes_no "Ban muon bat WordPress Lockdown cho site: $domain ?"; then
            msg "$ICON_EXIT Huy hanh dong!"
        else
            _lockdown "$domain" "$base_dir"
            msg "$ICON_SUCCESS Da bat WordPress Lockdown cho site: $domain" 'green'
        fi
    fi

    wordpress_menu
    press_enter_to_continue; return 0
}
