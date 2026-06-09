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

if [ -z "${MAX_MEMORY}" ]; then
    source "${MENU_DIR}/helpers/php_variables.sh"
fi

if ! declare -f extract_file >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/file.sh"
fi

if ! declare -f is_valid_domain >/dev/null 2>&1; then
    source "${MENU_DIR}/validate/rule.sh"
fi

_build_php_ext_from_source() {
    local name="$1"
    local version="$2"
    local config_args="$3"
    local ini_priority="$4"

    local folder="$BUILD_DIR/${name}-${version}"
    local ini_file="${PHP_MODULES_PATH}/${name}.ini"

    echo "📦 Dang cai dat extension: ${name} v${version}"

    cd "$folder" || return 1

    run_or_exit "Prepare compile PHP ${name}" /usr/bin/phpize"${PHP_NEW_VERSION}"
    # shellcheck disable=SC2086
    run_or_exit "configure PHP ${name}" ./configure --with-php-config="/usr/bin/php-config${PHP_NEW_VERSION}" ${config_args}
    run_or_exit "Build PHP ${name}" make -j"${CPU_CORES:-1}"
    run_or_exit "Install PHP ${name}" make install -j"${CPU_CORES:-1}"

    echo "extension=${name}.so" >"$ini_file"
    create_symlink "$ini_file" "${PHP_INI_PATH}/${ini_priority}-${name}.ini"
    create_symlink "$ini_file" "${PHP_CLI_PATH}/${ini_priority}-${name}.ini"

    msg "$ICON_CHECK Cai dat xong ${name}" "blue"
}

