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

if ! declare -f allocate_port >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_app_deploy.sh"
fi

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

############################################
# Deploy New App
############################################

deploy_new_app() {
    clear_screen
    echo "${GREEN}========== DEPLOY UNG DUNG MOI ==========${NC}"
    echo ""

    local domain app_type source_path branch db_type
    local enable_auth auth_user auth_pass
    local enable_webhook webhook_secret
    local owner owner_folder base_dir app_dir
    local node_port db_name db_user db_pass db_url

    # 1. Domain
    run_prompt_or_exit prompt_domain_input domain "app_deploy_menu"
    sleep 0.5; clear_screen

    # 2. App type
    echo "${GREEN}Chon loai ung dung:${NC}"
    echo "1) Next.js"
    echo "2) Nuxt.js"
    echo "3) NestJS"
    echo "4) Express"
    echo "5) React (static build + serve)"
    echo "6) Other"
    echo "${RED}0) Huy thao tac${NC}"

    while true; do
        read -rp "Nhap lua chon (0-6): " app_choice
        case "$app_choice" in
            0) return 0 ;;
            1) app_type="nextjs"; break ;;
            2) app_type="nuxtjs"; break ;;
            3) app_type="nestjs"; break ;;
            4) app_type="express"; break ;;
            5) app_type="react"; break ;;
            6) app_type="other"; break ;;
            *) msg "$ICON_EXIT Lua chon khong hop le!" ;;
        esac
    done
    sleep 0.5; clear_screen

    # 3. Source path
    echo "${GREEN}Nhap duong dan source:${NC}"
    echo "  - GitHub URL (vd: https://github.com/user/repo.git)"
    echo "  - Hoac duong dan tren VPS (vd: /home/user/myapp)"
    read -rp "Source: " source_path
    [[ -z "$source_path" ]] && { msg "$ICON_EXIT Source khong duoc de trong!"; press_enter_to_continue; return 0; }

    # 4. Branch (only for git repos)
    local is_git_repo=false
    if [[ "$source_path" == http* || "$source_path" == git@* ]]; then
        is_git_repo=true
        read -rp "Branch (mac dinh: main): " branch
        branch="${branch:-main}"
    fi
    sleep 0.5; clear_screen

    # 5. Database
    echo "${GREEN}Chon loai Database:${NC}"
    echo "1) PostgreSQL"
    echo "2) MariaDB (MySQL)"
    echo "3) Khong su dung Database"
    echo "${RED}0) Huy thao tac${NC}"

    while true; do
        read -rp "Nhap lua chon (0-3): " db_choice
        case "$db_choice" in
            0) return 0 ;;
            1) db_type="postgresql"; break ;;
            2) db_type="mariadb"; break ;;
            3) db_type="none"; break ;;
            *) msg "$ICON_EXIT Lua chon khong hop le!" ;;
        esac
    done
    sleep 0.5; clear_screen

    # 6. Basic Auth
    enable_auth="n"
    if prompt_yes_no "Ban co muon bat Basic Auth (bao ve trang bang user/pass)?"; then
        enable_auth="y"
        read -rp "Auth username (mac dinh: admin): " auth_user
        auth_user="${auth_user:-admin}"
        auth_pass=$(gen_pass)
        echo "${GREEN}Auth password: ${auth_pass}${NC}"
    fi
    sleep 0.5; clear_screen

    # 7. Webhook auto deploy
    enable_webhook="n"
    if [[ "$is_git_repo" == true ]]; then
        if prompt_yes_no "Ban co muon setup Auto Deploy (webhook tu GitHub)?"; then
            enable_webhook="y"
            webhook_secret=$(gen_pass)
        fi
    fi

    clear_screen
    echo "${GREEN}========== DANG DEPLOY... ==========${NC}"
    echo ""

    # Install dependencies
    install_nodejs
    install_pm2
    if [[ "$db_type" == "postgresql" ]]; then
        install_postgresql
    fi

    # Allocate port
    node_port=$(allocate_port) || { msg "$ICON_EXIT Khong the cap phat port!"; press_enter_to_continue; return 0; }
    msg "$ICON_CHECK Port: ${node_port}" "green"

    # Create system user
    owner=$(generate_user_from_domain "$domain")
    owner_folder=$(generate_web_owner_folder "$domain")
    base_dir="/home/${owner_folder}/${domain}"
    app_dir="${base_dir}/public_html"

    create_system_user "$owner" "$owner_folder"

    # Create SFTP user
    local sftp_user="sftp_${owner}"
    local sftp_pass
    sftp_pass=$(gen_pass)
    create_sftp_user "$sftp_user" "$sftp_pass" "$domain" "$owner_folder"

    # Create directories
    run_or_exit "Tao thu muc website" create_website_directories "$base_dir"

    # Clone or copy source
    if [[ "$is_git_repo" == true ]]; then
        msg "$ICON_TOOL Dang clone source tu GitHub..."
        git clone -b "$branch" "$source_path" "$app_dir" 2>/dev/null || {
            msg "$ICON_EXIT Clone that bai! Kiem tra lai URL va branch."
            press_enter_to_continue; return 0
        }
    else
        if [[ -d "$source_path" ]]; then
            msg "$ICON_TOOL Dang copy source..."
            cp -r "${source_path}/." "$app_dir/"
        else
            msg "$ICON_EXIT Duong dan khong ton tai: ${source_path}"
            press_enter_to_continue; return 0
        fi
    fi

    # Install npm dependencies & build
    msg "$ICON_TOOL Dang cai dat dependencies (npm install)..."
    cd "$app_dir" || return 1
    if [[ -f "package-lock.json" ]]; then
        npm ci >/dev/null 2>&1
    elif [[ -f "yarn.lock" ]]; then
        yarn install >/dev/null 2>&1
    else
        npm install >/dev/null 2>&1
    fi

    if grep -q '"build"' package.json 2>/dev/null; then
        msg "$ICON_TOOL Dang build ung dung..."
        npm run build >/dev/null 2>&1
    fi
    cd "${HOSTVN_DIR}" || return 1

    # Create database
    db_url=""
    if [[ "$db_type" == "postgresql" ]]; then
        db_name="${owner}_db"
        db_user="${owner}_user"
        db_pass=$(gen_pass)
        create_pg_database "$db_name"
        create_pg_user "$db_user" "$db_pass"
        grant_pg_privileges "$db_name" "$db_user"
        db_url="postgresql://${db_user}:${db_pass}@localhost:5432/${db_name}"
    elif [[ "$db_type" == "mariadb" ]]; then
        db_name="${owner}_db"
        db_user="${owner}_user"
        db_pass=$(gen_pass)
        create_database "$db_name"
        create_mysql_user "$db_user" "$db_pass"
        grant_mysql_user_privileges "$db_name" "$db_user"
        db_url="mysql://${db_user}:${db_pass}@localhost:3306/${db_name}"
    fi

    # Save settings
    # shellcheck disable=SC2034
    declare -A website_conf=(
        [domain]="$domain"
        [owner]="$owner"
        [owner_folder]="$owner_folder"
        [website_source]="$app_type"
        [node_port]="$node_port"
        [app_type]="$app_type"
        [db_type]="$db_type"
        [db_user]="$db_user"
        [db_name]="$db_name"
        [db_pass]="$db_pass"
        [db_url]="$db_url"
        [base_dir]="$base_dir"
        [sftp_user]="$sftp_user"
        [sftp_pass]="$sftp_pass"
        [webhook_enabled]="$enable_webhook"
        [source_path]="$source_path"
        [branch]="${branch:-}"
        [basic_auth]="$enable_auth"
    )
    save_website_settings website_conf

    # Create PM2 ecosystem
    create_pm2_ecosystem "$domain" "$node_port" "$app_dir" "$app_type" "$db_type" "$db_url"

    # Set permissions
    set_site_dir_permission --owner "$owner" --owner_folder "$owner_folder" --domain "$domain"

    # Generate nginx vhost (nodejs template)
    local vhost_file="${SITE_AVAILABLE_DIR}/${domain}.conf"
    run_or_exit "Tao vHost Nginx" generate_nginx_vhost --domain "$domain" --owner "$owner" \
        --owner_folder "$owner_folder" --base_dir "$base_dir" --website_source "nodejs"

    # Replace __NODE_PORT__ in vhost
    sed -i "s|__NODE_PORT__|${node_port}|g" "$vhost_file"

    # Fix upstream name (dots not allowed in upstream)
    local upstream_name
    upstream_name=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
    sed -i "s|${domain}_backend|${upstream_name}_backend|g" "$vhost_file"

    run_or_exit "Format Nginx config" format_nginx_config "$vhost_file"
    enable_nginx_vhost "$domain"

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        press_enter_to_continue; return 0
    fi

    nginx_reload

    # Setup basic auth
    if [[ "$enable_auth" == "y" ]]; then
        setup_basic_auth "$domain" "$auth_user" "$auth_pass"
    fi

    # Start PM2
    pm2_start_app "$domain" "$app_dir"

    # Setup webhook
    if [[ "$enable_webhook" == "y" ]]; then
        setup_webhook_listener "$domain" "$source_path" "$branch" "$webhook_secret" "$app_dir"
    fi

    # SSL pending
    mkdir -p "${SSL_PENDING_DIR}"
    touch "${SSL_PENDING_DIR}/${domain}"

    # Summary
    clear_screen
    echo ""
    echo "${GREEN}========== DEPLOY THANH CONG! ==========${NC}"
    echo "---------------------------"
    echo "Ten mien         : ${domain}"
    echo "Loai app         : ${app_type}"
    echo "Port             : ${node_port}"
    echo "App Dir          : ${app_dir}"

    if [[ "$db_type" != "none" ]]; then
        printf "\n"
        echo "--- DATABASE (${db_type}) ---"
        echo "Database Name    : ${db_name}"
        echo "Database User    : ${db_user}"
        echo "Database Password: ${db_pass}"
        if [[ -n "$db_url" ]]; then
            echo "DATABASE_URL     : ${db_url}"
        fi
    fi

    printf "\n"
    echo "--- SFTP ---"
    echo "SFTP User        : ${sftp_user}"
    echo "SFTP Password    : ${sftp_pass}"
    echo "SFTP Directory   : /${domain}/public_html"

    if [[ "$enable_auth" == "y" ]]; then
        printf "\n"
        echo "--- BASIC AUTH ---"
        echo "Username         : ${auth_user}"
        echo "Password         : ${auth_pass}"
    fi

    if [[ "$enable_webhook" == "y" ]]; then
        printf "\n"
        echo "--- AUTO DEPLOY ---"
        echo "Webhook URL      : http://${IPADDRESS}:${WEBHOOK_PORT}/webhook/${domain}"
        echo "Webhook Secret   : ${webhook_secret}"
        echo ""
        echo "Cau hinh tren GitHub: Settings > Webhooks > Add webhook"
        echo "  Payload URL: http://${IPADDRESS}:${WEBHOOK_PORT}/webhook/${domain}"
        echo "  Content type: application/json"
        echo "  Secret: ${webhook_secret}"
    fi

    printf "\n"
    echo "--- PM2 COMMANDS ---"
    echo "pm2 status ${domain}"
    echo "pm2 logs ${domain}"
    echo "pm2 reload ${domain}"
    echo "---------------------------"

    press_enter_to_continue
}

