#!/bin/bash

##############################################################################################################
#                             Auto Install & Optimize LEMP Stack on Ubuntu                                   #
#                                                                                                            #
#                                    Author: Sanvv - MCN Technical                                           #
#                                        Website: https://mcnvps.net                                         #
#                                                                                                            #
#                                  Please do not remove copyright. Thank!                                    #
#  Copying or using this content for any commercial purpose is strictly prohibited under all circumstances!  #
##############################################################################################################

if ! declare -f create_system_user >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_linux_user.sh"
fi

if ! declare -f save_website_settings >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_website.sh"
fi

if ! declare -f generate_nginx_vhost >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_vhost.sh"
fi

if ! declare -f test_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_nginx.sh"
fi

if ! declare -f create_database >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_mysql.sh"
fi

if ! declare -f create_php_pool >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_php.sh"
fi

_migrate_ssh_cmd() {
    local ssh_cmd="$1"
    shift
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -i "$MIGRATE_SSH_KEY" -p "$MIGRATE_SSH_PORT" \
        "root@${MIGRATE_SSH_IP}" "$@" 2>/dev/null
}

_migrate_ssh() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -i "$MIGRATE_SSH_KEY" -p "$MIGRATE_SSH_PORT" \
        "root@${MIGRATE_SSH_IP}" "$@" 2>/dev/null
}

_migrate_scp() {
    scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -i "$MIGRATE_SSH_KEY" -P "$MIGRATE_SSH_PORT" "$@" 2>/dev/null
}

