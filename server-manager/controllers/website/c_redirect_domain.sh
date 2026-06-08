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

add_redirect_domain() {
    local target_domain=''
    local redirect_domain=''

    msg "Nhap ten mien ban muon redirect"
    run_prompt_or_exit prompt_domain_input redirect_domain "website_menu"
    sleep 0.5

    msg "Nhap ten mien cua website ban muon redirect toi"
    run_prompt_or_exit prompt_domain_input target_domain "website_menu" 'false' 'false'
    sleep 0.5

    mkdir -p "$SITE_REDIRECT_CONF_DIR"
    local redirect_vhost="${SITE_REDIRECT_CONF_DIR}/${redirect_domain}.conf"
    local template_file="${TEMPLATES_DIR}/nginx/nginx_redirect.conf"

    run_or_exit "" perl -pe "
            s|__DOMAIN__|${redirect_domain}|g;
            s|__DOMAIN_REDIRECT_TO__|${target_domain}|g;
        " "${template_file}" > "$redirect_vhost"

    create_symlink "${redirect_vhost}" "${SITE_ENABLED_DIR}/${redirect_domain}.conf" || {
        delete_file "$redirect_vhost"
        msg "$ICON_EXIT $SYMLINK_ERR_REPLY"
        exit 1
    }

    if [ ! -e "${SITE_ENABLED_DIR}/${redirect_domain}.conf" ]; then
        msg "$ICON_EXIT Khong tao duoc symlink cho vhost ${redirect_domain}.conf"
        delete_file "$redirect_vhost"
        exit 1
    fi

    if ! test_nginx_config; then
        delete_file "${SITE_ENABLED_DIR}/${redirect_domain}.conf"
        delete_file "${redirect_vhost}"
        msg "$NGINX_T_REPLY"
        msg "$ICON_EXIT Da xay ra loi khi them Redirect Domain"
        exit 1
    fi

    mkdir -p "${SSL_PENDING_DIR}"
    touch "${SSL_PENDING_DIR}/${redirect_domain}"

    nginx_reload

    msg "$ICON_CHECK Them redirect domain thanh cong" "green"
    website_menu
}

delete_redirect_domain() {
    local redirect_domain
    run_prompt_or_exit prompt_select_website redirect_domain "website_menu" "$SITE_REDIRECT_CONF_DIR" "f"

    delete_file "${SITE_ENABLED_DIR}/${redirect_domain}.conf"
    delete_file "${SITE_REDIRECT_CONF_DIR}/${redirect_domain}.conf"
    nginx_reload

    msg "${ICON_CHECK} ${GREEN}Xoa Redirect Domain $redirect_domain thanh cong!${NC}"
    website_menu
}

list_all_redirect_domain() {
    local -A seen_domains=()
    local -a domains=()

    if [[ -d "$SITE_REDIRECT_CONF_DIR" ]]; then
        while IFS= read -r -d '' conf; do
            local target_domain=''
            local redirect_domain=''

            redirect_domain=$(basename "${conf%.conf}")
            target_domain=$(awk '/^\s*rewrite\s+\^/ {
                              if (match($0, /\$scheme:\/\/([^\/$]+)/, m)) {
                                  print m[1]
                                  exit
                              }
                          }' "$conf")

            if [[ -z "${seen_domains[$redirect_domain]}" ]]; then
                seen_domains["$redirect_domain"]=1
                domains+=( "$redirect_domain ${GREEN}(Redirect -> $target_domain)${NC}" )
            fi
        done < <(find "$SITE_REDIRECT_CONF_DIR" -maxdepth 1 -type f -name "*.conf" -print0 | sort -z)
    fi

    if [[ ${#domains[@]} -eq 0 ]]; then
        msg "${ICON_EXIT} Khong tim thay Redirect Domain nao tren server"
        website_menu
    fi

    print_paginated_list --title "${GREEN}${ICON_GLOBE} Danh sach Redirect Domain${NC}" \
            --items domains --page_size 20 --cols 2 --fallback_cmd 'website_alias_redirect_menu'
    press_enter_to_continue; return 0
}
