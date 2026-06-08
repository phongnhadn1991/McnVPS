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
source "${MENU_DIR}/models/m_nginx.sh"

if ! declare -f format_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

add_alias_domain() {
    local origin_domain=''
    local alias_domain=''

    msg "$ICON_GLOBE Lua chon Website goc"
    run_prompt_or_exit prompt_select_website origin_domain "website_menu"
    sleep 0.5

    msg "Nhap domain muon dung lam alias"
    run_prompt_or_exit prompt_domain_input alias_domain "website_menu"
    sleep 0.5

    if ! prompt_yes_no "Ban muon su dung ten mien ${RED}$alias_domain${NC} lam alias cho ${RED}$origin_domain${NC} ?"; then
        msg "Huy thao tac"
        website_menu
    fi

    local origin_vhost="${SITE_AVAILABLE_DIR}/${origin_domain}.conf"
    local alias_vhost="${SITE_ALIAS_CONF_DIR}/${alias_domain}.conf"
    local ssl_cert_path='/etc/nginx/ssl/default/server.crt'
    local ssl_key_path='/etc/nginx/ssl/default/server.key'

    if [ ! -e "$origin_vhost" ]; then
        msg "$ICON_EXIT vhost ${origin_domain} khong ton tai"
    fi

    mkdir -p "${SITE_ALIAS_CONF_DIR}"
    run_or_exit "" cp "$origin_vhost" "${alias_vhost}"

    sed -i "/^\s*server_name\s\+.*\b$origin_domain\b.*;/d" "$alias_vhost"
    sed -i "/#SERVER_NAME/a\    server_name $alias_domain www.$alias_domain;" "$alias_vhost"

    sed -i '/^\s*ssl_certificate\s\+[^;]*;/d' "$alias_vhost"
    sed -i '/^\s*ssl_certificate_key\s\+[^;]*;/d' "$alias_vhost"
    sed -i "/#SSL_CERT/a\    ssl_certificate     $ssl_cert_path;\n    ssl_certificate_key $ssl_key_path;" "$alias_vhost"

    run_or_exit "" format_nginx_config "$alias_vhost"

    create_symlink "${alias_vhost}" "${SITE_ENABLED_DIR}/${alias_domain}.conf"

    if [ ! -e "${SITE_ENABLED_DIR}/${alias_domain}.conf" ]; then
        msg "$ICON_EXIT Khong tao duoc symlink cho vhost ${alias_domain}.conf"
        delete_file "$alias_vhost"
        exit 1
    fi

    if ! test_nginx_config; then
        delete_file "${SITE_ENABLED_DIR}/${alias_domain}.conf"
        delete_file "${alias_vhost}"
        msg "$NGINX_T_REPLY"
        msg "$ICON_EXIT Da xay ra loi khi them Alias"
        exit 1
    fi

    mkdir -p "${SSL_PENDING_DIR}"
    touch "${SSL_PENDING_DIR}/${alias_domain}"
    nginx_reload

    msg "$ICON_CHECK Them alias thanh cong" "green"
    website_menu
}

delete_alias_domain() {
    local alias_domain
    run_prompt_or_exit prompt_select_website alias_domain "website_menu" "$SITE_ALIAS_CONF_DIR" "f"

    delete_file "${SITE_ENABLED_DIR}/${alias_domain}.conf"
    delete_file "${SITE_ALIAS_CONF_DIR}/${alias_domain}.conf"
    nginx_reload

    msg "${ICON_CHECK} ${GREEN}Xoa Alias Domain $alias_domain thanh cong!${NC}"
    website_menu
}

list_all_alias_domain() {
    local -A seen_domains=()
    local -a domains=()

    if [[ -d "$SITE_ALIAS_CONF_DIR" ]]; then
        while IFS= read -r -d '' conf; do
            local origin_domain=''
            local alias_domain=''

            alias_domain=$(basename "${conf%.conf}")
            origin_domain=$(awk '/^\s*root\s+/ {
                              if (match($2, /\/([^\/]+)\/public_html/, m)) {
                                  print m[1]
                                  exit
                              }
                          }' "$conf")

            if [[ -z "${seen_domains[$alias_domain]}" ]]; then
                seen_domains["$alias_domain"]=1
                domains+=( "$alias_domain ${GREEN}(Alias -> $origin_domain)${NC}" )
            fi
        done < <(find "$SITE_ALIAS_CONF_DIR" -maxdepth 1 -type f -name "*.conf" -print0 | sort -z)
    fi

    if [[ ${#domains[@]} -eq 0 ]]; then
        msg "${ICON_EXIT} Khong tim thay Alias Domain nao tren server"
        website_menu
    fi

    print_paginated_list --title "${GREEN}${ICON_GLOBE} Danh sach Alias Domain${NC}" \
        --items domains --page_size 20 --cols 2 --fallback_cmd 'website_alias_redirect_menu'
    press_enter_to_continue; return 0
}