migrate_website() {
    clear_screen
    echo "${GREEN}========== MIGRATE WEBSITE TU SERVER KHAC ==========${NC}"
    echo ""
    echo "Chuyen website tu server cu sang server nay (MCN Script)"
    echo "Bao gom: source code, database, SSL certificate"
    echo "${RED}----------------------------------${NC}"
    echo ""

    # SSH info server cu
    local ssh_ip ssh_port ssh_key
    local MIGRATE_KEY_CREATED=false

    read -rp "IP server cu: " ssh_ip
    [[ -z "$ssh_ip" ]] && { msg "$ICON_EXIT IP khong duoc de trong!"; press_enter_to_continue; return 0; }

    read -rp "SSH Port (mac dinh 22): " ssh_port
    ssh_port="${ssh_port:-22}"

    MIGRATE_SSH_IP="$ssh_ip"
    MIGRATE_SSH_PORT="$ssh_port"

    # SSH Key setup
    echo ""
    echo "${BLUE}== Thiet lap SSH Key ==${NC}"
    echo "  1) Nhap duong dan SSH Key co san"
    echo "  2) Tu dong tao SSH Key moi"
    echo "  ${RED}0) Huy${NC}"
    read -rp "Chon: " key_choice

    case "$key_choice" in
        1)
            read -rp "Duong dan SSH Key: " ssh_key
            MIGRATE_SSH_KEY="${ssh_key:-/root/.ssh/id_rsa}"
            ;;
        2)
            local migrate_key="/root/.ssh/id_rsa_migrate"
            if [[ -f "$migrate_key" ]]; then
                msg "$ICON_CHECK SSH Key migrate da ton tai: ${migrate_key}" "green"
            else
                msg "$ICON_TOOL Dang tao SSH Key moi..."
                ssh-keygen -t rsa -b 4096 -N "" -f "$migrate_key" -q
                msg "$ICON_CHECK Da tao SSH Key: ${migrate_key}" "green"
            fi
            MIGRATE_KEY_CREATED=true
            MIGRATE_SSH_KEY="$migrate_key"

            echo ""
            echo "${GREEN}========== PUBLIC KEY ==========${NC}"
            echo ""
            cat "${migrate_key}.pub"
            echo ""
            echo "${GREEN}================================${NC}"
            echo ""
            echo "${BLUE}Hay chay lenh sau tren LOCAL de add key vao server cu:${NC}"
            echo ""
            echo "  ssh root@${ssh_ip} -p ${ssh_port} \"mkdir -p ~/.ssh && echo '$(cat "${migrate_key}.pub")' >> ~/.ssh/authorized_keys\""
            echo ""
            echo "${RED}Hoac copy PUBLIC KEY phia tren va paste vao file ~/.ssh/authorized_keys tren server cu.${NC}"
            echo ""
            read -rp "Nhan Enter sau khi da add key vao server cu... "
            ;;
        0) return 0 ;;
        *) msg "$ICON_EXIT Lua chon khong hop le!"; press_enter_to_continue; return 0 ;;
    esac

    # Test connection
    msg "$ICON_TOOL Dang ket noi toi server cu..."
    if ! _migrate_ssh "echo OK" &>/dev/null; then
        msg "$ICON_EXIT Khong the ket noi! Kiem tra lai IP, port va SSH key."
        press_enter_to_continue; return 0
    fi
    msg "$ICON_CHECK Ket noi thanh cong!" "green"

    # Detect server version
    echo ""
    msg "$ICON_TOOL Dang kiem tra phien ban server cu..."
    local MIGRATE_SERVER_VERSION="unknown"
    local version_check
    version_check=$(_migrate_ssh "
        if [[ -f /etc/mcnvps.lock ]]; then
            echo 'mcnscript'
        elif [[ -f /etc/hostvn.lock ]]; then
            echo 'hostvn'
        else
            echo 'unknown'
        fi
    ")
    MIGRATE_SERVER_VERSION="$version_check"

    case "$MIGRATE_SERVER_VERSION" in
        mcnscript) msg "$ICON_CHECK Server cu: MCN Script" "green" ;;
        hostvn)    msg "$ICON_CHECK Server cu: HostVN Script (ver cu)" "green" ;;
        *)         msg "$ICON_WARNING Server cu: Khong xac dinh duoc phien ban" ;;
    esac

    # Server overview
    echo ""
    msg "$ICON_TOOL Dang quet thong tin server cu..."
    local server_overview
    server_overview=$(_migrate_ssh "
        # Count sites
        site_count=\$(find /home/*/public_html -maxdepth 1 \\( -name 'wp-config.php' -o -name 'index.php' \\) 2>/dev/null | sed 's|/public_html/.*||' | sort -u | wc -l)
        echo \"SITE_COUNT=\${site_count}\"

        # Count databases
        db_count=\$(mysql -N -e 'SHOW DATABASES' 2>/dev/null | grep -vcE '^(information_schema|performance_schema|mysql|sys)\$' || echo 0)
        echo \"DB_COUNT=\${db_count}\"

        # Count SSL
        ssl_count=\$(find /etc/nginx/ssl/ -maxdepth 1 -type d 2>/dev/null | grep -v '^/etc/nginx/ssl/\$' | grep -vc 'default' || echo 0)
        echo \"SSL_COUNT=\${ssl_count}\"

        # Disk usage
        disk_used=\$(du -sh /home/ 2>/dev/null | awk '{print \$1}')
        echo \"DISK_USED=\${disk_used}\"

        # OS info
        os_info=\$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'\"' -f2)
        echo \"OS_INFO=\${os_info}\"
    ")

    local site_count db_count ssl_count disk_used os_info
    eval "$(echo "$server_overview" | grep '^SITE_COUNT=')"
    eval "$(echo "$server_overview" | grep '^DB_COUNT=')"
    eval "$(echo "$server_overview" | grep '^SSL_COUNT=')"
    eval "$(echo "$server_overview" | grep '^DISK_USED=')"
    eval "$(echo "$server_overview" | grep '^OS_INFO=')"

    echo ""
    echo "${GREEN}========== THONG TIN SERVER CU ==========${NC}"
    echo "  IP          : ${ssh_ip}"
    echo "  OS          : ${OS_INFO}"
    echo "  Phien ban   : ${MIGRATE_SERVER_VERSION}"
    echo "  So website  : ${SITE_COUNT}"
    echo "  So database : ${DB_COUNT}"
    echo "  So SSL cert : ${SSL_COUNT}"
    echo "  Dung luong  : ${DISK_USED}"
    echo "${GREEN}=========================================${NC}"
    echo ""

    # List sites on old server
    msg "$ICON_TOOL Dang liet ke cac website..."
    local remote_sites

    if [[ "$MIGRATE_SERVER_VERSION" == "mcnscript" ]]; then
        # MCN Script: doc tu .settings.conf
        remote_sites=$(_migrate_ssh "find /home/ -name '.settings.conf' -path '*/public_html/../.settings.conf' 2>/dev/null | while read -r conf; do dirname \"\$conf\" | xargs basename; done | sort -u")
    else
        # Ver cu (hostvn/unknown): scan public_html
        remote_sites=$(_migrate_ssh "find /home/*/public_html -maxdepth 1 \\( -name 'wp-config.php' -o -name 'index.php' \\) 2>/dev/null | sed 's|/public_html/.*||' | sort -u | while read -r dir; do basename \"\$dir\"; done | sort -u")
    fi

    if [[ -z "$remote_sites" ]]; then
        msg "$ICON_EXIT Khong tim thay website nao tren server cu!"
        press_enter_to_continue; return 0
    fi

    echo ""
    echo "${GREEN}Danh sach website tren server cu:${NC}"
    local site_list=()
    local i=1
    while IFS= read -r site; do
        [[ -z "$site" ]] && continue
        site_list+=("$site")

        local site_db="none" site_ssl="No"

        if [[ "$MIGRATE_SERVER_VERSION" == "mcnscript" ]]; then
            # MCN: doc .settings.conf
            site_db=$(_migrate_ssh "grep '^db_name=' /home/*/${site}/.settings.conf 2>/dev/null | head -1 | cut -d'=' -f2" 2>/dev/null)
            site_ssl=$(_migrate_ssh "[[ -d '/etc/nginx/ssl/${site}' ]] && echo 'Yes' || echo 'No'" 2>/dev/null)
        else
            # Ver cu: doc wp-config.php
            site_db=$(_migrate_ssh "
                wp_conf=\$(find /home/ -path \"*/${site}/public_html/wp-config.php\" -o -path \"*/${site}/wp-config.php\" 2>/dev/null | head -1)
                [[ -n \"\$wp_conf\" ]] && grep DB_NAME \"\$wp_conf\" 2>/dev/null | cut -d\"'\" -f4
            " 2>/dev/null)
            site_ssl=$(_migrate_ssh "[[ -d '/etc/nginx/ssl/${site}' ]] && echo 'Yes' || echo 'No'" 2>/dev/null)
        fi

        printf "  %d) %-40s DB: %-15s SSL: %s\n" "$i" "$site" "${site_db:-none}" "${site_ssl:-No}"
        ((i++))
    done <<< "$remote_sites"
    echo "  ${RED}0) Huy thao tac${NC}"
    echo ""

    # Select sites
    read -rp "Nhap so thu tu (cach nhau boi dau phay, hoac 'all' de chon tat ca): " selection

    [[ "$selection" == "0" ]] && return 0

    local selected_domains=()
    if [[ "$selection" == "all" ]]; then
        selected_domains=("${site_list[@]}")
    else
        IFS=',' read -ra sel_arr <<< "$selection"
        for s in "${sel_arr[@]}"; do
            s=$(echo "$s" | tr -d ' ')
            if [[ "$s" =~ ^[0-9]+$ ]] && (( s >= 1 && s <= ${#site_list[@]} )); then
                selected_domains+=("${site_list[$((s-1))]}")
            fi
        done
    fi

    if [[ ${#selected_domains[@]} -eq 0 ]]; then
        msg "$ICON_EXIT Khong co domain nao duoc chon!"
        press_enter_to_continue; return 0
    fi

    echo ""
    echo "${GREEN}Se migrate ${#selected_domains[@]} website:${NC}"
    for d in "${selected_domains[@]}"; do
        echo "  - ${d}"
    done
    echo ""

    if ! prompt_yes_no "Bat dau migrate?"; then
        return 0
    fi

    # Migrate each domain
    local success_count=0
    local fail_count=0
    local results=()

    for domain in "${selected_domains[@]}"; do
        echo ""
        echo "${BLUE}============================================${NC}"
        echo "${BLUE}  Migrating: ${domain}${NC}"
        echo "${BLUE}============================================${NC}"

        if _migrate_single_site "$domain"; then
            ((success_count++))
            results+=("${GREEN}OK${NC}  ${domain}")
        else
            ((fail_count++))
            results+=("${RED}FAIL${NC} ${domain}")
        fi
    done

    # Summary
    clear_screen
    echo ""
    echo "${GREEN}========== KET QUA MIGRATE ==========${NC}"
    echo ""
    for r in "${results[@]}"; do
        echo -e "  $r"
    done
    echo ""
    echo "${GREEN}Thanh cong: ${success_count}${NC} | ${RED}That bai: ${fail_count}${NC}"
    echo ""
    echo "Buoc tiep theo: Tro DNS cua cac domain ve IP ${IP_ADDRESS}"
    echo ""

    # Cleanup SSH key
    if [[ "$MIGRATE_KEY_CREATED" == true ]]; then
        echo "${BLUE}== Quan ly SSH Key Migrate ==${NC}"
        echo "  1) Huy SSH Key (xoa key tren server nay + server cu)"
        echo "  2) Giu lai SSH Key (dung cho lan migrate tiep theo)"
        read -rp "Chon: " cleanup_choice

        case "$cleanup_choice" in
            1)
                local migrate_key="/root/.ssh/id_rsa_migrate"
                local pub_key
                pub_key=$(cat "${migrate_key}.pub" 2>/dev/null)

                # Xoa public key tren server cu
                if [[ -n "$pub_key" ]]; then
                    _migrate_ssh "sed -i '\|${pub_key}|d' ~/.ssh/authorized_keys" 2>/dev/null
                    msg "$ICON_CHECK Da xoa public key tren server cu" "green"
                fi

                # Xoa key tren server moi
                rm -f "${migrate_key}" "${migrate_key}.pub"
                msg "$ICON_CHECK Da xoa SSH Key tren server nay" "green"
                ;;
            2)
                msg "$ICON_CHECK Giu lai SSH Key tai /root/.ssh/id_rsa_migrate" "green"
                ;;
        esac
    fi

    press_enter_to_continue
}

_migrate_single_site() {
    local domain="$1"
    local tmp_dir="/tmp/migrate_${domain//[^a-zA-Z0-9]/_}"

    # 1. Detect site info on old server
    msg "$ICON_TOOL [1/8] Dang thu thap thong tin site tren server cu..."
    local remote_info
    remote_info=$(_migrate_ssh "
        site_dir=\$(find /home/ -maxdepth 2 -name '${domain}' -type d 2>/dev/null | head -1)
        if [[ -z \"\$site_dir\" ]]; then
            echo 'NOT_FOUND'
            exit 1
        fi
        echo \"SITE_DIR=\${site_dir}\"

        # Find wp-config
        if [[ -f \"\${site_dir}/public_html/wp-config.php\" ]]; then
            echo 'WP_CONFIG=inside'
            db_name=\$(grep \"DB_NAME\" \"\${site_dir}/public_html/wp-config.php\" | cut -d\"'\" -f4)
            db_user=\$(grep \"DB_USER\" \"\${site_dir}/public_html/wp-config.php\" | cut -d\"'\" -f4)
        elif [[ -f \"\${site_dir}/wp-config.php\" ]]; then
            echo 'WP_CONFIG=outside'
            db_name=\$(grep \"DB_NAME\" \"\${site_dir}/wp-config.php\" | cut -d\"'\" -f4)
            db_user=\$(grep \"DB_USER\" \"\${site_dir}/wp-config.php\" | cut -d\"'\" -f4)
        else
            echo 'WP_CONFIG=none'
            db_name=''
            db_user=''
        fi
        echo \"DB_NAME=\${db_name}\"
        echo \"DB_USER=\${db_user}\"

        # Check SSL
        if [[ -d /etc/nginx/ssl/${domain} ]]; then
            echo 'HAS_SSL=yes'
        else
            echo 'HAS_SSL=no'
        fi

        # Source size
        du -sm \"\${site_dir}\" 2>/dev/null | awk '{print \"SIZE_MB=\"\$1}'
    ")

    if [[ "$remote_info" == *"NOT_FOUND"* ]]; then
        msg "$ICON_EXIT Khong tim thay ${domain} tren server cu!"
        return 1
    fi

    # Parse info
    local site_dir db_name db_user wp_config has_ssl size_mb
    eval "$(echo "$remote_info" | grep '^SITE_DIR=')"
    eval "$(echo "$remote_info" | grep '^DB_NAME=')"
    eval "$(echo "$remote_info" | grep '^DB_USER=')"
    eval "$(echo "$remote_info" | grep '^WP_CONFIG=')"
    eval "$(echo "$remote_info" | grep '^HAS_SSL=')"
    eval "$(echo "$remote_info" | grep '^SIZE_MB=')"

    echo "  Site dir : ${site_dir}"
    echo "  Database : ${DB_NAME:-none}"
    echo "  SSL      : ${HAS_SSL}"
    echo "  Size     : ${SIZE_MB:-?}MB"

    # 2. Backup on old server
    msg "$ICON_TOOL [2/8] Dang backup tren server cu..."
    _migrate_ssh "
        mkdir -p /tmp/migrate_export
        cd \$(dirname '${SITE_DIR}') && \
        tar czf /tmp/migrate_export/${domain}.tar.gz \$(basename '${SITE_DIR}')/ 2>/dev/null
        if [[ -n '${DB_NAME}' ]]; then
            mariadb-dump '${DB_NAME}' --routines --triggers 2>/dev/null | gzip > /tmp/migrate_export/${domain}.sql.gz \
            || mysqldump '${DB_NAME}' --routines --triggers 2>/dev/null | gzip > /tmp/migrate_export/${domain}.sql.gz
        fi
        if [[ -d /etc/nginx/ssl/${domain} ]]; then
            tar czf /tmp/migrate_export/${domain}_ssl.tar.gz -C /etc/nginx/ssl ${domain}/ 2>/dev/null
        fi
        if [[ -d /root/.acme.sh/${domain}_ecc ]]; then
            tar czf /tmp/migrate_export/${domain}_acme.tar.gz -C /root/.acme.sh ${domain}_ecc/ 2>/dev/null
        fi
        ls -la /tmp/migrate_export/${domain}* 2>/dev/null
    "

    # 3. Transfer to new server
    msg "$ICON_TOOL [3/8] Dang chuyen du lieu sang server moi..."
    mkdir -p "$tmp_dir"
    _migrate_scp "root@${MIGRATE_SSH_IP}:/tmp/migrate_export/${domain}.tar.gz" "${tmp_dir}/" || {
        msg "$ICON_EXIT Chuyen source that bai!"; return 1
    }
    [[ -n "$DB_NAME" ]] && _migrate_scp "root@${MIGRATE_SSH_IP}:/tmp/migrate_export/${domain}.sql.gz" "${tmp_dir}/" 2>/dev/null
    [[ "$HAS_SSL" == "yes" ]] && _migrate_scp "root@${MIGRATE_SSH_IP}:/tmp/migrate_export/${domain}_ssl.tar.gz" "${tmp_dir}/" 2>/dev/null
    _migrate_scp "root@${MIGRATE_SSH_IP}:/tmp/migrate_export/${domain}_acme.tar.gz" "${tmp_dir}/" 2>/dev/null

    # 4. Create domain on new server
    msg "$ICON_TOOL [4/8] Dang tao domain tren server moi..."
    local owner owner_folder base_dir new_db_name new_db_user new_db_pass sftp_user sftp_pass
    local php_version

    # Detect PHP version
    php_version=$(ls /etc/php/ 2>/dev/null | sort -V | tail -1)
    if [[ -z "$php_version" ]]; then
        msg "$ICON_EXIT Khong tim thay PHP!"
        return 1
    fi

    owner=$(generate_user_from_domain "$domain")
    owner_folder=$(generate_web_owner_folder "$domain")
    base_dir="/home/${owner_folder}/${domain}"

    # Check if domain already exists
    if [[ -d "$base_dir" ]]; then
        msg "$ICON_WARNING Domain ${domain} da ton tai tren server nay. Bo qua tao moi."
    else
        create_system_user "$owner" "$owner_folder"

        sftp_user="sftp_${owner}"
        sftp_pass=$(gen_pass)
        create_sftp_user "$sftp_user" "$sftp_pass" "$domain" "$owner_folder"

        create_website_directories "$base_dir"
    fi

    # Re-read owner if domain existed
    if [[ -d "$base_dir" ]]; then
        owner=$(stat -c '%U' "${base_dir}/public_html" 2>/dev/null || echo "$owner")
    fi

    # 5. Extract source
    msg "$ICON_TOOL [5/8] Dang giai nen source code..."

    # Remove immutable flags if any
    chattr -R -i "${base_dir}/" 2>/dev/null

    rm -rf "${base_dir}/public_html" 2>/dev/null
    mkdir -p "${base_dir}/public_html"

    # Extract - handle both structures
    if tar -tzf "${tmp_dir}/${domain}.tar.gz" 2>/dev/null | head -1 | grep -q "^${domain}/public_html/\|^[^/]*/public_html/"; then
        # Has internal structure with public_html
        tar -xzf "${tmp_dir}/${domain}.tar.gz" -C "$(dirname "$base_dir")/" 2>/dev/null

        # Move wp-config if it's outside public_html
        if [[ -f "${base_dir}/wp-config.php" && ! -f "${base_dir}/public_html/wp-config.php" ]]; then
            : # Keep wp-config outside, mcn supports this
        fi
    else
        # Flat structure
        tar -xzf "${tmp_dir}/${domain}.tar.gz" -C "${base_dir}/public_html/" --strip-components=1 2>/dev/null
    fi

    # Verify extraction
    if [[ ! -f "${base_dir}/public_html/index.php" && ! -f "${base_dir}/public_html/index.html" ]]; then
        # Try alternative extraction
        tar -xzf "${tmp_dir}/${domain}.tar.gz" -C "${base_dir}/" 2>/dev/null
    fi

    msg "$ICON_CHECK Source code da giai nen" "green"

    # 6. Create DB and import
    if [[ -n "$DB_NAME" && -f "${tmp_dir}/${domain}.sql.gz" ]]; then
        msg "$ICON_TOOL [6/8] Dang tao database va import..."
        new_db_name="${owner}_db"
        new_db_user="${owner}_user"
        new_db_pass=$(gen_pass)

        create_database "$new_db_name"
        create_mysql_user "$new_db_user" "$new_db_pass"
        grant_mysql_user_privileges "$new_db_name" "$new_db_user"

        # Import
        gunzip < "${tmp_dir}/${domain}.sql.gz" | mariadb "$new_db_name" 2>/dev/null

        # Update wp-config.php
        local wp_config_file=""
        [[ -f "${base_dir}/public_html/wp-config.php" ]] && wp_config_file="${base_dir}/public_html/wp-config.php"
        [[ -f "${base_dir}/wp-config.php" ]] && wp_config_file="${base_dir}/wp-config.php"

        if [[ -n "$wp_config_file" ]]; then
            wp --path="${base_dir}/public_html" --allow-root config set DB_NAME "$new_db_name" 2>/dev/null
            wp --path="${base_dir}/public_html" --allow-root config set DB_USER "$new_db_user" 2>/dev/null
            wp --path="${base_dir}/public_html" --allow-root config set DB_PASSWORD "$new_db_pass" 2>/dev/null
            wp --path="${base_dir}/public_html" --allow-root config set DB_HOST "localhost" 2>/dev/null

            # Search-replace old paths
            local old_site_dir="${SITE_DIR}"
            if [[ "$old_site_dir" != "$base_dir" ]]; then
                wp --path="${base_dir}/public_html" --allow-root \
                    search-replace "$old_site_dir" "$base_dir" --all-tables 2>/dev/null
            fi

            # Update site URL
            wp --path="${base_dir}/public_html" --allow-root \
                option update siteurl "https://${domain}" 2>/dev/null
            wp --path="${base_dir}/public_html" --allow-root \
                option update home "https://${domain}" 2>/dev/null
        fi

        msg "$ICON_CHECK Database da import va cap nhat" "green"
    else
        msg "$ICON_WARNING Khong co database, bo qua" "orange"
        new_db_name=""
        new_db_user=""
        new_db_pass=""
    fi

    # 7. Setup nginx, PHP-FPM
    msg "$ICON_TOOL [7/8] Dang cau hinh Nginx va PHP..."

    # Save website settings
    # shellcheck disable=SC2034
    declare -A website_conf=(
        [domain]="$domain"
        [php_version]="$php_version"
        [owner]="$owner"
        [owner_folder]="$owner_folder"
        [website_source]="wordpress"
        [db_user]="$new_db_user"
        [db_name]="$new_db_name"
        [db_pass]="$new_db_pass"
        [php_pm]=ondemand
        [base_dir]="$base_dir"
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
        [sftp_user]="${sftp_user}"
        [sftp_pass]="${sftp_pass}"
    )
    save_website_settings website_conf

    # Create PHP-FPM pool
    create_php_pool "$owner" "$owner_folder" "$domain" "$php_version"

    # Generate nginx vhost
    local vhost_file="${SITE_AVAILABLE_DIR}/${domain}.conf"
    generate_nginx_vhost --domain "$domain" --owner "$owner" \
        --owner_folder "$owner_folder" --base_dir "$base_dir" --website_source "wordpress"

    format_nginx_config "$vhost_file" 2>/dev/null
    enable_nginx_vhost "$domain"

    # Fix permissions
    set_site_dir_permission --owner "$owner" --owner_folder "$owner_folder" --domain "$domain"
    chattr -R -i "${base_dir}/" 2>/dev/null

    # Test and reload
    if test_nginx_config; then
        reload_specific_php_ver "$php_version"
        nginx_reload
    else
        msg "$ICON_EXIT Nginx config loi!"
        return 1
    fi

    # 8. Copy SSL
    msg "$ICON_TOOL [8/8] Dang chuyen SSL certificate..."
    if [[ -f "${tmp_dir}/${domain}_ssl.tar.gz" ]]; then
        mkdir -p "/etc/nginx/ssl/"
        tar -xzf "${tmp_dir}/${domain}_ssl.tar.gz" -C "/etc/nginx/ssl/" 2>/dev/null
        msg "$ICON_CHECK SSL certificate da chuyen" "green"
    fi

    if [[ -f "${tmp_dir}/${domain}_acme.tar.gz" ]]; then
        tar -xzf "${tmp_dir}/${domain}_acme.tar.gz" -C "/root/.acme.sh/" 2>/dev/null
        msg "$ICON_CHECK ACME certificate da chuyen" "green"
    fi

    # Reload nginx with SSL
    if [[ -f "/etc/nginx/ssl/${domain}/cert.pem" ]]; then
        sed -i "s|/etc/nginx/ssl/default/server.crt|/etc/nginx/ssl/${domain}/cert.pem|g" "$vhost_file" 2>/dev/null
        sed -i "s|/etc/nginx/ssl/default/server.key|/etc/nginx/ssl/${domain}/key.pem|g" "$vhost_file" 2>/dev/null
        nginx_reload
    fi

    # SSL pending
    mkdir -p "${SSL_PENDING_DIR}"
    touch "${SSL_PENDING_DIR}/${domain}"

    # Cleanup temp files
    rm -rf "$tmp_dir"
    _migrate_ssh "rm -f /tmp/migrate_export/${domain}*" 2>/dev/null

    # Summary
    echo ""
    echo "${GREEN}  ✅ Migrate ${domain} thanh cong!${NC}"
    echo "  ---------------------------"
    echo "  Domain    : ${domain}"
    echo "  Web Dir   : ${base_dir}"
    if [[ -n "$new_db_name" ]]; then
        echo "  Database  : ${new_db_name}"
        echo "  DB User   : ${new_db_user}"
        echo "  DB Pass   : ${new_db_pass}"
    fi
    if [[ -n "$sftp_user" ]]; then
        echo "  SFTP User : ${sftp_user}"
        echo "  SFTP Pass : ${sftp_pass}"
    fi
    echo "  SSL       : ${HAS_SSL}"
    echo "  ---------------------------"

    return 0
}
