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

APP_PORT_MIN=3000
APP_PORT_MAX=9000
WEBHOOK_PORT=9999
WEBHOOK_SERVICE="mcnvps-webhook"
WEBHOOK_LOG="/var/log/mcnvps-webhook.log"

############################################
# Node.js & PM2
############################################

install_nodejs() {
    if command -v node &>/dev/null; then
        msg "$ICON_CHECK Node.js da duoc cai dat: $(node -v)" "green"
        return 0
    fi

    msg "$ICON_TOOL Dang cai dat Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
    safe_apt_install "Node.js" nodejs
    msg "$ICON_CHECK Node.js $(node -v) da cai dat thanh cong!" "green"
}

install_pm2() {
    if command -v pm2 &>/dev/null; then
        return 0
    fi

    msg "$ICON_TOOL Dang cai dat PM2..."
    npm install -g pm2 >/dev/null 2>&1
    pm2 startup systemd -u root --hp /root >/dev/null 2>&1
    msg "$ICON_CHECK PM2 da cai dat thanh cong!" "green"
}

update_nodejs() {
    msg "$ICON_TOOL Dang cap nhat Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
    apt-get install -y nodejs >/dev/null 2>&1
    npm install -g pm2@latest >/dev/null 2>&1
    msg "$ICON_CHECK Node.js $(node -v), PM2 $(pm2 -v) da cap nhat!" "green"
}

############################################
# PostgreSQL
############################################

install_postgresql() {
    if command -v psql &>/dev/null; then
        msg "$ICON_CHECK PostgreSQL da duoc cai dat." "green"
        return 0
    fi

    msg "$ICON_TOOL Dang cai dat PostgreSQL..."
    safe_apt_install "PostgreSQL" postgresql postgresql-contrib
    systemctl enable postgresql >/dev/null 2>&1
    systemctl start postgresql

    local pg_pass
    pg_pass=$(gen_pass)
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '${pg_pass}';" >/dev/null 2>&1

    if [[ -f "${FILE_INFO}" ]]; then
        echo "pg_root_pwd=${pg_pass}" >> "${FILE_INFO}"
    fi

    msg "$ICON_CHECK PostgreSQL da cai dat thanh cong!" "green"
}

create_pg_database() {
    local db_name="$1"
    sudo -u postgres psql -c "CREATE DATABASE \"${db_name}\";" 2>/dev/null
    return $?
}

create_pg_user() {
    local pg_user="$1"
    local pg_pass="$2"
    sudo -u postgres psql -c "CREATE ROLE \"${pg_user}\" LOGIN PASSWORD '${pg_pass}';" 2>/dev/null
    return $?
}

grant_pg_privileges() {
    local db_name="$1"
    local pg_user="$2"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"${db_name}\" TO \"${pg_user}\";" 2>/dev/null
    sudo -u postgres psql -d "${db_name}" -c "GRANT ALL ON SCHEMA public TO \"${pg_user}\";" 2>/dev/null
    return $?
}

delete_pg_database() {
    local db_name="$1"
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS \"${db_name}\";" 2>/dev/null
    return $?
}

delete_pg_user() {
    local pg_user="$1"
    sudo -u postgres psql -c "DROP ROLE IF EXISTS \"${pg_user}\";" 2>/dev/null
    return $?
}

export_pg_database() {
    local db_name="$1"
    local backup_dir="$2"
    local backup_file="${backup_dir}/${db_name}_$(date +%Y%m%d_%H%M%S).sql.gz"

    mkdir -p "${backup_dir}"
    sudo -u postgres pg_dump "${db_name}" | gzip > "${backup_file}" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        msg "$ICON_CHECK Export thanh cong: ${backup_file}" "green"
    else
        msg "$ICON_EXIT Export that bai!" "red"
        return 1
    fi
}

list_pg_databases() {
    sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" 2>/dev/null | sed '/^$/d' | sed 's/^ *//'
}

list_pg_users() {
    sudo -u postgres psql -t -c "SELECT rolname FROM pg_roles WHERE rolcanlogin = true AND rolname != 'postgres';" 2>/dev/null | sed '/^$/d' | sed 's/^ *//'
}

############################################
# Port Management
############################################

