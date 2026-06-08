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

source "${MENU_DIR}/models/m_mysql.sh"
source "${MENU_DIR}/models/m_website.sh"
source "${MENU_DIR}/models/m_application.sh"
source "${MENU_DIR}/models/m_vhost.sh"
source "${MENU_DIR}/validate/rule.sh"

_rollback_install_new_wordpress() {
    local exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        trap - EXIT
        return
    fi

    countdown_timer 3 "$ICON_WARNING Da xay ra loi. Dang tien hanh rollback..."

    local vhost_file="${SITE_AVAILABLE_DIR}/${INSTALL_WP_DOMAIN}.conf"

    delete_vhost "$INSTALL_WP_DOMAIN"

    mv "/tmp/${INSTALL_WP_DOMAIN}.conf.bak" "$vhost_file"
    create_symlink "$vhost_file" "${SITE_ENABLED_DIR}/${INSTALL_WP_DOMAIN}.conf"
    rm -rf "${INSTALL_WP_BASE_DIR}/public_html/*"

    if [ -n "$INSTALL_WP_DB_NAME" ]; then
        empty_db "$INSTALL_WP_DB_NAME"
    fi

    unset INSTALL_WP_DOMAIN INSTALL_WP_DB_NAME INSTALL_WP_BASE_DIR
}

install_new_wordpress() {
    trap _rollback_install_new_wordpress EXIT

    local domain
    local wp_admin_user
    local wp_admin_email
    local wp_site_name
    local wp_admin_pwd
    local db_name
    local db_user
    local db_pass
    local owner
    local php_version
    local base_dir
    local prompt_create_db='n'

    run_prompt_or_exit prompt_select_website domain 'wordpress_menu'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    validate_php_version_requirement --website_source 'wordpress' --php_ver "$php_version" || {
        press_enter_to_continue; return 0
    }

    if ! is_dir_empty "${base_dir}/public_html"; then
        msg "$ICON_EXIT Thu muc public_html da ton tai du lieu, vui long lam rong (empty) thu muc truoc khi cai dat WordPress."
        press_enter_to_continue; return 0
    fi

    INSTALL_WP_DOMAIN="$domain"
    INSTALL_WP_BASE_DIR="${base_dir}"

    if [[ -z "$db_name" || -z "$db_user" ]]; then
        if prompt_yes_no 'Ban co muon tu dong tao Database va user Mysql khong?'; then
            prompt_create_db="y"
        fi

        if [ "$prompt_create_db" == 'y' ]; then
            db_name="${owner}_db"
            db_user="${owner}_user"
            db_pass="$(gen_pass)"

            create_database "$db_name"
            create_mysql_user "$db_user" "$db_pass"
            grant_mysql_user_privileges "$db_name" "$db_user"
        else
            run_prompt_or_exit prompt_select_mysql_database db_name 'wordpress_menu'
            run_prompt_or_exit prompt_select_mysql_user db_user 'wordpress_menu'
            run_prompt_or_exit prompt_mysql_password_input db_pass 'wordpress_menu'
        fi
    fi

    db_pass=$(trim "$db_pass")
    if ! check_mysql_password "$db_user" "$db_pass"; then
        msg "$ICON_EXIT Mat khau mysql khong dung. Vui long kiem tra lai"
        press_enter_to_continue; return 0
    fi

    if ! is_empty_db "$db_name"; then
        msg "$ICON_EXIT Database ${db_name} da ton tai du lieu, vui long lam rong (empty) database hoac tao Database moi truoc khi cai dat WordPress."
        press_enter_to_continue; return 0
    fi

    if ! has_db_privileges --mysql_user "$db_user" --mysql_db "$db_name" ; then
        msg "$ICON_EXIT MySQL user ${db_user} khong co quyen truy cap database ${db_name}. Vui long kiem tra lai quyen truy cap."
        press_enter_to_continue; return 0
    fi

    INSTALL_WP_DB_NAME="$db_name"

    wp_admin_pwd=$(gen_pass)
    run_prompt_or_exit prompt_wp_admin_user wp_admin_user 'website_menu'
    run_prompt_or_exit prompt_wp_admin_email wp_admin_email 'website_menu'
    run_prompt_or_exit prompt_wp_site_name wp_site_name 'website_menu'

    # shellcheck disable=SC2034
    declare -A site_setting_vars=(
        [wp_admin_email]="${wp_admin_email}"
        [wp_admin_user]="${wp_admin_user}"
        [wp_admin_pwd]="${wp_admin_pwd}"
        [wp_site_name]="${wp_site_name}"
        [db_name]="${db_name}"
        [db_user]="${db_user}"
        [db_pass]="${db_pass}"
        [updated_at]="$(date "+%F %T")"
    )

    run_or_exit '' update_site_setting_vars "${WEB_DATA_DIR}/${domain}/.settings.conf" site_setting_vars

    run_or_exit 'Cai WordPress' install_wordpress "$domain"
    # shellcheck disable=SC2154
    set_site_dir_permission --owner "${owner}" --owner_folder "${owner_folder}" --domain "$domain"

    local vhost_file="${SITE_AVAILABLE_DIR}/${domain}.conf"
    if [ -e "$vhost_file" ]; then
        cp "$vhost_file" "/tmp/${domain}.conf.bak"
    fi

    run_or_exit 'Tao vHost Nginx' generate_nginx_vhost --domain "$domain" --owner "$owner" \
            --owner_folder "$owner_folder" --base_dir "$base_dir" --website_source 'wordpress'

    run_or_exit 'Format Nginx config' format_nginx_config "$vhost_file"

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        unset NGINX_T_REPLY
        exit 1
    fi

    trap - EXIT
    unset INSTALL_WP_DOMAIN INSTALL_WP_DB_NAME INSTALL_WP_BASE_DIR
    clear_screen
    msg "$ICON_SUCCESS Da cai dat WordPress thanh cong cho domain: ${domain}" 'green'
}
