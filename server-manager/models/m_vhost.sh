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

_set_document_root() {
    local website_source="$1"

    local root_dir=""

    case "$website_source" in
        laravel | symfony | codeigniter4)
            root_dir="public"
            ;;
        magento2)
            root_dir="pub"
            ;;
        cakephp)
            root_dir="webroot"
            ;;
        nuxt)
            root_dir=".output/public"
            ;;
        nextjs)
            root_dir="out"
            ;;
        angular|vue)
            root_dir="dist"
            ;;
        react)
            root_dir="build"
            ;;
        yii2)
            root_dir="web"
            ;;
        *)
            root_dir=""
            ;;
    esac

    echo "${root_dir}"
}

_get_vhost_template() {
    local website_source="$1"
    local template_name=''

    if [ -e "${TEMPLATES_DIR}/nginx/${website_source}.conf" ]; then
        template_name="${website_source}.conf"
    else
        template_name='nginx-vhost.conf'
    fi

    echo "${TEMPLATES_DIR}/nginx/${template_name}"
}

generate_nginx_vhost() {
    local domain
    local owner
    local owner_folder
    local base_dir
    local website_source
    local template_file=''
    local root_dir=''

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)         domain="$2"; shift 2 ;;
            --owner)          owner="$2"; shift 2 ;;
            --owner_folder)   owner_folder="$2"; shift 2 ;;
            --base_dir)       base_dir="$2"; shift 2 ;;
            --website_source) website_source="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$domain" || -z "$owner" || -z "$owner_folder" || -z "$base_dir" || -z "$website_source" ]]; then
        msg "$ICON_EXIT Thieu tham so bat buoc!"
        msg "Can truyen: --domain, --owner, --owner_folder, --base_dir, --website_source"
        exit 1
    fi

    ROLLBACK_SITE_AVAIL="${SITE_AVAILABLE_DIR}/${domain}.conf"
    # shellcheck disable=SC2034
    ROLLBACK_SITE_ENABLED="${SITE_ENABLED_DIR}/${domain}.conf"

    root_dir=$(_set_document_root "$website_source")
    template_file=$(_get_vhost_template "$website_source")

    run_or_exit "" perl -pe "
        s|__DOMAIN__|${domain}|g;
        s|__OWNER_FOLDER__|${owner_folder}|g;
        s|__DOCUMENT_ROOT__|${base_dir}/public_html/${root_dir}|g;
    " "${template_file}" > "$ROLLBACK_SITE_AVAIL"

    append_wp_login "$ROLLBACK_SITE_AVAIL" "$website_source"
    append_laravel_security "$ROLLBACK_SITE_AVAIL" "$website_source"
    append_wp_security "$ROLLBACK_SITE_AVAIL" "$website_source"

    run_or_exit "" sed -i "s|__PHP_SOCKET__|/var/run/php/${owner}.sock|g" "$ROLLBACK_SITE_AVAIL"

    run_or_exit "" sed -i "/#HTTP_STATIC_FILES/r ${TEMPLATES_DIR}/nginx/http-static-file-no-cache.conf" "$ROLLBACK_SITE_AVAIL"
    run_or_exit "" sed -i "/#HTTPS_STATIC_FILES/r ${TEMPLATES_DIR}/nginx/https-static-file-no-cache.conf" "$ROLLBACK_SITE_AVAIL"

    #shellcheck disable=SC2016
    run_or_exit "" sed -i '/#HTTP3_ALT_HEADER/a add_header Alt-Svc '\''h3=":$server_port"; ma=2592000'\'';' "$vhost_file"
    run_or_exit "" sed -i '/#HSLS_HEADER/a more_set_headers "Strict-Transport-Security max-age=31536000; includeSubDomains" always;' "$vhost_file"
}

append_wp_login() {
    local vhost_file="$1"
    local website_source="$2"

    if [[ "$website_source" == "wordpress" ]]; then
        run_or_exit "Them cau hinh Protect Bruteforce wp-login" sed -i "/#HTTP_WP_LOGIN/r ${TEMPLATES_DIR}/nginx/http-wp-login.conf" "$vhost_file"
        run_or_exit "" sed -i "/#HTTPS_WP_LOGIN/r ${TEMPLATES_DIR}/nginx/https-wp-login.conf" "$vhost_file"
    fi
}

append_laravel_security() {
    local vhost_file="$1"
    local website_source="$2"

    if [[ "$website_source" == "laravel" ]]; then
        run_or_exit "Them cau hinh bao mat Laravel" sed -i "/#BEGIN_LARAVEL_SEC/r ${TEMPLATES_DIR}/nginx/laravel-security.conf" "$vhost_file"
    fi
}

append_wp_security() {
    local vhost_file="$1"
    local website_source="$2"

    if [[ "$website_source" == "wordpress" ]]; then
        run_or_exit "Them cau hinh bao mat WordPress" sed -i "/#BEGIN_WP_SEC/a include /etc/nginx/conf.d/wp-security.conf;" "$vhost_file"
    fi
}

enable_nginx_vhost() {
    local domain="$1"
    msg "$ICON_TOOL Enable vhost" "green"
    create_symlink "${SITE_AVAILABLE_DIR}/${domain}.conf" "${SITE_ENABLED_DIR}/${domain}.conf"
}

delete_vhost() {
    local domain="$1"
    msg "$ICON_CLEAN Delete vhost" "green"
    delete_file "${SITE_ENABLED_DIR}/${domain}.conf"
    delete_file "${SITE_AVAILABLE_DIR}/${domain}.conf"
    systemctl reload nginx
}
