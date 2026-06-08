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
source "${MENU_DIR}/helpers/file.sh"

if ! declare -f test_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_nginx.sh"
fi

if ! declare -f format_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

if [ -z "${MAX_MEMORY}" ]; then
    source "${MENU_DIR}/helpers/php_variables.sh"
fi

source "${MENU_DIR}/models/m_linux_user.sh"
source "${MENU_DIR}/models/m_mysql.sh"
source "${MENU_DIR}/models/m_php.sh"
source "${MENU_DIR}/models/m_vhost.sh"
source "${MENU_DIR}/models/m_website.sh"
source "${MENU_DIR}/models/m_application.sh"

_rollback_add_site() {
    local exit_code=$?
    if [[ "$ADD_SITE_NEED_ROLLBACK" != "true" || "$exit_code" -eq 0 ]]; then
        return
    fi

    msg "$ICON_WARNING Da xay ra loi. Dang tien hanh rollback..."

    # Xóa SFTP user nếu đã tạo
    [[ -n "$ROLLBACK_SFTP_USER" ]] && delete_sftp_user "$ROLLBACK_SFTP_USER"

    # Xóa user nếu đã tạo
    delete_linux_user "$ROLLBACK_WEB_OWNER"
    delete_dir "/home/${ROLLBACK_OWNER_FOLDER}"

    # Xóa database nếu đã tạo
    msg "$ICON_CLEAN Xoa MySQL DB $ROLLBACK_DB_NAME"
    delete_mysql_db "$ROLLBACK_DB_NAME"

    # Xóa user MySQL nếu đã tạo
    msg "$ICON_CLEAN Xoa MySQL User $ROLLBACK_DB_USER"
    delete_mysql_user "$ROLLBACK_DB_USER"

    # Xóa vhost
    delete_vhost "${ROLLBACK_DOMAIN_NAME}"

    # Xóa PHP config
    [[ -n "$ROLLBACK_PHP_CONF" ]] && msg "$ICON_CLEAN Xoa PHP pool $ROLLBACK_PHP_CONF" && delete_file "$ROLLBACK_PHP_CONF"

    delete_dir "${WEB_DATA_DIR}/${ROLLBACK_DOMAIN_NAME}"
    delete_file "${WP_CRON_DIR}/${ROLLBACK_DOMAIN_NAME}"

    msg "$ICON_BLOCK Rollback hoan tat."
    trap - EXIT
    unset ROLLBACK_WEB_OWNER ROLLBACK_DB_NAME ROLLBACK_DB_USER ROLLBACK_PHP_CONF ROLLBACK_SITE_CONF_BACKUP_DIR ROLLBACK_OWNER_FOLDER
    exit "$exit_code"
}

_add_site_success() {
    ADD_SITE_NEED_ROLLBACK=false
    trap - EXIT
    unset ROLLBACK_WEB_OWNER ROLLBACK_DB_NAME ROLLBACK_DB_USER ROLLBACK_PHP_CONF ROLLBACK_SITE_CONF_BACKUP_DIR ROLLBACK_OWNER_FOLDER
    msg "$ICON_CHECK Da them website thanh cong!" 'green'
    press_enter_to_continue; return 0
}