############################################
# Manage Apps (PM2)
############################################

manage_apps() {
    while true; do
        clear_screen
        echo "${GREEN}========== QUAN LY UNG DUNG ==========${NC}"
        echo ""

        local app_domains
        app_domains=($(get_app_domains))

        if [[ ${#app_domains[@]} -eq 0 ]]; then
            msg "$ICON_EXIT Chua co ung dung nao duoc deploy." "red"
            press_enter_to_continue
            return 0
        fi

        echo "${BLUE}PM2 Status:${NC}"
        pm2 list 2>/dev/null
        echo ""

        echo "${BLUE}Chon ung dung:${NC}"
        for i in "${!app_domains[@]}"; do
            local d="${app_domains[$i]}"
            local port
            port=$(get_app_setting "$d" "node_port")
            echo "$((i+1))) ${d} (port: ${port})"
        done
        echo "${RED}0) Quay lai${NC}"

        read -rp "Nhap lua chon: " app_select

        [[ "$app_select" == "0" ]] && return 0

        if [[ "$app_select" =~ ^[0-9]+$ ]] && (( app_select >= 1 && app_select <= ${#app_domains[@]} )); then
            local selected_domain="${app_domains[$((app_select-1))]}"
            _manage_single_app "$selected_domain"
        else
            msg "$ICON_EXIT Lua chon khong hop le!"
            sleep 1
        fi
    done
}

_manage_single_app() {
    local domain="$1"
    local owner_folder
    owner_folder=$(get_app_setting "$domain" "owner_folder")
    local app_dir="/home/${owner_folder}/${domain}/public_html"

    while true; do
        clear_screen
        echo "${GREEN}========== ${domain} ==========${NC}"
        echo ""

        local pm2_status
        pm2_status=$(pm2 describe "$domain" 2>/dev/null | grep "status" | head -1 || echo "not found")
        echo "Status: ${pm2_status}"
        echo ""

        echo "${BLUE}1. Start${NC}"
        echo "${BLUE}2. Stop${NC}"
        echo "${BLUE}3. Restart (zero-downtime)${NC}"
        echo "${BLUE}4. Xem Log${NC}"
        echo "${BLUE}5. Bat/Tat Basic Auth${NC}"
        echo "${BLUE}6. Xoa ung dung${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"

        read -rp "Chon: " action

        case "$action" in
            1) pm2_start_app "$domain" "$app_dir"; press_enter_to_continue ;;
            2) pm2_stop_app "$domain"; msg "$ICON_CHECK Da stop ${domain}" "green"; press_enter_to_continue ;;
            3) pm2_restart_app "$domain"; msg "$ICON_CHECK Da reload ${domain} (zero-downtime)" "green"; press_enter_to_continue ;;
            4) pm2 logs "$domain" --lines 50 --nostream 2>/dev/null; press_enter_to_continue ;;
            5) _toggle_basic_auth "$domain" ;;
            6)
                if prompt_yes_no "Ban chac chan muon xoa ${domain}?"; then
                    _delete_app "$domain"
                    return 0
                fi
                ;;
            0) return 0 ;;
            *) msg "$ICON_EXIT Lua chon khong hop le!"; sleep 1 ;;
        esac
    done
}

