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

source "${MENU_DIR}/helpers/prompt.sh"

change_db_info() {
    local domain db_name db_user db_pass base_dir

    msg "$ICON_GLOBE Lua chon Website muon doi thong tin Database"
    run_prompt_or_exit prompt_select_website domain "website_menu"

    run_prompt_or_exit prompt_mysql_db_input db_name "website_menu" 'false'
    run_prompt_or_exit prompt_mysql_user_input db_user "website_menu" 'false'
    run_prompt_or_exit prompt_mysql_password_input db_pass "website_menu"

    if prompt_yes_no "Ban muon thay doi thong tin database cho website ${domain}?"; then
        # shellcheck disable=SC2034
        declare -A site_setting_vars=(
            [db_name]="$db_name"
            [db_user]="$db_user"
            [db_pass]="$db_pass"
            [updated_at]="$(date "+%F %T")"
        )

        rm -f "${WEB_DATA_DIR}/${domain}/.settings.conf.bak"
        cp "${WEB_DATA_DIR}/${domain}/.settings.conf" "${WEB_DATA_DIR}/${domain}/.settings.conf.bak"

        run_or_exit "" update_site_setting_vars "${WEB_DATA_DIR}/${domain}/.settings.conf" site_setting_vars

        base_dir="$(find /home -name "${domain}")"
        if [[ -n "$base_dir" && -f "${base_dir}/public_html/wp-config.php" ]]; then
            wp config set "DB_NAME" "$db_name" --allow-root --path="${base_dir}/public_html"
            wp config set "DB_USER" "$db_user" --allow-root --path="${base_dir}/public_html"
            wp config set "DB_PASSWORD" "$db_pass" --allow-root --path="${base_dir}/public_html"
        fi

        msg "$ICON_SUCCESS Thay doi thong tin database thanh cong!" 'green'
    else
        msg "$ICON_EXIT Thao tac huy bo!"
    fi

    website_menu
}
