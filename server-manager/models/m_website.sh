#!/bin/bash

##############################################################################################################
#                             Auto Install & Optimize LEMP Stack on Ubuntu                                   #
#                                                                                                            #
#                                    Author: Sanvv - HOSTVN Technical                                        #
#                                        Website: https://hostvn.vn                                          #
#                                                                                                            #
#                                  Please do not remove copyright. Thank!                                    #
#  Copying or using this content for any commercial purpose is strictly prohibited under all circumstances!  #
##############################################################################################################

if ! declare -f test_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_nginx.sh"
fi

if ! declare -f delete_vhost >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_vhost.sh"
fi

if ! declare -f reload_specific_php_ver >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_php.sh"
fi

if ! declare -f safe_copy_or_exit >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/file.sh"
fi

if ! declare -f delete_linux_user >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_linux_user.sh"
fi

backup_site_config() {
    local domain="$1"
    local php_version="$2"
    local ignore_file_not_exist="${3:-false}"
    local current_date

    if [ -z "$domain" ]; then
        return 1
    fi

    current_date="$(date "+%d-%m-%Y")"
    ROLLBACK_SITE_CONF_BACKUP_DIR="${BACKUP_CONF_DIR}/${domain}/${current_date}"

    local vhost_file="${SITE_AVAILABLE_DIR}/${domain}.conf"
    local settings_file="${WEB_DATA_DIR}/${domain}/.settings.conf"

    mkdir -p "${ROLLBACK_SITE_CONF_BACKUP_DIR}"

    safe_copy_or_exit "Backup Nginx vhost" "${vhost_file}" "${ROLLBACK_SITE_CONF_BACKUP_DIR}/nginx_${domain}.conf" "$ignore_file_not_exist"

    if [ -n "$php_version" ]; then
        local pool_file="${PHP_BASE_DIR}/${php_version}/fpm/pool.d/${domain}.conf"
        safe_copy_or_exit "Backup PHP pool" "${pool_file}" "${ROLLBACK_SITE_CONF_BACKUP_DIR}/php_${domain}.conf" "$ignore_file_not_exist"
    fi

    safe_copy_or_exit "Backup site settings file" "${settings_file}" "${ROLLBACK_SITE_CONF_BACKUP_DIR}/.settings.conf" "$ignore_file_not_exist"
}

create_website_directories() {
    local base_dir="$1"

    for dir in public_html logs/access logs/errors php/sessions php/logs/errors php/logs/slow ; do
        run_or_exit "Tao thu muc $dir" mkdir -p "${base_dir}/$dir"
    done
}