_toggle_basic_auth() {
    local domain="$1"
    local current
    current=$(get_app_setting "$domain" "basic_auth")

    if [[ "$current" == "y" ]]; then
        if prompt_yes_no "Basic Auth dang BAT. Ban co muon TAT?"; then
            remove_basic_auth "$domain"
            sed -i "s|^basic_auth=.*|basic_auth=n|" "${WEB_DATA_DIR}/${domain}/.settings.conf"
            msg "$ICON_CHECK Da tat Basic Auth cho ${domain}" "green"
        fi
    else
        local auth_user auth_pass
        read -rp "Auth username (mac dinh: admin): " auth_user
        auth_user="${auth_user:-admin}"
        auth_pass=$(gen_pass)
        setup_basic_auth "$domain" "$auth_user" "$auth_pass"
        sed -i "s|^basic_auth=.*|basic_auth=y|" "${WEB_DATA_DIR}/${domain}/.settings.conf"
        echo "Username: ${auth_user}"
        echo "Password: ${auth_pass}"
        msg "$ICON_CHECK Da bat Basic Auth cho ${domain}" "green"
    fi
    press_enter_to_continue
}

_delete_app() {
    local domain="$1"
    local owner owner_folder

    owner=$(get_app_setting "$domain" "owner")
    owner_folder=$(get_app_setting "$domain" "owner_folder")

    pm2_delete_app "$domain"
    remove_webhook "$domain"

    # Remove nginx vhost
    rm -f "/etc/nginx/sites-enabled/${domain}.conf"
    rm -f "/etc/nginx/sites-available/${domain}.conf"
    nginx_reload

    # Remove basic auth
    rm -f "/etc/nginx/htpasswd/${domain}"

    # Remove DB
    local db_type db_name db_user
    db_type=$(get_app_setting "$domain" "db_type")
    db_name=$(get_app_setting "$domain" "db_name")
    db_user=$(get_app_setting "$domain" "db_user")

    if [[ "$db_type" == "postgresql" ]]; then
        delete_pg_database "$db_name"
        delete_pg_user "$db_user"
    elif [[ "$db_type" == "mariadb" ]]; then
        delete_mysql_db "$db_name"
        delete_mysql_user "$db_user"
    fi

    # Remove user & files
    local sftp_user="sftp_${owner}"
    userdel -r "$sftp_user" 2>/dev/null
    userdel -r "$owner" 2>/dev/null
    rm -rf "/home/${owner_folder}/${domain}"
    rm -rf "${WEB_DATA_DIR}/${domain}"

    msg "$ICON_CHECK Da xoa ung dung ${domain}" "green"
    press_enter_to_continue
}

