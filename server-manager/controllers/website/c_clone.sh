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
source "${MENU_DIR}/models/m_linux_user.sh"
source "${MENU_DIR}/models/m_mysql.sh"
source "${MENU_DIR}/models/m_php.sh"
source "${MENU_DIR}/models/m_vhost.sh"
source "${MENU_DIR}/models/m_website.sh"
source "${MENU_DIR}/models/m_nginx.sh"

if ! declare -f format_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

_rollback_clone_website() {
    local exit_code=$?

    if [[ "$CLONE_WEBSITE_NEED_ROLLBACK" != "true" || "$exit_code" -eq 0 ]]; then
        return
    fi

    clear_screen
    countdown_timer 3 "$ICON_WARNING Da xay ra loi. Dang tien hanh rollback..."

    delete_dir "${WEB_DATA_DIR}/${CLONE_DOMAIN}"
    delete_dir "/home/${CLONE_OWNER_FOLDER}"
    delete_linux_user "$CLONE_WEB_OWNER"
    delete_file "${PHP_BASE_DIR}/${CW_PHP_VERSION}/fpm/pool.d/${CLONE_DOMAIN}.conf"
    delete_vhost "${CLONE_DOMAIN}"

    delete_mysql_user "${CLONE_DB_USER}"
    delete_mysql_db "${CLONE_DB_NAME}"

    nginx_reload
    reload_specific_php_ver "$CW_PHP_VERSION"
    unset CLONE_DOMAIN CLONE_WEB_OWNER CW_PHP_VERSION CLONE_OWNER_FOLDER CLONE_DB_USER CLONE_DB_NAME

    msg "$ICON_EXIT Clone website that bai"
}

_clone_site_success() {
    CLONE_WEBSITE_NEED_ROLLBACK=false
    trap - EXIT
    clear_screen
    msg "$ICON_CHECK Da clone website thanh cong!" 'green'
    echo "---------------------------"
    echo "Domain clone    : $CLONE_DOMAIN"
    echo "Web Dir         : /home/${CLONE_OWNER_FOLDER}/${CLONE_DOMAIN}/public_html"
    if [[ -n "$CLONE_DB_NAME" ]]; then
        echo "Database        : $CLONE_DB_NAME"
        echo "DB User         : $CLONE_DB_USER"
    fi
    echo "SFTP User       : sftp_${CLONE_WEB_OWNER}"
    echo "---------------------------"
    unset CLONE_DOMAIN CLONE_WEB_OWNER CW_PHP_VERSION CLONE_OWNER_FOLDER CLONE_DB_USER CLONE_DB_NAME
    press_enter_to_continue; return 0
}