update_site_setting_vars() {
    local file="$1"
    local -n map="$2"

    if [[ ! -f "$file" ]]; then
        msg "$ICON_EXIT File khong ton tai: $file"
        exit 1
    fi

    cp -p "$file" "${file}.bak"

    local tmp_file
    tmp_file=$(mktemp)

    declare -A updated_keys=()
    local key value

    while IFS= read -r line || [[ -n "$line" ]]; do
        local updated_line="$line"
        for key in "${!map[@]}"; do
            if [[ "$line" =~ ^${key}=\' ]]; then
                value="${map[$key]}"
                updated_line="${key}='${value}'"
                updated_keys["$key"]=1
                break
            fi
        done
        echo "$updated_line" >> "$tmp_file"
    done < "$file"

    # Thêm các biến chưa tồn tại
    for key in "${!map[@]}"; do
        if [[ -z "${updated_keys[$key]}" ]]; then
            value="${map[$key]}"
            echo "${key}='${value}'" >> "$tmp_file"
        fi
    done

    run_or_exit "" mv "$tmp_file" "$file"
}

save_website_settings() {
    local -n conf="$1"

    if [[ -z "${conf[domain]}" ]]; then
        msg "$ICON_EXIT Thieu gia tri conf[domain] — khong the ghi file cau hinh"
        exit 1
    fi

    local conf_path="${WEB_DATA_DIR}/${conf[domain]}"
    local conf_file="${conf_path}/.settings.conf"

    if [[ -f "$conf_file" ]]; then
        msg "$ICON_WARNING File cau hinh da ton tai: $conf_file — khong ghi de"
        exit 1
    fi

    mkdir -p "$conf_path"

    # shellcheck disable=SC2154
    conf[created_at]="$(date "+%F %T")"
    # shellcheck disable=SC2154
    conf[updated_at]=""

    for key in "${!conf[@]}"; do
        printf "%s='%s'\n" "$key" "${conf[$key]}"
    done > "$conf_file"

    if [[ ! -s "$conf_file" ]]; then
        msg "💾 Khong the ghi file cau hinh: ${conf_file}"
        exit 1
    fi
}

destroy_website() {
    local domain="$1"
    local destroy_db="${2:-n}"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    if [ "$destroy_db" == 'y' ]; then
        if [[ -n "$db_name" ]]; then
            # shellcheck disable=SC2154
            run_or_exit "🧹 Xoa MySQL DB $db_name" mariadb -u"${mysql_user}" \
                -p"${mysql_admin_pwd}" -e "DROP DATABASE IF EXISTS \`${db_name}\`;" 2>/dev/null
        fi

        if [[ -n "$db_user" ]]; then
            run_or_exit "🧹 Xoa MySQL User $db_user" mariadb -u"${mysql_user}" \
                -p"${mysql_admin_pwd}" \
                -e "DROP USER IF EXISTS '${db_user}'@'localhost'; DROP USER IF EXISTS '${db_user}'@'127.0.0.1';" 2>/dev/null
        fi
    fi

    delete_vhost "${domain}"

    # shellcheck disable=SC2154
    [[ -e "/etc/php/${php_version}/fpm/pool.d/$domain.conf" ]] && msg "🧹 Xoa PHP pool" \
        && delete_file "/etc/php/${php_version}/fpm/pool.d/$domain.conf"

    # shellcheck disable=SC2154
    delete_dir "/home/$owner_folder"
    delete_dir "${WEB_DATA_DIR}/${domain}"
    delete_file "${WP_CRON_DIR}/${domain}"

    if [[ -n "$owner" ]] && id "$owner" &>/dev/null; then
        delete_linux_user "$owner"
    fi

    reload_specific_php_ver "$php_version"
}

_rollback_change_website_domain() {
    local exit_code=$?
    local need_reload_nginx='true'
    local site_backup_conf_dir

    if [[ "$CHANGE_WEBSITE_DOMAIN_NEED_ROLLBACK" != "true" || "$exit_code" -eq 0 ]]; then
        return
    fi

    countdown_timer 3 "$ICON_WARNING Da xay ra loi. Dang tien hanh rollback..."

    backup_site_config "${ROLLBACK_NEW_DOMAIN}" "${ROLLBACK_PHP_VERSION}" 'true'
    site_backup_conf_dir="${BACKUP_CONF_DIR}/${ROLLBACK_OLD_DOMAIN}/$(date "+%d-%m-%Y")"

    # Rollback website settings
    if [[ -f "${site_backup_conf_dir}/.settings.conf" ]]; then
        if [[ -d "${WEB_DATA_DIR}/${ROLLBACK_NEW_DOMAIN}" && ! -d "${WEB_DATA_DIR}/${ROLLBACK_OLD_DOMAIN}" ]]; then
            run_or_exit "Rollback site settings" mv "${WEB_DATA_DIR}/${ROLLBACK_NEW_DOMAIN}" "${WEB_DATA_DIR}/${ROLLBACK_OLD_DOMAIN}"
        fi

        safe_copy_or_exit "" "${site_backup_conf_dir}/.settings.conf" "${WEB_DATA_DIR}/${ROLLBACK_OLD_DOMAIN}/.settings.conf" 'true'
    fi

    # Rename folder
    # shellcheck disable=SC2154
    if [[ ! -d "/home/${ROLLBACK_OLD_OWNER_FOLDER}" && -d "/home/${ROLLBACK_NEW_OWNER_FOLDER}" ]]; then
        run_or_exit "Rename owner folder" mv "/home/${ROLLBACK_NEW_OWNER_FOLDER}" "/home/${ROLLBACK_OLD_OWNER_FOLDER}"
    fi

    if [[ ! -d "/home/${ROLLBACK_OLD_OWNER_FOLDER}/${ROLLBACK_OLD_DOMAIN}" && -d "/home/${ROLLBACK_OLD_OWNER_FOLDER}/${ROLLBACK_NEW_DOMAIN}" ]]; then
        run_or_exit "Rename owner folder" mv "/home/${ROLLBACK_OLD_OWNER_FOLDER}/${ROLLBACK_NEW_DOMAIN}" \
            "/home/${ROLLBACK_OLD_OWNER_FOLDER}/${ROLLBACK_OLD_DOMAIN}"
    fi

    # Rollback nginx vhost
    delete_file "${SITE_ENABLED_DIR}/${ROLLBACK_NEW_DOMAIN}.conf" "${SITE_AVAILABLE_DIR}/${ROLLBACK_NEW_DOMAIN}.conf"

    if [ ! -e "$ROLLBACK_OLD_VHOST" ]; then
        safe_copy_or_exit "Rollback Nginx vhost" "${site_backup_conf_dir}/nginx_${ROLLBACK_OLD_DOMAIN}.conf" "$ROLLBACK_OLD_VHOST" 'true'
    fi

    if [ ! -e "${SITE_ENABLED_DIR}/${ROLLBACK_OLD_DOMAIN}.conf" ]; then
        ln -s "$ROLLBACK_OLD_VHOST" "${SITE_ENABLED_DIR}/${ROLLBACK_OLD_DOMAIN}.conf"
    fi

    # Rollback PHP Pool
    # shellcheck disable=SC2154
    delete_file "/etc/php/${ROLLBACK_PHP_VERSION}/fpm/pool.d/${ROLLBACK_NEW_DOMAIN}.conf"
    if [ ! -e "$ROLLBACK_OLD_PHP_POOL" ]; then
        safe_copy_or_exit "Rollback PHP Pool" "${site_backup_conf_dir}/php_${ROLLBACK_OLD_DOMAIN}.conf" "$ROLLBACK_OLD_PHP_POOL" 'true'
    fi

    if [[ "${ROLLBACK_WP_CHANGE_DOMAIN}" == 'true' ]]; then
        cd_dir "/home/${ROLLBACK_OLD_OWNER_FOLDER}/${ROLLBACK_OLD_DOMAIN}/public_html"
        run_or_exit "Change WordPress Domain" wp search-replace "${ROLLBACK_NEW_DOMAIN}" "${ROLLBACK_OLD_DOMAIN}" --allow-root
    fi

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        need_reload_nginx='false'
        if [[ "$NGINX_T_REPLY" == *"${ROLLBACK_OLD_DOMAIN}"* ]]; then
            msg "Disable Website $ROLLBACK_OLD_DOMAIN de tranh loi"
            delete_file "${SITE_ENABLED_DIR}/${ROLLBACK_OLD_DOMAIN}.conf"
        fi
    fi

    if [ "$need_reload_nginx" == 'true' ]; then
        nginx_reload
    fi

    # Rollback linux user
    if ! is_linux_user_exists "${ROLLBACK_OLD_WEB_OWNER}"; then
        create_system_user "${ROLLBACK_OLD_WEB_OWNER}" "${ROLLBACK_OLD_OWNER_FOLDER}" 'false'
    fi

    if [[ -d "/home/${ROLLBACK_OLD_OWNER_FOLDER}/${ROLLBACK_OLD_DOMAIN}" ]]; then
        set_site_dir_permission --owner "${ROLLBACK_OLD_WEB_OWNER}" --owner_folder "${ROLLBACK_OLD_OWNER_FOLDER}" --domain "${ROLLBACK_OLD_DOMAIN}"
    fi

    run_or_exit "" systemctl restart php"${ROLLBACK_PHP_VERSION}"-fpm.service

    # Xoa user moi
    if is_linux_user_exists "${ROLLBACK_NEW_WEB_OWNER}"; then
        delete_linux_user "$ROLLBACK_NEW_WEB_OWNER"
    fi

    msg "$ICON_WARNING Doi ten mien that bai. Da rollback ve trang thai truoc do!"

    unset ROLLBACK_OLD_DOMAIN ROLLBACK_OLD_VHOST ROLLBACK_OLD_PHP_POOL ROLLBACK_OLD_OWNER_FOLDER ROLLBACK_OLD_WEB_OWNER \
        ROLLBACK_SITE_CONF_BACKUP_DIR ROLLBACK_NEW_DOMAIN ROLLBACK_NEW_OWNER_FOLDER ROLLBACK_NEW_WEB_OWNER

    trap - EXIT

    exit "$exit_code"
}

_change_site_domain_success() {
     CHANGE_WEBSITE_DOMAIN_NEED_ROLLBACK=false
     trap - EXIT

     local new_domain="${ROLLBACK_NEW_DOMAIN}"
     local new_owner_folder="${ROLLBACK_NEW_OWNER_FOLDER}"

     unset ROLLBACK_OLD_DOMAIN ROLLBACK_OLD_VHOST ROLLBACK_OLD_PHP_POOL ROLLBACK_OLD_OWNER_FOLDER ROLLBACK_OLD_WEB_OWNER \
        ROLLBACK_SITE_CONF_BACKUP_DIR ROLLBACK_NEW_DOMAIN ROLLBACK_NEW_OWNER_FOLDER ROLLBACK_NEW_WEB_OWNER

     # Load thong tin moi tu settings file
     local db_name db_user db_pass sftp_user sftp_pass php_version
     source "${WEB_DATA_DIR}/${new_domain}/.settings.conf" 2>/dev/null

     msg "$ICON_CHECK Thay doi ten mien thanh cong!" 'green'
     echo "---------------------------"
     echo "Domain moi    : ${new_domain}"
     echo "Web Dir       : /home/${new_owner_folder}/${new_domain}/public_html"
     echo "URL           : https://${new_domain}"
     if [[ -n "$db_name" ]]; then
         echo "Database      : ${db_name}"
         echo "DB User       : ${db_user}"
         echo "DB Password   : ${db_pass}"
     fi
     if [[ -n "$sftp_user" ]]; then
         echo "SFTP User     : ${sftp_user}"
         echo "SFTP Password : ${sftp_pass}"
     fi
     echo "PHP Version   : ${php_version}"
     echo "---------------------------"
     press_enter_to_continue
 }

change_website_domain() {
    trap _rollback_change_website_domain EXIT
    CHANGE_WEBSITE_DOMAIN_NEED_ROLLBACK=true

    ROLLBACK_OLD_DOMAIN="$1"
    ROLLBACK_NEW_DOMAIN="$2"
    local file_settings=''
    local php_version

    file_settings="${WEB_DATA_DIR}/${ROLLBACK_OLD_DOMAIN}/.settings.conf"

    # shellcheck disable=SC1090
    source "$file_settings" || {
        trap - EXIT
        msg "$ICON_EXIT Khong the load file cau hinh: ${ROLLBACK_OLD_DOMAIN}"
        exit 1
    }

    ROLLBACK_PHP_VERSION="${php_version}"
    ROLLBACK_WP_CHANGE_DOMAIN='false'
    ROLLBACK_OLD_OWNER_FOLDER="${owner_folder}"
    ROLLBACK_OLD_WEB_OWNER="${owner}"
    ROLLBACK_OLD_VHOST="${SITE_AVAILABLE_DIR}/${ROLLBACK_OLD_DOMAIN}.conf"
    ROLLBACK_OLD_PHP_POOL="/etc/php/${php_version}/fpm/pool.d/${ROLLBACK_OLD_DOMAIN}.conf"

    check_service_before_action "$php_version" || {
        trap - EXIT
        exit 1
    }

    if ! test_php_pool_conf --php_version "$php_version" --domain "$ROLLBACK_OLD_DOMAIN"; then
        msg "$PHP_POOL_T_REPLY"
        trap - EXIT
        exit 1
    fi

    # backup file cau hinh cu:
    backup_site_config "${ROLLBACK_OLD_DOMAIN}" "${php_version}"

    # Change domain
    ROLLBACK_NEW_OWNER_FOLDER=$(generate_web_owner_folder "$ROLLBACK_NEW_DOMAIN")
    ROLLBACK_NEW_WEB_OWNER=$(generate_user_from_domain "$ROLLBACK_NEW_DOMAIN")

    ## Edit nginx vhost
    sed -i \
        -e "s|\\b${ROLLBACK_OLD_DOMAIN}\\b|${ROLLBACK_NEW_DOMAIN}|g" \
        -e "s|/home/${ROLLBACK_OLD_OWNER_FOLDER}/|/home/${ROLLBACK_NEW_OWNER_FOLDER}/|g" \
        -e "s|${ROLLBACK_OLD_WEB_OWNER}\.sock|${ROLLBACK_NEW_WEB_OWNER}.sock|g" \
        "$ROLLBACK_OLD_VHOST"

    ## Edit SSL config
    local need_sign_ssl='false'

    if [ ! -d "${SSL_CERT_DIR}/${ROLLBACK_NEW_DOMAIN}" ]; then
        mkdir -p "${SSL_CERT_DIR}/${ROLLBACK_NEW_DOMAIN}"
    fi

    if [ ! -f "${SSL_CERT_DIR}/${ROLLBACK_NEW_DOMAIN}/${SSL_CERT_FILE_NAME}" ]; then
        run_or_exit "Copy SSL cert" cp "${SSL_CERT_DIR}/default/server.crt" \
            "${SSL_CERT_DIR}/${ROLLBACK_NEW_DOMAIN}/${SSL_CERT_FILE_NAME}"
        need_sign_ssl='true'
    fi

    if [ ! -f "${SSL_CERT_DIR}/${ROLLBACK_NEW_DOMAIN}/${SSL_PRI_KEY_FILE_NAME}" ]; then
        run_or_exit "Copy SSL key" cp "${SSL_CERT_DIR}/default/server.key" \
            "${SSL_CERT_DIR}/${ROLLBACK_NEW_DOMAIN}/${SSL_PRI_KEY_FILE_NAME}"
        need_sign_ssl='true'
    fi

    if [ $need_sign_ssl == 'true' ]; then
        touch "${SSL_PENDING_DIR}/${ROLLBACK_NEW_DOMAIN}"
    fi

    ## Rename domain folder
    if [ -d "/home/${ROLLBACK_OLD_OWNER_FOLDER}/${ROLLBACK_OLD_DOMAIN}" ]; then
        run_or_exit "Rename domain folder" mv "/home/${ROLLBACK_OLD_OWNER_FOLDER}/${ROLLBACK_OLD_DOMAIN}" \
            "/home/${ROLLBACK_OLD_OWNER_FOLDER}/${ROLLBACK_NEW_DOMAIN}"
    fi

    if [ -d "/home/${ROLLBACK_OLD_OWNER_FOLDER}" ]; then
        run_or_exit "Rename owner folder" mv "/home/${ROLLBACK_OLD_OWNER_FOLDER}" "/home/${ROLLBACK_NEW_OWNER_FOLDER}"
    fi

    rm -f "${SITE_ENABLED_DIR}/${ROLLBACK_OLD_DOMAIN}.conf"
    run_or_exit "Rename Nginx vhost" mv "$ROLLBACK_OLD_VHOST" "${SITE_AVAILABLE_DIR}/${ROLLBACK_NEW_DOMAIN}.conf"
    delete_file "${SITE_ENABLED_DIR}/${ROLLBACK_NEW_DOMAIN}.conf"
    ln -s "${SITE_AVAILABLE_DIR}/${ROLLBACK_NEW_DOMAIN}.conf" "${SITE_ENABLED_DIR}/${ROLLBACK_NEW_DOMAIN}.conf"

    run_or_exit "Format Nginx config" format_nginx_config "${SITE_AVAILABLE_DIR}/${ROLLBACK_NEW_DOMAIN}.conf"

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        exit 1
    fi

    ## Create new php pool
    run_or_exit "Tao PHP-FPM pool" create_php_pool "${ROLLBACK_NEW_WEB_OWNER}" \
        "${ROLLBACK_NEW_OWNER_FOLDER}" "${ROLLBACK_NEW_DOMAIN}" "${php_version}"

    delete_file "$ROLLBACK_OLD_PHP_POOL"

    ## Edit user linux
    create_system_user "${ROLLBACK_NEW_WEB_OWNER}" "${ROLLBACK_NEW_OWNER_FOLDER}" 'false'

    ## Rename user folder
    run_or_exit "" mv "${WEB_DATA_DIR}/${ROLLBACK_OLD_DOMAIN}" "${WEB_DATA_DIR}/${ROLLBACK_NEW_DOMAIN}"

    ## update setting file
    # shellcheck disable=SC2034
    declare -A site_setting_vars=(
        [domain]="${ROLLBACK_NEW_DOMAIN}"
        [owner]="${ROLLBACK_NEW_WEB_OWNER}"
        [owner_folder]="${ROLLBACK_NEW_OWNER_FOLDER}"
        [base_dir]="/home/${ROLLBACK_NEW_WEB_OWNER}/${ROLLBACK_NEW_DOMAIN}"
        [updated_at]="$(date "+%F %T")"
    )

    run_or_exit "" update_site_setting_vars "${WEB_DATA_DIR}/${ROLLBACK_NEW_DOMAIN}/.settings.conf" site_setting_vars

    ## Change domain if is WordPress
    if is_wordpress "${ROLLBACK_NEW_DOMAIN}" "${ROLLBACK_NEW_OWNER_FOLDER}"; then
        cd_dir "/home/${ROLLBACK_NEW_OWNER_FOLDER}/${ROLLBACK_NEW_DOMAIN}/public_html"
        run_or_exit "Change WordPress Domain" wp search-replace "${ROLLBACK_OLD_DOMAIN}" "${ROLLBACK_NEW_DOMAIN}" --allow-root
        ROLLBACK_WP_CHANGE_DOMAIN='true'
    fi

    restart_specific_php_ver "$php_version"
    nginx_reload

    delete_linux_user "${ROLLBACK_OLD_WEB_OWNER}"

    msg "$ICON_SEARCH Dang kiem tra cau hinh. Vui long doi..."

    set_site_dir_permission --owner "${ROLLBACK_NEW_WEB_OWNER}" --owner_folder "${ROLLBACK_NEW_OWNER_FOLDER}" --domain "${ROLLBACK_NEW_DOMAIN}"

    if ! check_http_status "${ROLLBACK_NEW_DOMAIN}"; then
        msg "${CHECK_HTTP_STATUS_REPLY}"
        exit 1
    fi

    _change_site_domain_success
}

change_website_php_version() {
    local domain="$1"
    local old_php_version="$2"
    local new_php_version="$3"

    if ! test_php_pool_conf --php_version "$old_php_version" --domain "$domain"; then
        msg "$PHP_POOL_T_REPLY"
        exit 1
    fi

    run_or_exit "Change PHP Version" mv "${PHP_BASE_DIR}/${old_php_version}/fpm/pool.d/${domain}.conf" "${PHP_BASE_DIR}/${new_php_version}/fpm/pool.d/${domain}.conf"

    # shellcheck disable=SC2034
    declare -A site_setting_vars=(
        [php_version]="${new_php_version}"
        [updated_at]="$(date "+%F %T")"
    )

    run_or_exit "" update_site_setting_vars "${WEB_DATA_DIR}/${domain}/.settings.conf" site_setting_vars

    sleep 1.5
    reload_specific_php_ver "$old_php_version"
    sleep 1.5
    reload_specific_php_ver "$new_php_version"
}