############################################
# Manage PostgreSQL
############################################

manage_postgresql_menu() {
    while true; do
        clear_screen
        echo "${GREEN}========== QUAN LY POSTGRESQL ==========${NC}"
        echo ""

        if ! command -v psql &>/dev/null; then
            msg "$ICON_EXIT PostgreSQL chua duoc cai dat."
            if prompt_yes_no "Ban co muon cai dat PostgreSQL?"; then
                install_postgresql
            else
                return 0
            fi
        fi

        echo "${BLUE}1. Tao Database${NC}"
        echo "${BLUE}2. Tao User${NC}"
        echo "${BLUE}3. Xoa Database${NC}"
        echo "${BLUE}4. Xoa User${NC}"
        echo "${BLUE}5. Export Database${NC}"
        echo "${BLUE}6. Danh sach Databases${NC}"
        echo "${BLUE}7. Danh sach Users${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"

        read -rp "Chon mot tuy chon: " pg_choice

        case "$pg_choice" in
            1) _pg_create_database ;;
            2) _pg_create_user ;;
            3) _pg_delete_database ;;
            4) _pg_delete_user ;;
            5) _pg_export_database ;;
            6)
                echo ""
                echo "${GREEN}Databases:${NC}"
                list_pg_databases
                press_enter_to_continue
                ;;
            7)
                echo ""
                echo "${GREEN}Users:${NC}"
                list_pg_users
                press_enter_to_continue
                ;;
            0) return 0 ;;
            *) msg "$ICON_EXIT Lua chon khong hop le!"; sleep 1 ;;
        esac
    done
}