allocate_port() {
    local used_ports=()
    local conf_file

    for conf_file in "${WEB_DATA_DIR}"/*/".settings.conf"; do
        [[ -f "$conf_file" ]] || continue
        local port
        port=$(grep '^node_port=' "$conf_file" 2>/dev/null | cut -d= -f2)
        [[ -n "$port" ]] && used_ports+=("$port")
    done

    local port
    for port in $(seq ${APP_PORT_MIN} ${APP_PORT_MAX}); do
        local in_use=false
        for used in "${used_ports[@]}"; do
            if [[ "$port" == "$used" ]]; then
                in_use=true
                break
            fi
        done
        if ! $in_use && ! ss -tlnp | grep -q ":${port} "; then
            echo "$port"
            return 0
        fi
    done

    msg "$ICON_EXIT Khong tim thay port trong!" "red"
    return 1
}

############################################
# PM2 Ecosystem
############################################

create_pm2_ecosystem() {
    local domain="$1"
    local port="$2"
    local app_dir="$3"
    local app_type="$4"
    local db_type="${5:-}"
    local db_url="${6:-}"

    local start_script="npm start"
    local interpreter="none"

    case "$app_type" in
        nextjs|nuxtjs)
            start_script="npm start"
            ;;
        nestjs|express)
            start_script="node dist/main.js"
            interpreter="none"
            ;;
        react)
            start_script="npx serve -s build -l ${port}"
            ;;
        *)
            start_script="npm start"
            ;;
    esac

    local ecosystem_file="${app_dir}/ecosystem.config.js"
    local env_block="PORT: ${port}"
    if [[ -n "$db_url" ]]; then
        env_block="${env_block},
      DATABASE_URL: '${db_url}'"
    fi

    cat > "${ecosystem_file}" <<ECOSYSTEM
module.exports = {
  apps: [{
    name: '${domain}',
    cwd: '${app_dir}',
    script: '${start_script}',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    env: {
      NODE_ENV: 'production',
      ${env_block}
    }
  }]
};
ECOSYSTEM
}

pm2_start_app() {
    local domain="$1"
    local app_dir="$2"
    local ecosystem="${app_dir}/ecosystem.config.js"

    if [[ ! -f "$ecosystem" ]]; then
        msg "$ICON_EXIT Khong tim thay ecosystem.config.js!" "red"
        return 1
    fi

    pm2 start "${ecosystem}" 2>/dev/null
    pm2 save >/dev/null 2>&1
}

pm2_stop_app() {
    local domain="$1"
    pm2 stop "${domain}" 2>/dev/null
    pm2 save >/dev/null 2>&1
}

pm2_restart_app() {
    local domain="$1"
    pm2 reload "${domain}" --update-env 2>/dev/null
    pm2 save >/dev/null 2>&1
}

pm2_delete_app() {
    local domain="$1"
    pm2 delete "${domain}" 2>/dev/null
    pm2 save >/dev/null 2>&1
}

pm2_list_apps() {
    pm2 jlist 2>/dev/null
}

############################################
# Basic Auth
############################################

setup_basic_auth() {
    local domain="$1"
    local auth_user="$2"
    local auth_pass="$3"

    local htpasswd_dir="/etc/nginx/htpasswd"
    local htpasswd_file="${htpasswd_dir}/${domain}"

    mkdir -p "${htpasswd_dir}"
    echo "${auth_pass}" | htpasswd -ci "${htpasswd_file}" "${auth_user}" >/dev/null 2>&1

    local vhost_file="/etc/nginx/sites-available/${domain}.conf"
    if [[ -f "$vhost_file" ]]; then
        local auth_block="    auth_basic \"Restricted\";\n    auth_basic_user_file ${htpasswd_file};"
        sed -i "s|#BASIC_AUTH|${auth_block}\n    #BASIC_AUTH|g" "${vhost_file}"
        nginx_reload
    fi
}

remove_basic_auth() {
    local domain="$1"

    local htpasswd_file="/etc/nginx/htpasswd/${domain}"
    rm -f "${htpasswd_file}"

    local vhost_file="/etc/nginx/sites-available/${domain}.conf"
    if [[ -f "$vhost_file" ]]; then
        sed -i '/auth_basic /d' "${vhost_file}"
        sed -i '/auth_basic_user_file/d' "${vhost_file}"
        nginx_reload
    fi
}

############################################
# Webhook Auto Deploy
############################################

setup_webhook_listener() {
    local domain="$1"
    local repo_url="$2"
    local branch="$3"
    local secret="$4"
    local app_dir="$5"

    local webhook_dir="${MENU_DIR}/bin"
    local deploy_script="${webhook_dir}/deploy_${domain}.sh"

    cat > "${deploy_script}" <<'DEPLOY_SCRIPT'
#!/bin/bash
DOMAIN="__DOMAIN__"
APP_DIR="__APP_DIR__"
BRANCH="__BRANCH__"
LOG="/var/log/mcnvps-webhook-${DOMAIN}.log"

echo "[$(date)] Deploy started for ${DOMAIN}" >> "${LOG}"

cd "${APP_DIR}" || exit 1

git fetch origin "${BRANCH}" >> "${LOG}" 2>&1
git reset --hard "origin/${BRANCH}" >> "${LOG}" 2>&1

if [[ -f "package-lock.json" ]]; then
    npm ci --production >> "${LOG}" 2>&1
elif [[ -f "yarn.lock" ]]; then
    yarn install --production >> "${LOG}" 2>&1
else
    npm install --production >> "${LOG}" 2>&1
fi

if grep -q '"build"' package.json 2>/dev/null; then
    npm run build >> "${LOG}" 2>&1
fi

pm2 reload "${DOMAIN}" --update-env >> "${LOG}" 2>&1

echo "[$(date)] Deploy completed for ${DOMAIN}" >> "${LOG}"
DEPLOY_SCRIPT

    sed -i "s|__DOMAIN__|${domain}|g" "${deploy_script}"
    sed -i "s|__APP_DIR__|${app_dir}|g" "${deploy_script}"
    sed -i "s|__BRANCH__|${branch}|g" "${deploy_script}"
    chmod +x "${deploy_script}"

    _ensure_webhook_server

    local webhook_conf="/etc/mcnvps/webhooks/${domain}.conf"
    mkdir -p /etc/mcnvps/webhooks
    cat > "${webhook_conf}" <<EOF
REPO_URL=${repo_url}
BRANCH=${branch}
SECRET=${secret}
DEPLOY_SCRIPT=${deploy_script}
APP_DIR=${app_dir}
EOF
    chmod 600 "${webhook_conf}"
}

_ensure_webhook_server() {
    if systemctl is-active --quiet "${WEBHOOK_SERVICE}" 2>/dev/null; then
        return 0
    fi

    local server_script="${MENU_DIR}/bin/webhook_server.py"

    cat > "/etc/systemd/system/${WEBHOOK_SERVICE}.service" <<EOF
[Unit]
Description=McnVPS Webhook Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${server_script}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${WEBHOOK_SERVICE}" >/dev/null 2>&1
    systemctl start "${WEBHOOK_SERVICE}"
}

remove_webhook() {
    local domain="$1"

    rm -f "/etc/mcnvps/webhooks/${domain}.conf"
    rm -f "${MENU_DIR}/bin/deploy_${domain}.sh"

    local remaining
    remaining=$(ls /etc/mcnvps/webhooks/*.conf 2>/dev/null | wc -l)
    if [[ "$remaining" -eq 0 ]]; then
        systemctl stop "${WEBHOOK_SERVICE}" 2>/dev/null
        systemctl disable "${WEBHOOK_SERVICE}" 2>/dev/null
    fi
}

############################################
# App Helpers
############################################

get_app_domains() {
    local domains=()
    local conf_file
    for conf_file in "${WEB_DATA_DIR}"/*/".settings.conf"; do
        [[ -f "$conf_file" ]] || continue
        local source
        source=$(grep '^website_source=' "$conf_file" 2>/dev/null | cut -d= -f2)
        if [[ "$source" == "nodejs" || "$source" == "nextjs" || "$source" == "nuxtjs" || \
              "$source" == "nestjs" || "$source" == "express" || "$source" == "react" ]]; then
            local domain
            domain=$(basename "$(dirname "$conf_file")")
            domains+=("$domain")
        fi
    done
    echo "${domains[@]}"
}

get_app_setting() {
    local domain="$1"
    local key="$2"
    local conf="${WEB_DATA_DIR}/${domain}/.settings.conf"
    grep "^${key}=" "$conf" 2>/dev/null | cut -d= -f2
}
