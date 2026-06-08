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

change_wp_admin_password() {
    local domain
    local admin_id
    local admin_login_name
    local wp_admin_user
    local base_dir
    local new_password

    run_prompt_or_exit prompt_select_website domain "wordpress_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    run_prompt_or_exit prompt_select_wp_admin_user wp_admin_user "wordpress_menu" "$domain"

    IFS=':' read -r admin_id admin_login_name <<< "$wp_admin_user"

    if ! prompt_yes_no "Ban muon thay doi mat khau cho user: $admin_login_name ?"; then
        msg "$ICON_EXIT Thay doi mat khau bi huy boi nguoi dung!"
        wordpress_menu
        return 1
    fi

    cd_dir "${base_dir}/public_html"

    new_password=$(gen_pass)
    wp user update "$admin_id" --user_pass="$new_password" --allow-root
    clear_screen
    msg "$ICON_SUCCESS Da thay doi mat khau cho user: $admin_login_name" 'green'
    echo "${GREEN}Mat khau moi:${NC} ${RED}${new_password}${NC}"
    exit 1
}
