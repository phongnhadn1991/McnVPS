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

install_wordpress() {
    local domain="$1"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh"
        exit 1
    }

    # shellcheck disable=SC2154
    cd_dir "${base_dir}/public_html"
    run_or_exit "Xoa public_html cu" rm -rf ./*

    run_or_exit "Tai WordPress" wp core download --locale=en_US --allow-root

    delete_file license.txt readme.html

    run_or_exit "Tao wp-config.php" wp config create --allow-root \
        --dbname="$db_name" --dbuser="$db_user" --dbpass="$db_pass" --extra-php <<PHP
define('FS_METHOD', 'direct');
define('DISABLE_WP_CRON', true);
define('WP_POST_REVISIONS', 5);
define('WP_MAX_MEMORY_LIMIT', '128M');
PHP

    # shellcheck disable=SC2154
    run_or_exit "Cai dat WordPress" wp core install \
        --url="$domain" \
        --title="$wp_site_name" \
        --admin_user="$wp_admin_user" \
        --admin_password="$wp_admin_pwd" \
        --admin_email="$wp_admin_email" \
        --skip-email \
        --allow-root

    cat > "${base_dir}/public_html/robots.txt" <<END
User-agent: *
Disallow: /wp-admin/
Disallow: /wp-includes/
Disallow: /search?q=*
Disallow: *?replytocom
Disallow: */attachment/*
Disallow: /images/
Allow: /wp-admin/admin-ajax.php
Allow: /*.js$
Allow: /*.css$
END

    cd_dir "${base_dir}/public_html"
    run_or_exit "" wp user update 1 --display_name='Admin' --user_nicename='Admin' \
        --nickname='Admin' --skip-email --allow-root

    # wget -q -O - https://example.com/wp-cron.php?doing_wp_cron
    touch "${WP_CRON_DIR}/${domain}"

    sed -i '/wp_admin_pwd/d' "${WEB_DATA_DIR}/${domain}/.settings.conf"
    delete_file "${base_dir}/public_html/wp-config-sample.php"
}

install_laravel() {
    local domain="$1"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh"
        exit 1
    }

    cd_dir "$base_dir"
    delete_dir "${base_dir}/public_html"

    export COMPOSER_ALLOW_SUPERUSER=1

    # shellcheck disable=SC2154
    run_or_exit "Cai dat Laravel ${laravel_version}" \
        composer create-project --prefer-dist laravel/laravel public_html "$laravel_version"
    unset COMPOSER_ALLOW_SUPERUSER

    # robots.txt
    cat >"${base_dir}/public_html/public/robots.txt" <<END
User-agent: *
END

    # .env configuration
    local env_file="${base_dir}/public_html/.env"
    if [[ -f "$env_file" ]]; then
        run_or_exit "" sed -i "s|APP_URL=http://localhost|APP_URL=http://${domain}|g" "$env_file"

        if [[ -n "$db_name" && -n "$db_user" && -n "$db_pass" ]]; then
            # shellcheck disable=SC2154
            run_or_exit "" sed -i "s|^# DB_DATABASE=.*|DB_DATABASE=${db_name}|g;
                s|^# DB_HOST=.*|DB_HOST=127.0.0.1|g;
                s|^# DB_USERNAME=.*|DB_USERNAME=${db_user}|g;
                s|^# DB_PASSWORD=.*|DB_PASSWORD=${db_pass}|g;
                s|^DB_CONNECTION=.*|DB_CONNECTION=mariadb|g;
                s|^SESSION_DRIVER=.*|SESSION_DRIVER=file|g;
                s|^CACHE_STORE=.*|CACHE_STORE=file|g;
                s|^APP_TIMEZONE=.*|APP_TIMEZONE=Asia/Ho_Chi_Minh|g;
                s|^# CACHE_PREFIX=.*|CACHE_PREFIX=${owner_folder}_|g" "$env_file"
        fi
    fi

    cd_dir "${base_dir}/public_html"

    # shellcheck disable=SC2154
    run_or_exit "Tao application key" php"${php_version}" artisan key:generate
}

install_cakephp() {
    local domain="$1"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh"
        exit 1
    }

    cd_dir "$base_dir"
    delete_dir "${base_dir}/public_html"

    export COMPOSER_ALLOW_SUPERUSER=1

    # shellcheck disable=SC2154
    run_or_exit "Cai dat CakePHP" \
        composer create-project --prefer-dist cakephp/app:~"${cakephp_version}" public_html <<EOF
y
EOF

    unset COMPOSER_ALLOW_SUPERUSER

    # robots.txt
    cat >"${base_dir}/public_html/webroot/robots.txt" <<END
User-agent: *
END
}

install_codeigniter() {
    composer create-project codeigniter4/appstarter project-root
}

install_yii() {
    composer create-project --prefer-dist yiisoft/yii2-app-basic yii
}

install_nodejs_use_nvm() {
    echo "Installing Node.js using NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    source /root/.bashrc

    #  install the latest LTS version
    nvm install --lts

    # example, to install Node.js version 18
    nvm install 18
}

install_nodejs_use_node_source() {
    # https://nodesource.com/products/distributions
    echo "Installing Node.js using NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get update
    apt-get install -y nodejs npm
}

install_n8n() {
    echo "Installing N8N..."
}

install_nextcloud() {
    echo "Installing Nextcloud..."
}