add_website() {
    trap _rollback_add_site EXIT
    ADD_SITE_NEED_ROLLBACK=true

    clear_screen
    print_header "Them website moi"

    local website_source=""
    local prompt_inst_wp='n'
    local prompt_inst_lar='n'
    local prompt_create_db='n'
    local db_pass=''
    local wp_admin_user=''
    local wp_admin_pwd=''
    local wp_admin_email=''
    local wp_site_name=''
    local laravel_version=''
    local base_dir=''

    run_prompt_or_exit prompt_domain_input ROLLBACK_DOMAIN_NAME "website_menu"
    sleep 0.5

    ROLLBACK_WEB_OWNER=$(generate_user_from_domain "$ROLLBACK_DOMAIN_NAME")

    ROLLBACK_OWNER_FOLDER=$(generate_web_owner_folder "$ROLLBACK_DOMAIN_NAME")

    run_prompt_or_exit prompt_select_php_version ROLLBACK_PHP_VERSION "website_menu"
    sleep 0.5; clear_screen

    run_prompt_or_exit prompt_select_website_source website_source "website_menu"
    sleep 0.5; clear_screen

    check_service_before_action "$ROLLBACK_PHP_VERSION" || {
        trap - EXIT
        exit 1
    }

    if prompt_yes_no "Ban co muon tao Database va user Mysql khong?"; then
        prompt_create_db="y"
    fi

    if [[ "$prompt_create_db" == 'y' && "$website_source" == 'wordpress' ]]; then
        sleep 0.5
        printf "\n"
        if prompt_yes_no "Ban co muon tu đong cai dat WordPress moi khong ?"; then
            prompt_inst_wp='y'
            wp_admin_pwd=$(gen_pass)
            run_prompt_or_exit prompt_wp_admin_user wp_admin_user "website_menu"
            run_prompt_or_exit prompt_wp_admin_email wp_admin_email "website_menu"
            run_prompt_or_exit prompt_wp_site_name wp_site_name "website_menu"
        fi
    fi

    if [[ "$website_source" == 'laravel' ]]; then
        sleep 0.5
        printf "\n"
        if prompt_yes_no "Ban co muon tu đong cai dat Laravel moi khong ?"; then
            prompt_inst_lar='y'
            run_prompt_or_exit prompt_select_laravel_version laravel_version "website_menu"
        fi
    fi

    if [[ "$prompt_inst_lar" == 'y' || "$prompt_inst_wp" == 'y' ]]; then
        validate_php_version_requirement --website_source "$website_source" --php_ver "$ROLLBACK_PHP_VERSION" || {
            trap - EXIT
            exit 1
        }
    fi

    base_dir="/home/${ROLLBACK_OWNER_FOLDER}/${ROLLBACK_DOMAIN_NAME}"
    create_system_user "$ROLLBACK_WEB_OWNER" "$ROLLBACK_OWNER_FOLDER"

    # Tao SFTP user rieng cho domain nay
    ROLLBACK_SFTP_USER="sftp_${ROLLBACK_WEB_OWNER}"
    SFTP_PASS=$(gen_pass)
    create_sftp_user "$ROLLBACK_SFTP_USER" "$SFTP_PASS" "$ROLLBACK_DOMAIN_NAME" "$ROLLBACK_OWNER_FOLDER"

    if [[ "$prompt_create_db" == 'y' ]]; then
        ROLLBACK_DB_USER="${ROLLBACK_WEB_OWNER}_user"
        ROLLBACK_DB_NAME="${ROLLBACK_WEB_OWNER}_db"
        db_pass=$(gen_pass)

        create_database "$ROLLBACK_DB_NAME"
        create_mysql_user "$ROLLBACK_DB_USER" "$db_pass"
        grant_mysql_user_privileges "$ROLLBACK_DB_NAME" "$ROLLBACK_DB_USER"
    fi

    # shellcheck disable=SC2034
    declare -A website_conf=(
        [domain]="$ROLLBACK_DOMAIN_NAME"
        [php_version]="$ROLLBACK_PHP_VERSION"
        [owner]="$ROLLBACK_WEB_OWNER"
        [owner_folder]="$ROLLBACK_OWNER_FOLDER"
        [website_source]="$website_source"
        [db_user]="$ROLLBACK_DB_USER"
        [db_name]="$ROLLBACK_DB_NAME"
        [db_pass]="$db_pass"
        [php_pm]=ondemand
        [disable_xmlrpc]=no
        [disable_user_api]=no
        [disable_file_edit]=no
        [lock_folder]=no
        [laravel_version]="$laravel_version"
        [base_dir]="$base_dir"
        [wp_admin_user]="$wp_admin_user"
        [wp_admin_pwd]="$wp_admin_pwd"
        [wp_admin_email]="$wp_admin_email"
        [wp_site_name]="$wp_site_name"
        [pm_max_children]="$PM_MAX_CHILDREN"
        [pm_start_servers]="$PM_START_SERVERS"
        [pm_min_spare_servers]="$PM_MIN_SPARE_SERVER"
        [pm_max_spare_servers]="$PM_MAX_SPARE_SERVER"
        [pm_max_request]="$PM_MAX_REQUEST"
        [php_memory_limit]="${MAX_MEMORY}"
        [php_max_execution_time]=600
        [php_max_input_time]=600
        [php_post_max_size]="${MAX_MEMORY}"
        [php_upload_max_filesize]="${MAX_MEMORY}"
        [sftp_user]="$ROLLBACK_SFTP_USER"
        [sftp_pass]="$SFTP_PASS"
    )

    save_website_settings website_conf

    run_or_exit "Tao thu muc website" create_website_directories "$base_dir"

    if [[ "$prompt_inst_wp" == 'y' ]]; then
        run_or_exit "Cai WordPress" install_wordpress "$ROLLBACK_DOMAIN_NAME"
    fi

    if [[ "$prompt_inst_lar" == 'y' ]]; then
         run_or_exit "Cai Laravel" install_laravel "$ROLLBACK_DOMAIN_NAME"
    fi

    set_site_dir_permission --owner "$ROLLBACK_WEB_OWNER" --owner_folder "$ROLLBACK_OWNER_FOLDER" --domain "$ROLLBACK_DOMAIN_NAME"

    local pool_conf="/etc/php/${ROLLBACK_PHP_VERSION}/fpm/pool.d/${ROLLBACK_DOMAIN_NAME}.conf"
    run_or_exit "Tao PHP-FPM pool" create_php_pool "$ROLLBACK_WEB_OWNER" "$ROLLBACK_OWNER_FOLDER" \
        "$ROLLBACK_DOMAIN_NAME" "$ROLLBACK_PHP_VERSION"

    if [[ "$website_source" == 'laravel' ]]; then
        run_or_exit "Xoa proc_* trong pool.conf" strip_proc_functions "$pool_conf"
    fi

    local vhost_file="${SITE_AVAILABLE_DIR}/${ROLLBACK_DOMAIN_NAME}.conf"
    run_or_exit "Tao vHost Nginx" generate_nginx_vhost --domain "$ROLLBACK_DOMAIN_NAME" --owner "$ROLLBACK_WEB_OWNER" \
        --owner_folder "$ROLLBACK_OWNER_FOLDER" --base_dir "$base_dir" --website_source "$website_source"

    run_or_exit "Format Nginx config" format_nginx_config "$vhost_file"

    enable_nginx_vhost "${ROLLBACK_DOMAIN_NAME}"

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        exit 1
    fi

    if ! test_php_pool_conf --php_version "$ROLLBACK_PHP_VERSION" --domain "${ROLLBACK_DOMAIN_NAME}"; then
        msg "$PHP_POOL_T_REPLY"
        exit 1
    fi

    reload_specific_php_ver "$ROLLBACK_PHP_VERSION"
    nginx_reload


    if ! check_http_status "${ROLLBACK_DOMAIN_NAME}"; then
        msg "${CHECK_HTTP_STATUS_REPLY}"
        exit 1
    fi

    mkdir -p "${SSL_PENDING_DIR}"
    touch "${SSL_PENDING_DIR}/${ROLLBACK_DOMAIN_NAME}"

    backup_site_config "${ROLLBACK_DOMAIN_NAME}" "$ROLLBACK_PHP_VERSION"

    clear_screen
    printf "\n"
    echo "Duoi day la thong tin website cua ban!"
    echo "---------------------------"
    echo "Ten mien         : $ROLLBACK_DOMAIN_NAME"
    echo "PHP version      : $ROLLBACK_PHP_VERSION"
    echo "Website Dir      : $base_dir"
    echo "Website Source   : $website_source"

    if [ "$prompt_inst_wp" == 'y' ]; then
        printf "\n"
        echo "WP-ADMIN User    : $wp_admin_user"
        echo "WP-ADMIN Password: $wp_admin_pwd"
    fi

    if [ "$prompt_create_db" == 'y' ]; then
        printf "\n"
        echo "Database Name    : $ROLLBACK_DB_NAME"
        echo "Database User    : $ROLLBACK_DB_USER"
        echo "Database Password: $db_pass"
    fi

    # shellcheck disable=SC2154
    echo "phpMyAdmin URL   : http://${IP_ADDRESS}:${admin_port}/phpmyadmin"

    printf "\n"
    echo "--- SFTP ---"
    echo "SFTP Host        : ${IP_ADDRESS}"
    echo "SFTP Port        : 22"
    echo "SFTP User        : $ROLLBACK_SFTP_USER"
    echo "SFTP Password    : $SFTP_PASS"
    echo "SFTP Directory   : /${ROLLBACK_DOMAIN_NAME}/public_html"

    echo "---------------------------"

    _add_site_success
}
