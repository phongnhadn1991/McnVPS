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

test_nginx_config() {
    local error_output=''

    msg "$ICON_SEARCH Kiem tra cau hinh Nginx..." "green"

    if ! error_output=$(nginx -t 2>&1); then
          if [[ "$error_output" =~ open\(\)\ \"(/.*?/logs/(access|errors)/(access\.log|error\.log))\".*No\ such\ file ]]; then
              local log_file="${BASH_REMATCH[1]}"
              local base_dir="${log_file%/logs/*}/logs"

              local log_dir_access="$base_dir/access"
              local log_dir_error="$base_dir/errors"

              mkdir -p "$log_dir_access" "$log_dir_error"

              if error_output=$(nginx -t 2>&1); then
                  return 0
              fi
          fi

        NGINX_T_REPLY="$ICON_EXIT Nginx config test failed: $error_output"
        return 1
    fi

    return 0
}

nginx_reload() {
    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        return 1
    fi

    systemctl reload nginx
    return 0
}

nginx_restart() {
    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        return 1
    fi

    systemctl restart nginx
    return 0
}

nginx_stop() {
    systemctl stop nginx
}

nginx_rebuild() {
    local build_dir="/tmp/build"
    local version_response
    local nginx_version
    local more_clear_headers_v
    local ngx_http_geoip2_module_v
    local ngx_http_tls_dyn_size_v

    mkdir -p "$build_dir"
    cd_dir "$build_dir"
    rm -rf "${build_dir:?}/*"

    version_response=$(curl_get_with_retry --url "${GET_VERSION_LINK}") || {
        msg "$ICON_EXIT Failed to get version information from $GET_VERSION_LINK"
        return 1
    }

    extract_key_value "$version_response" "nginx_version"
    nginx_version="$KEY_VALUE_REPLY"

    extract_key_value "$version_response" "more_clear_headers_v"
    more_clear_headers_v="$KEY_VALUE_REPLY"

    extract_key_value "$version_response" "ngx_http_geoip2_module_v"
    ngx_http_geoip2_module_v="$KEY_VALUE_REPLY"

    extract_key_value "$version_response" "ngx_http_tls_dyn_size_v"
    ngx_http_tls_dyn_size_v="$KEY_VALUE_REPLY"

    wget_with_retry --url "https://nginx.org/download/nginx-${nginx_version}.tar.gz" --output "nginx-${nginx_version}.tar.gz" || exit 1
    run_or_exit "" extract_file "nginx-${nginx_version}.tar.gz" && delete_file "nginx-${nginx_version}.tar.gz"

    wget_with_retry --url "${MODULE_LINK}/headers-more-nginx-module-${more_clear_headers_v}.tar.gz" \
        --output "headers-more-nginx-module-${more_clear_headers_v}.tar.gz" || exit 1
    run_or_exit "" extract_file "headers-more-nginx-module-${more_clear_headers_v}.tar.gz" && delete_file "headers-more-nginx-module-${more_clear_headers_v}.tar.gz"

    wget_with_retry --url "${MODULE_LINK}/ngx_http_geoip2_module-${ngx_http_geoip2_module_v}.tar.gz" \
        --output "ngx_http_geoip2_module-${ngx_http_geoip2_module_v}.tar.gz" || exit 1
    run_or_exit "" extract_file "ngx_http_geoip2_module-${ngx_http_geoip2_module_v}.tar.gz" && delete_file "ngx_http_geoip2_module-${ngx_http_geoip2_module_v}.tar.gz"

    if [ -d "${build_dir}/ngx_brotli" ]; then
        delete_dir "${build_dir}/ngx_brotli"
    fi

    cd_dir "$build_dir"
    git_clone_with_retry --repo_url "https://github.com/google/ngx_brotli" --repo_dir "ngx_brotli" || exit 1

    cd_dir ngx_brotli/deps/brotli
    mkdir out && cd_dir out
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
    cmake --build . --config Release --target brotlienc

    cd_dir "${build_dir}"/nginx-"${nginx_version}"/
    wget_with_retry --url "https://raw.githubusercontent.com/nginx-modules/ngx_http_tls_dyn_size/refs/heads/master/nginx__dynamic_tls_records_${ngx_http_tls_dyn_size_v}%2B.patch" \
        --output "nginx__dynamic_tls_records_${ngx_http_tls_dyn_size_v}.patch" || exit 1

    export CFLAGS="${CFLAGS} -fpermissive"
    cd_dir "${build_dir}"/nginx-"${nginx_version}"/

    run_or_exit "configure Nginx" ./configure \
        "--user=nginx" \
        "--group=nginx" \
        "--prefix=/usr" \
        "--sbin-path=/usr/sbin" \
        "--conf-path=/etc/nginx/nginx.conf" \
        "--pid-path=/var/run/nginx.pid" \
        "--http-log-path=/var/log/nginx/access/access.log" \
        "--error-log-path=/var/log/nginx/errors/error.log" \
        "--without-mail_imap_module" \
        "--without-mail_smtp_module" \
        "--with-http_ssl_module" \
        "--with-http_sub_module" \
        "--with-http_realip_module" \
        "--with-http_stub_status_module" \
        "--with-http_gzip_static_module" \
        "--with-http_dav_module" \
        "--with-http_v2_module" \
        "--with-http_v3_module" \
        "--with-threads" \
        "--with-file-aio" \
        "--with-pcre-jit" \
        "--with-http_geoip_module" \
        "--add-module=../ngx_http_geoip2_module-${ngx_http_geoip2_module_v}" \
        "--add-module=../headers-more-nginx-module-${more_clear_headers_v}" \
        "--add-module=../ngx_brotli" \
        "--with-cc-opt='-D FD_SETSIZE=32768'"

    run_or_exit "Build Nginx" make -j"${CPU_CORES}"

    patch -p1 < "nginx__dynamic_tls_records_${ngx_http_tls_dyn_size_v}.patch"

    systemctl stop nginx
    run_or_exit "Install Nginx" make install -j"${CPU_CORES}"

    # shellcheck disable=SC2002
    # shellcheck disable=SC2143
    if [[ -z "$(cat /etc/passwd | grep nginx)" ]]; then
        run_or_exit "Add Nginx user" adduser --system --home /nonexistent --shell /bin/false --no-create-home \
            --disabled-login --disabled-password --gecos "nginx user" --group nginx
    fi

    cat >"/etc/systemd/system/nginx.service" <<EOnginx_service
[Unit]
Description=The nginx HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx.conf
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true
LimitMEMLOCK=infinity
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOnginx_service

    systemctl daemon-reload

    if [[ -z "$(which nginx)" ]]; then
        # shellcheck disable=SC2059
        printf "${RED}Rebuild Nginx Failed${NC}\n"
        exit 1
    fi

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        return 1
    fi

    systemctl enable nginx.service
    systemctl restart nginx.service

    return 0
}