clone_website() {
    trap _rollback_clone_website EXIT
    CLONE_WEBSITE_NEED_ROLLBACK=true

    local cw_target_domain
    local target_file_settings
    local clone_file_settings
    local clone_base_dir

    msg "$ICON_TOOL Lua chon website ban muon clone" "green"
    run_prompt_or_exit prompt_select_website cw_target_domain "website_menu"
    sleep 0.5;

    msg "$ICON_TOOL Nhap ten mien moi" "green"
    run_prompt_or_exit prompt_domain_input CLONE_DOMAIN "website_menu"
    sleep 0.5;

    if ! prompt_yes_no "Ban muon clone Website ${RED}${cw_target_domain}${NC} sang Website ${RED}${CLONE_DOMAIN}${NC} ?"; then
        unset cw_target_domain
        trap - EXIT
        msg "Huy thao tac"
        sleep 1
        website_menu
    fi

    target_file_settings="${WEB_DATA_DIR}/${cw_target_domain}/.settings.conf"
    clone_file_settings="${WEB_DATA_DIR}/${CLONE_DOMAIN}/.settings.conf"

    # shellcheck disable=SC1090
    source "$target_file_settings" || {
        trap - EXIT
        msg "$ICON_EXIT Khong the load file cau hinh: ${cw_target_domain}"
        exit 1
    }

    # shellcheck disable=SC2154
    local cw_target_owner_folder="${owner_folder}"
    # shellcheck disable=SC2154
    local cw_target_owner="${owner}"
    local cw_target_db_name="${db_name}"

    # shellcheck disable=SC2154
    check_service_before_action "$php_version" || {
        trap - EXIT
        exit 1
    }

    CW_PHP_VERSION="${php_version}"

    CLONE_WEB_OWNER=$(generate_user_from_domain "${CLONE_DOMAIN}")
    CLONE_OWNER_FOLDER=$(generate_web_owner_folder "${CLONE_DOMAIN}")

    clone_base_dir="/home/${CLONE_OWNER_FOLDER}/${CLONE_DOMAIN}"
    create_system_user "$CLONE_WEB_OWNER" "$CLONE_OWNER_FOLDER"

    # Tao SFTP user cho domain clone
    local clone_sftp_user="sftp_${CLONE_WEB_OWNER}"
    local clone_sftp_pass
    clone_sftp_pass=$(gen_pass)
    create_sftp_user "$clone_sftp_user" "$clone_sftp_pass" "$CLONE_DOMAIN" "$CLONE_OWNER_FOLDER"

    run_or_exit "Tao thu muc website" create_website_directories "$clone_base_dir"

    # shellcheck disable=SC2154
    run_or_exit "Clone ma nguon" rsync -avh "${base_dir}/public_html/" "${clone_base_dir}/public_html/"

    set_site_dir_permission --owner "$CLONE_WEB_OWNER" --owner_folder "$CLONE_OWNER_FOLDER" --domain "$CLONE_DOMAIN"

    if [[ -n "$db_name" ]]; then
        msg "$ICON_TOOL Clone Database" "green"
        local clone_db_pass
        clone_db_pass=$(gen_pass)
        CLONE_DB_USER="${CLONE_WEB_OWNER}_user"
        CLONE_DB_NAME="${CLONE_WEB_OWNER}_db"

        create_database "$CLONE_DB_NAME"
        create_mysql_user "$CLONE_DB_USER" "$clone_db_pass"
        grant_mysql_user_privileges "$CLONE_DB_NAME" "$CLONE_DB_USER"

        delete_file "/tmp/${cw_target_db_name}.sql"

        mariadb-dump "$cw_target_db_name" > "/tmp/${cw_target_db_name}.sql" || {
            msg "$ICON_EXIT Cannot Dump Database $cw_target_db_name"
            exit 1
        }

        mariadb "$CLONE_DB_NAME" < "/tmp/${cw_target_db_name}.sql" || {
            msg "$ICON_EXIT Cannot import Database $cw_target_db_name"
            exit 1
        }

        delete_file "/tmp/${cw_target_db_name}.sql"

        if is_wordpress "${CLONE_DOMAIN}" "${CLONE_OWNER_FOLDER}"; then
            cd_dir "${clone_base_dir}/public_html"
            run_or_exit "Edit WordPress Config DB_NAME" wp config set DB_NAME "$CLONE_DB_NAME" --allow-root
            run_or_exit "Edit WordPress Config DB_USER" wp config set DB_USER "$CLONE_DB_USER" --allow-root
            run_or_exit "Edit WordPress Config DB_USER" wp config set DB_PASSWORD "$clone_db_pass" --allow-root
            run_or_exit "Change WordPress Domain" wp search-replace "${cw_target_domain}" "${CLONE_DOMAIN}" --allow-root
        elif [[ -e "${clone_base_dir}/public_html/.env" ]]; then
            run_or_exit "" sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${CLONE_DB_NAME}|g;
                s|^DB_USERNAME=.*|DB_USERNAME=${CLONE_DB_USER}|g;
                s|^DB_PASSWORD=.*|DB_PASSWORD=${clone_db_pass}|g;
                s|^CACHE_PREFIX=.*|CACHE_PREFIX=${CLONE_OWNER_FOLDER}_|g" "${clone_base_dir}/public_html/.env"
        fi
    fi

    mkdir -p "${WEB_DATA_DIR}/${CLONE_DOMAIN}"
    run_or_exit "Clone Setting File" cp "${target_file_settings}" "${clone_file_settings}"

    # shellcheck disable=SC2034
    declare -A clone_site_setting_vars=(
        [domain]="${CLONE_DOMAIN}"
        [owner]="${CLONE_WEB_OWNER}"
        [owner_folder]="${CLONE_OWNER_FOLDER}"
        [db_user]="${CLONE_DB_USER}"
        [db_name]="${CLONE_DB_NAME}"
        [db_pass]="${clone_db_pass}"
        [base_dir]="${clone_base_dir}"
        [sftp_user]="${clone_sftp_user}"
        [sftp_pass]="${clone_sftp_pass}"
        [updated_at]="$(date "+%F %T")"
    )

    run_or_exit "" update_site_setting_vars "${WEB_DATA_DIR}/${CLONE_DOMAIN}/.settings.conf" clone_site_setting_vars

    # shellcheck disable=SC2154
    run_or_exit "Clone PHP-FPM pool" create_php_pool "${CLONE_WEB_OWNER}" \
            "${CLONE_OWNER_FOLDER}" "${CLONE_DOMAIN}" "${php_version}"

    # Restart PHP-FPM truoc de tao sock file moi truoc khi nginx test
    run_or_exit "Restart php-fpm" systemctl restart php"${php_version}"-fpm.service
    sleep 1

    local target_vhost="${SITE_AVAILABLE_DIR}/${cw_target_domain}.conf"
    local clone_vhost="${SITE_AVAILABLE_DIR}/${CLONE_DOMAIN}.conf"

    run_or_exit "Clone vhost" cp "$target_vhost" "$clone_vhost"

    # Thay the ssl_certificate va ssl_certificate_key bang cert mac dinh
    sed -i "s|ssl_certificate .*;|ssl_certificate /etc/nginx/ssl/default/server.crt;|g" "$clone_vhost"
    sed -i "s|ssl_certificate_key .*;|ssl_certificate_key /etc/nginx/ssl/default/server.key;|g" "$clone_vhost"

    sed -i \
        -e "s|\\b${cw_target_domain}\\b|${CLONE_DOMAIN}|g" \
        -e "s|/home/${cw_target_owner_folder}/|/home/${CLONE_OWNER_FOLDER}/|g" \
        -e "s|${cw_target_owner}\.sock|${CLONE_WEB_OWNER}.sock|g" \
        "$clone_vhost"

    run_or_exit "Format Nginx config" format_nginx_config "$clone_vhost"

    enable_nginx_vhost "${CLONE_DOMAIN}"

    # Tao thu muc logs neu chua co de nginx test khong bi loi
    mkdir -p "/home/${CLONE_OWNER_FOLDER}/${CLONE_DOMAIN}/logs/access" \
             "/home/${CLONE_OWNER_FOLDER}/${CLONE_DOMAIN}/logs/errors"

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        exit 1
    fi

    reload_specific_php_ver "$php_version"
    nginx_reload
    _clone_site_success
}