_install_php_ext() {
    local version_response
    local igbinary_version
    local php_memcached_version
    local php_redis_version

    if [[ "${PHP_NEW_VERSION}" == "5.6" ]]; then
        igbinary_version="2.0.8"
        php_memcached_version="2.2.0"
        php_redis_version="4.3.0"
    else
        version_response=$(curl_get_with_retry --url "${GET_VERSION_LINK}") || {
            msg "$ICON_EXIT Da xay ra loi khi lay danh sach phien ban"
            return 1
        }

        extract_key_value "${version_response}" "igbinary_version" 'true'
        # shellcheck disable=SC2206
        igbinary_version="${KEY_VALUE_REPLY}"

        extract_key_value "${version_response}" "php_memcached_version" 'true'
        # shellcheck disable=SC2206
        php_memcached_version="${KEY_VALUE_REPLY}"

        extract_key_value "${version_response}" "php_redis_version" 'true'
        # shellcheck disable=SC2206
        php_redis_version="${KEY_VALUE_REPLY}"
    fi

    local php_config_path="/etc/php/${PHP_NEW_VERSION}/fpm"
    local php_pool_path="${php_config_path}/pool.d"
    local php_default_pool_file="${php_pool_path}/www.conf"
    local php_global_config_file="${php_config_path}/php-fpm.conf"

    PHP_INI_PATH="${php_config_path}/conf.d"
    PHP_CLI_PATH="/etc/php/${PHP_NEW_VERSION}/cli/conf.d"
    PHP_MODULES_PATH="/etc/php/${PHP_NEW_VERSION}/mods-available"

    if [[ "$PHP_MAJOR_VERSION" == '7' ]]; then
        if [[ $PHP_MINOR_VERSION -lt 2 ]]; then
            php_redis_version="5.3.7"
        elif [[ $PHP_MINOR_VERSION -lt 4 ]]; then
            php_redis_version="6.0.2"
        fi
    fi

    mkdir -p "$BUILD_DIR"
    cd_dir "$BUILD_DIR"
    rm -rf ./*

    wget_with_retry --url "${MODULE_LINK}/igbinary-${igbinary_version}.tgz" --output "igbinary-${igbinary_version}.tgz" || return 1
    run_or_exit "" extract_file "igbinary-${igbinary_version}.tgz" && delete_file "igbinary-${igbinary_version}.tgz"

    wget_with_retry --url "${MODULE_LINK}/memcached-${php_memcached_version}.tgz" --output "memcached-${php_memcached_version}.tgz" || return 1
    run_or_exit "" extract_file "memcached-${php_memcached_version}.tgz" && delete_file "memcached-${php_memcached_version}.tgz"

    wget_with_retry --url "${MODULE_LINK}/redis-${php_redis_version}.tgz" --output "redis-${php_redis_version}.tgz" || return 1
    run_or_exit "" extract_file "redis-${php_redis_version}.tgz" && delete_file "redis-${php_redis_version}.tgz"

    _build_php_ext_from_source "igbinary" "${igbinary_version}" "" 30

    local check_igbinary=''
    local memcached_config_args=''
    local redis_config_args='--enable-redis-zstd'

    if [[ -x "/usr/bin/php${PHP_NEW_VERSION}" ]]; then
        if /usr/bin/php"${PHP_NEW_VERSION}" -m | grep -q '^igbinary$'; then
            check_igbinary='true'
        fi
    fi

    if [[ "$check_igbinary" == 'true' ]]; then
        memcached_config_args='--enable-memcached-igbinary'
        redis_config_args+=' --enable-redis-igbinary'
    fi

    if [[ -e "/usr/include/lz4.h" && -e "/usr/lib/x86_64-linux-gnu/liblz4.so" ]]; then
        redis_config_args+=' --enable-redis-lz4 --with-liblz4=/usr'
    fi

    _build_php_ext_from_source "memcached" "${php_memcached_version}" "$memcached_config_args" 30
    _build_php_ext_from_source "redis" "${php_redis_version}" "$redis_config_args" 30

    if [[ -e "/etc/php/ioncube/ioncube_loader_lin_${PHP_NEW_VERSION}.so" ]]; then
        cat >"${PHP_MODULES_PATH}/ioncube.ini" <<END
zend_extension=/etc/php/ioncube/ioncube_loader_lin_${PHP_NEW_VERSION}.so
END

        create_symlink "${PHP_MODULES_PATH}/ioncube.ini" "${PHP_INI_PATH}/01-ioncube.ini"
        create_symlink "${PHP_MODULES_PATH}/ioncube.ini" "${PHP_CLI_PATH}/01-ioncube.ini"
    fi

    cat >"${php_global_config_file}"<<END
;;;;;;;;;;;;;;;;;;;;;
; FPM Configuration ;
;;;;;;;;;;;;;;;;;;;;;

include=${php_pool_path}/*.conf

[global]
pid = /run/php/php${PHP_NEW_VERSION}-fpm.pid
error_log = /var/log/php-fpm/error.log
log_level = warning
emergency_restart_threshold = 10
emergency_restart_interval = 1m
process_control_timeout = 10s
daemonize = yes
END

    cat >"${php_default_pool_file}"<<END
[www]
listen = /var/run/php${PHP_NEW_VERSION}-fpm.sock;
listen.allowed_clients = 127.0.0.1
listen.owner = nginx
listen.group = nginx
listen.mode = 0660
user = nginx
group = nginx
pm = ondemand
pm.max_children = ${PM_MAX_CHILDREN}
pm.max_requests = ${PM_MAX_REQUEST}
pm.process_idle_timeout = 20
;slowlog = /var/log/php-fpm/slow/slow.log
chdir = /
php_admin_value[error_log] = /var/log/php-fpm/error/error.log
php_admin_flag[log_errors] = on
php_value[session.save_handler] = files
php_value[session.save_path]    = /var/lib/php/session
php_value[soap.wsdl_cache_dir]  = /var/lib/php/wsdlcache
php_admin_value[disable_functions] = exec,system,passthru,shell_exec,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname
php_admin_value[open_basedir] = /tmp/:/var/tmp/:/dev/urandom:/usr/share/php/:/dev/shm:/var/lib/php/sessions/:/var/www/
security.limit_extensions = .php
END

    local opcache_jit_config="opcache.jit=disable"
    if [[ "${PHP_MAJOR_VERSION}" -gt 8 ]] || [[ "${PHP_MAJOR_VERSION}" -eq 8 && "${PHP_MINOR_VERSION}" -ge 1 ]]; then
        opcache_jit_config="opcache.jit=tracing
opcache.jit_buffer_size=${OPCACHE_JIT_BUFFER}M"
    fi

     cat >"${PHP_MODULES_PATH}/opcache.ini" <<EOphp_opcache
zend_extension=opcache.so
${opcache_jit_config}
opcache.enable=1
opcache.memory_consumption=${OPCACHE_MEM}
opcache.interned_strings_buffer=${OPCACHE_STRINGS_BUFFER}
opcache.max_wasted_percentage=5
opcache.max_accelerated_files=65407
opcache.revalidate_freq=180
opcache.fast_shutdown=0
opcache.enable_cli=0
opcache.save_comments=1
opcache.enable_file_override=1
opcache.validate_timestamps=1
opcache.blacklist_filename=${PHP_MODULES_PATH}/opcache-default.blacklist
EOphp_opcache

    cat >"${PHP_MODULES_PATH}/opcache-default.blacklist" <<EOopcache_blacklist
/home/*/*/public_html/wp-content/plugins/backwpup/*
/home/*/*/public_html/wp-content/plugins/duplicator/*
/home/*/*/public_html/wp-content/plugins/updraftplus/*
/home/*/*/public_html/wp-content/cache/*
/home/*/*/public_html/wp-content/uploads/*
/home/*/*/public_html/storage/*
EOopcache_blacklist

    cat >"${PHP_MODULES_PATH}/hostvn-custom.ini" <<EOhostvn_custom_ini
date.timezone = Asia/Ho_Chi_Minh
max_execution_time = 600
max_input_time = 600
short_open_tag = On
realpath_cache_size = ${PHP_REAL_PATH_LIMIT}
realpath_cache_ttl = ${PHP_REAL_PATH_TTL}
memory_limit = ${MAX_MEMORY}M
upload_max_filesize = ${MAX_MEMORY}M
post_max_size = ${MAX_MEMORY}M
expose_php = Off
display_errors = Off
mail.add_x_header = Off
max_input_nesting_level = 128
max_input_vars = ${MAX_INPUT_VARS}
mysqlnd.net_cmd_buffer_size = 16384
mysqlnd.collect_memory_statistics = Off
mysqlnd.mempool_default_size = 16000
always_populate_raw_post_data=-1
error_reporting = E_ALL & ~E_NOTICE
EOhostvn_custom_ini

    delete_file "${PHP_CLI_PATH}/00-hostvn-custom.ini"
    delete_file "${PHP_INI_PATH}/00-hostvn-custom.ini"

    ln -s "${PHP_MODULES_PATH}/hostvn-custom.ini" "${PHP_CLI_PATH}/00-hostvn-custom.ini"
    ln -s "${PHP_MODULES_PATH}/hostvn-custom.ini" "${PHP_INI_PATH}/00-hostvn-custom.ini"

    cd_dir /opt
    delete_dir "$BUILD_DIR"
}

reload_specific_php_ver(){
    local php_version="$1"

    if [ -z "$php_version" ]; then
        return 1
    fi

    systemctl reload php"$php_version"-fpm
}

#restart_specific_php_ver(){
#    local php_version="$1"
#
#    if [ -z "$php_version" ]; then
#        return 1
#    fi
#
#    systemctl restart php"$php_version"-fpm
#}

restart_specific_php_ver(){
    local php_version="$1"

    if [ -z "$php_version" ]; then
        return 1
    fi

    local pool_dir="/etc/php/${php_version}/fpm/pool.d"
    if [ ! -d "$pool_dir" ]; then
        msg "$ICON_ERROR Khong tim thay thu muc $pool_dir"
        return 1
    fi

    local missing_users=()

    for pool_file in "$pool_dir"/*.conf; do
        [ -e "$pool_file" ] || continue

        local filename="${pool_file##*/}"
        local domain="${filename%.conf}"

        if ! is_valid_domain "$domain"; then
            continue
        fi

        local pool_user
        pool_user=$(grep -m1 -E '^\s*\[[^]]+\]\s*$' "$pool_file" \
            | sed 's/^\s*\[\(.*\)\]\s*$/\1/')

        if [ -n "$pool_user" ]; then
            if ! id "$pool_user" &>/dev/null; then
                missing_users+=("$pool_user (domain: $domain)")
            fi
        fi
    done

    if [ "${#missing_users[@]}" -gt 0 ]; then
        msg "⚠️ Khong the restart php${php_version}-fpm. Thieu user:"
        printf '  - %s\n' "${missing_users[@]}"
        return 1
    fi

    systemctl restart "php${php_version}-fpm"
    return 0
}