_pg_create_database() {
    local db_name
    read -rp "Nhap ten Database: " db_name
    [[ -z "$db_name" ]] && { msg "$ICON_EXIT Ten database khong duoc de trong!"; press_enter_to_continue; return; }

    if create_pg_database "$db_name"; then
        msg "$ICON_CHECK Database '${db_name}' da tao thanh cong!" "green"
    else
        msg "$ICON_EXIT Tao database that bai!"
    fi
    press_enter_to_continue
}

_pg_create_user() {
    local pg_user pg_pass
    read -rp "Nhap ten User: " pg_user
    [[ -z "$pg_user" ]] && { msg "$ICON_EXIT Ten user khong duoc de trong!"; press_enter_to_continue; return; }

    pg_pass=$(gen_pass)
    if create_pg_user "$pg_user" "$pg_pass"; then
        echo ""
        echo "User     : ${pg_user}"
        echo "Password : ${pg_pass}"
        msg "$ICON_CHECK User '${pg_user}' da tao thanh cong!" "green"

        if prompt_yes_no "Ban co muon grant quyen cho user nay vao database?"; then
            local db_name
            read -rp "Nhap ten Database: " db_name
            grant_pg_privileges "$db_name" "$pg_user"
            msg "$ICON_CHECK Da grant quyen cho ${pg_user} tren ${db_name}" "green"
        fi
    else
        msg "$ICON_EXIT Tao user that bai!"
    fi
    press_enter_to_continue
}

_pg_delete_database() {
    echo ""
    echo "${GREEN}Databases hien co:${NC}"
    list_pg_databases
    echo ""

    local db_name
    read -rp "Nhap ten Database can xoa: " db_name
    [[ -z "$db_name" ]] && { press_enter_to_continue; return; }

    if prompt_yes_no "Ban chac chan muon xoa database '${db_name}'?"; then
        if delete_pg_database "$db_name"; then
            msg "$ICON_CHECK Da xoa database '${db_name}'" "green"
        else
            msg "$ICON_EXIT Xoa database that bai!"
        fi
    fi
    press_enter_to_continue
}

_pg_delete_user() {
    echo ""
    echo "${GREEN}Users hien co:${NC}"
    list_pg_users
    echo ""

    local pg_user
    read -rp "Nhap ten User can xoa: " pg_user
    [[ -z "$pg_user" ]] && { press_enter_to_continue; return; }

    if prompt_yes_no "Ban chac chan muon xoa user '${pg_user}'?"; then
        if delete_pg_user "$pg_user"; then
            msg "$ICON_CHECK Da xoa user '${pg_user}'" "green"
        else
            msg "$ICON_EXIT Xoa user that bai!"
        fi
    fi
    press_enter_to_continue
}

_pg_export_database() {
    echo ""
    echo "${GREEN}Databases hien co:${NC}"
    list_pg_databases
    echo ""

    local db_name
    read -rp "Nhap ten Database can export: " db_name
    [[ -z "$db_name" ]] && { press_enter_to_continue; return; }

    export_pg_database "$db_name" "/root/backup/postgresql"
    press_enter_to_continue
}

############################################
# Install/Update Node.js
############################################