create_php_pool() {
    local owner="$1"
    local owner_home="$2"
    local domain="$3"
    local php_version="$4"

    ROLLBACK_PHP_CONF="/etc/php/${php_version}/fpm/pool.d/${domain}.conf"
    local basedir="/home/${owner_home}/${domain}"
    local php_errors_log_dir="${basedir}/php/logs/errors"
    local php_slow_log_dir="${basedir}/php/logs/slow"
    local php_session_dir="${basedir}/php/sessions"

    mkdir -p "$php_errors_log_dir" "$php_slow_log_dir" "$php_session_dir"
    chmod 700 "$php_session_dir"

    local memory_limit="${MAX_MEMORY:-256}"
    local post_max_size="${MAX_MEMORY:-256}"
    local upload_max_filesize="${MAX_MEMORY:-256}"
    local max_input_time="600"
    local max_execution_time="600"

    local settings_file="${WEB_DATA_DIR}/${domain}/.settings.conf"
    if [[ -e "${settings_file}" && -s "${settings_file}" ]]; then
        # shellcheck disable=SC1090
        source "${settings_file}"

        memory_limit="${php_memory_limit:-$memory_limit}"
        post_max_size="${php_post_max_size:-$post_max_size}"
        upload_max_filesize="${php_upload_max_filesize:-$upload_max_filesize}"
        max_input_time="${php_max_input_time:-$max_input_time}"
        max_execution_time="${php_max_execution_time:-$max_execution_time}"
    fi

    run_or_exit "" perl -pe "
        s|__WEBSITE_USER__|${owner}|g;
        s|__OWNER_FOLDER__|${owner_home}|g;
        s|__DOMAIN__|${domain}|g;
        s|__PM_MAX_CHILDREN__|${PM_MAX_CHILDREN}|g;
        s|__PM_MAX_REQUEST__|${PM_MAX_REQUEST}|g;
        s|__PM_START_SERVERS__|${PM_START_SERVERS}|g;
        s|__PM_MIN_SPARE_SERVER__|${PM_MIN_SPARE_SERVER}|g;
        s|__PM_MAX_SPARE_SERVER__|${PM_MAX_SPARE_SERVER}|g;
        s|__SLOW_LOG__|${php_slow_log_dir}/slow.log|g;
        s|__ERROR_LOG_PATH__|${php_errors_log_dir}/error.log|g;
        s|__SESSION_PATH__|${php_session_dir}|g;
        s|__PHP_PM_TYPE__|ondemand|g;
        s|__PHP_MEMORY_LIMIT__|${memory_limit}M|g;
        s|__PHP_POST_MAX_SIZE__|${post_max_size}M|g;
        s|__PHP_UPLOAD_MAX_FILESIZE__|${upload_max_filesize}M|g;
        s|__PHP_MAX_EXECUTION_TIME__|${max_execution_time}|g;
        s|__PHP_MAX_INPUT_TIME__|${max_input_time}|g;
    " "${TEMPLATES_DIR}/php/pool.conf" > "$ROLLBACK_PHP_CONF"
}

strip_proc_functions() {
    local pool_file="$1"

    if [ ! -e "$pool_file" ]; then
        return 1
    fi

    run_or_exit "" sed -i -E \
       -e 's/\bproc_open\b,?//g' \
       -e 's/\bproc_close\b,?//g' \
       -e 's/,,/,/g' \
       -e 's/=\s*,/=/g' \
       -e 's/,\s*$//' \
       "$pool_file"
}

install_php() {
    PHP_NEW_VERSION="$1"
    PHP_MAJOR_VERSION=$(echo "${PHP_NEW_VERSION}" | cut -d'.' -f1)
    PHP_MINOR_VERSION=$(echo "${PHP_NEW_VERSION}" | cut -d'.' -f2)

    safe_apt_install "PHP ${PHP_NEW_VERSION}" php"${PHP_NEW_VERSION}" php"${PHP_NEW_VERSION}"-fpm \
        php"${PHP_NEW_VERSION}"-ldap php"${PHP_NEW_VERSION}"-zip \
        php"${PHP_NEW_VERSION}"-cli php"${PHP_NEW_VERSION}"-mysql php"${PHP_NEW_VERSION}"-gd php"${PHP_NEW_VERSION}"-xml \
        php"${PHP_NEW_VERSION}"-mbstring php"${PHP_NEW_VERSION}"-common php"${PHP_NEW_VERSION}"-soap \
        php"${PHP_NEW_VERSION}"-curl php"${PHP_NEW_VERSION}"-bcmath php"${PHP_NEW_VERSION}"-snmp php"${PHP_NEW_VERSION}"-pspell \
        php"${PHP_NEW_VERSION}"-gmp php"${PHP_NEW_VERSION}"-intl php"${PHP_NEW_VERSION}"-enchant \
        php"${PHP_NEW_VERSION}"-xmlrpc php"${PHP_NEW_VERSION}"-tidy php"${PHP_NEW_VERSION}"-opcache php"${PHP_NEW_VERSION}"-cli \
        php"${PHP_NEW_VERSION}"-dev php"${PHP_NEW_VERSION}"-sqlite3 php"${PHP_NEW_VERSION}"-imagick

    if [[ ${PHP_MAJOR_VERSION} -lt 8 ]]; then
        safe_apt_install "php-json" php"${PHP_NEW_VERSION}"-json
    fi

    if [ "${PHP_NEW_VERSION}" == "5.6" ]; then
        safe_apt_install "php5.6-mcrypt" php5.6-mcrypt
    fi

    case "$OS" in
        debian)
            if [[ "$OS_VERSION" == '12' ]]; then
                safe_apt_install "Install php${PHP_NEW_VERSION}-imap" "php${PHP_NEW_VERSION}-imap"
            fi
            ;;
        ubuntu)
            safe_apt_install "Install php${PHP_NEW_VERSION}-imap" "php${PHP_NEW_VERSION}-imap"
            ;;
    esac

    if [[ ! -e /usr/bin/php"${PHP_NEW_VERSION}" ]]; then
        # shellcheck disable=SC2059
        printf "${RED}Cannot install PHP ${PHP_NEW_VERSION}${NC}\n"
        exit 1
    fi

    patch_systemd_unit_file "php${PHP_NEW_VERSION}-fpm" 'php'
    _install_php_ext
    systemctl enable php"${PHP_NEW_VERSION}"-fpm.service
    restart_specific_php_ver "${PHP_NEW_VERSION}"
    clear_screen

    local php_status
    php_status=$(systemctl is-active php"${PHP_NEW_VERSION}"-fpm.service)

    if [ "$php_status" == 'active' ]; then
        msg "$ICON_CHECK Cai dat PHP ${PHP_NEW_VERSION} thanh cong!" 'green'
        press_enter_to_continue; return 0
    fi

    msg "$ICON_EXIT Da cai dat PHP ${PHP_NEW_VERSION} tuy nhien da xay ra loi. PHP ${PHP_NEW_VERSION} khong hoat dong"
    exit 1
}