install_nodejs_menu() {
    clear_screen
    echo "${GREEN}========== NODE.JS ==========${NC}"
    echo ""

    if command -v node &>/dev/null; then
        echo "Node.js hien tai: $(node -v)"
        echo "npm hien tai    : $(npm -v)"
        if command -v pm2 &>/dev/null; then
            echo "PM2 hien tai    : $(pm2 -v)"
        fi
        echo ""

        if prompt_yes_no "Ban co muon cap nhat Node.js va PM2?"; then
            update_nodejs
        fi
    else
        if prompt_yes_no "Node.js chua duoc cai dat. Ban co muon cai dat?"; then
            install_nodejs
            install_pm2
        fi
    fi

    press_enter_to_continue
}

############################################
# View App Logs
############################################

view_app_logs() {
    clear_screen
    echo "${GREEN}========== XEM LOG UNG DUNG ==========${NC}"
    echo ""

    local app_domains
    app_domains=($(get_app_domains))

    if [[ ${#app_domains[@]} -eq 0 ]]; then
        msg "$ICON_EXIT Chua co ung dung nao." "red"
        press_enter_to_continue
        return 0
    fi

    echo "${BLUE}Chon ung dung:${NC}"
    for i in "${!app_domains[@]}"; do
        echo "$((i+1))) ${app_domains[$i]}"
    done
    echo "${RED}0) Quay lai${NC}"

    read -rp "Nhap lua chon: " log_select
    [[ "$log_select" == "0" ]] && return 0

    if [[ "$log_select" =~ ^[0-9]+$ ]] && (( log_select >= 1 && log_select <= ${#app_domains[@]} )); then
        local selected="${app_domains[$((log_select-1))]}"
        echo ""
        pm2 logs "$selected" --lines 100 --nostream 2>/dev/null
    else
        msg "$ICON_EXIT Lua chon khong hop le!"
    fi

    press_enter_to_continue
}

############################################
# Manage Webhook
############################################

manage_webhook_menu() {
    while true; do
        clear_screen
        echo "${GREEN}========== QUAN LY WEBHOOK ==========${NC}"
        echo ""

        local webhook_files=(/etc/mcnvps/webhooks/*.conf)
        if [[ ! -f "${webhook_files[0]}" ]]; then
            msg "Chua co webhook nao duoc cau hinh." "orange"
            echo ""
        else
            echo "${BLUE}Webhook hien co:${NC}"
            for wf in "${webhook_files[@]}"; do
                local wd
                wd=$(basename "$wf" .conf)
                local wb
                wb=$(grep '^BRANCH=' "$wf" 2>/dev/null | cut -d= -f2)
                echo "  - ${wd} (branch: ${wb})"
            done
            echo ""
        fi

        echo "${BLUE}1. Them Webhook cho domain${NC}"
        echo "${BLUE}2. Xoa Webhook${NC}"
        echo "${BLUE}3. Xem Deploy Log${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"

        read -rp "Chon mot tuy chon: " wh_choice

        case "$wh_choice" in
            1)
                local domain repo branch secret
                read -rp "Nhap domain: " domain
                read -rp "Nhap GitHub repo URL: " repo
                read -rp "Branch (mac dinh: main): " branch
                branch="${branch:-main}"
                secret=$(gen_pass)

                local owner_folder
                owner_folder=$(get_app_setting "$domain" "owner_folder")
                local app_dir="/home/${owner_folder}/${domain}/public_html"

                setup_webhook_listener "$domain" "$repo" "$branch" "$secret" "$app_dir"
                echo ""
                echo "${GREEN}Webhook URL: http://${IPADDRESS}:${WEBHOOK_PORT}/webhook/${domain}${NC}"
                echo "${GREEN}Secret: ${secret}${NC}"
                press_enter_to_continue
                ;;
            2)
                read -rp "Nhap domain can xoa webhook: " domain
                remove_webhook "$domain"
                msg "$ICON_CHECK Da xoa webhook cho ${domain}" "green"
                press_enter_to_continue
                ;;
            3)
                read -rp "Nhap domain: " domain
                local logfile="/var/log/mcnvps-webhook-${domain}.log"
                if [[ -f "$logfile" ]]; then
                    tail -50 "$logfile"
                else
                    msg "Chua co log deploy cho ${domain}." "orange"
                fi
                press_enter_to_continue
                ;;
            0) return 0 ;;
            *) msg "$ICON_EXIT Lua chon khong hop le!"; sleep 1 ;;
        esac
    done
}