uninstall_php() {
    local php_version="$1"

    apt-get remove --purge php"${php_version}" php"${php_version}*" php"${php_version}-*" -y
    apt-get autoremove --purge -y

    delete_dir "/etc/php/$php_version"
    find /var/lib/dpkg/info -name "php${php_version}*" -delete
}

clear_opcache() {
    local php_user="$1"
    local php_version="$2"
    local cache_tool_ver cache_tool_file

    if [[ -z "$php_user" || -z "$php_version" ]]; then
        return 1
    fi

    cache_tool_ver="$(get_cache_tool_version)"

    if [[ -n "$cache_tool_ver" ]]; then
        cache_tool_file="${HOSTVN_DIR}/tools/cachetool${cache_tool_ver}"

        if [[ ! -e "$cache_tool_file" ]]; then
            mkdir -p "${HOSTVN_DIR}/tools"
            wget_with_retry --url "${MODULE_LINK}/cache-tool/${cache_tool_ver}/cachetool.phar" \
                --output "${cache_tool_file}" || return 1

            chmod +x "${cache_tool_file}"
            clear_screen
        fi
    fi

    if [[ -n "$cachetool_ver" && -e "$cache_tool_file" ]]; then
        php "${cache_tool_file}" opcache:reset --fcgi="/var/run/php/${php_user}.sock"
    else
        reload_specific_php_ver "$php_version"
    fi

    return 0
}

get_php_pool_value() {
    local pool_file="$1"

    if [[ -z "$pool_file" ]]; then
        msg "Usage: get_php_pool_value </pool_file>"
    fi

    if [[ ! -f "$pool_file" ]]; then
        msg "$ICON_ERROR File $pool_file khong ton tai"
        exit 1
    fi

    declare -gA PHP_FPM_POOL_VALUE

    while IFS='=' read -r key value; do
        key="$(echo "$key" | xargs)"
        value="$(echo "$value" | xargs)"
        # shellcheck disable=SC2034
        [[ -n "$key" && -n "$value" ]] && PHP_FPM_POOL_VALUE["$key"]="$value"
    done < "$pool_file"

    return 0
}

re_create_php_log_path() {
    local pool_file="$1"

    if [[ -z "$pool_file" ]]; then
        msg "Usage: create_missing_php_log_path </pool_file>"
    fi

    get_php_pool_value "$pool_file"
    if [ ${#PHP_FPM_POOL_VALUE[@]} -gt 0 ]; then
        for key in "php_admin_value[error_log]" \
                   "php_value[session.save_path]" \
                   "slowlog"; do
            path="${PHP_FPM_POOL_VALUE["$key"]}"
            [ -n "$path" ] && mkdir -p "$path"
        done
    fi
}

test_php_pool_conf() {
    local php_version
    local domain
    local output pool_file

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --php_version) php_version="$2"; shift 2 ;;
            --domain)      domain="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$php_version" || -z "$domain" ]]; then
        msg "Usage: test_php_pool_conf --php_version <php_version> --domain <domain>"
        return 1
    fi

    pool_file="${PHP_BASE_DIR}/${php_version}/fpm/pool.d/${domain}.conf"
    if [ ! -e "${pool_file}" ]; then
        PHP_POOL_T_REPLY="$ICON_EXIT File cau hinh PHP-FPM pool ${pool_file} khong ton tai"
        return 1
    fi

    msg "$ICON_SEARCH Kiem tra cau hinh PHP..." "green"

    if [ -z "$(which php-fpm"${php_version}")" ]; then
        return 0
    fi

    re_create_php_log_path "$pool_file"

    if output=$(php-fpm"${php_version}" -t -y "$pool_file" 2>&1); then
        return 0
    fi

    # shellcheck disable=SC2034
    PHP_POOL_T_REPLY="$output"
    return 1
}
