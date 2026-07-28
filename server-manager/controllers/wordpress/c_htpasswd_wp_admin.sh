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

if ! declare -f prompt_select_website >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/prompt.sh"
fi

if ! declare -f nginx_reload >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_nginx.sh"
fi

if ! declare -f format_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

htpasswd_wp_admin() {
    clear_screen
    local domain base_dir owner php_version
    local vhost_file htpasswd_dir htpasswd_file

    msg "$ICON_GLOBE Chon WordPress Website"
    run_prompt_or_exit prompt_select_website domain "wordpress_sec_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    vhost_file="${SITE_AVAILABLE_DIR}/${domain}.conf"
    htpasswd_dir="${base_dir}/htpasswd"
    htpasswd_file="${htpasswd_dir}/.htpasswd"

    if [[ -f "$htpasswd_file" ]] && grep -q "auth_basic" "$vhost_file" 2>/dev/null; then
        if prompt_yes_no "htpasswd dang bat cho ${domain}. Tat htpasswd?"; then
            rm -rf "$htpasswd_dir"
            sed -i '/auth_basic/d' "$vhost_file"
            sed -i '/htpasswd/d' "$vhost_file"
            format_nginx_config "$vhost_file"
            nginx_reload
            update_site_setting_vars "${WEB_DATA_DIR}/${domain}/.settings.conf" "htpasswd_wp_admin" "no"
            msg "$ICON_SUCCESS Da tat htpasswd cho ${domain}" 'green'
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    else
        if prompt_yes_no "Bat htpasswd bao ve wp-login.php cho ${domain}?"; then
            if ! command -v htpasswd &>/dev/null; then
                apt-get install -y apache2-utils >/dev/null 2>&1
            fi

            local ht_user ht_pass
            read -rp "Nhap username cho htpasswd: " ht_user
            if [[ -z "$ht_user" ]]; then
                msg "$ICON_EXIT Username khong duoc de trong"
                press_enter_to_continue; return 0
            fi

            ht_pass=$(gen_pass)

            mkdir -p "$htpasswd_dir"
            htpasswd -b -c "$htpasswd_file" "$ht_user" "$ht_pass"
            chown -R "${owner}:${owner}" "$htpasswd_dir"
            chmod 644 "$htpasswd_file"

            if ! grep -q "auth_basic" "$vhost_file" 2>/dev/null; then
                sed -i "/location ~ \\\\\.php/i\\
    location = /wp-login.php {\\
        auth_basic \"Restricted Access\";\\
        auth_basic_user_file ${htpasswd_file};\\
        include /etc/nginx/fastcgi_params;\\
        fastcgi_pass unix:/run/php/php${php_version}-fpm-${owner}.sock;\\
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\\
    }" "$vhost_file"
                format_nginx_config "$vhost_file"
                nginx_reload
            fi

            update_site_setting_vars "${WEB_DATA_DIR}/${domain}/.settings.conf" "htpasswd_wp_admin" "yes"

            echo ""
            msg "$ICON_SUCCESS Da bat htpasswd cho ${domain}" 'green'
            echo "${GREEN}-----------------------------------${NC}"
            echo "${GREEN}Username  : ${ht_user}${NC}"
            echo "${GREEN}Password  : ${ht_pass}${NC}"
            echo "${GREEN}-----------------------------------${NC}"
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    fi

    press_enter_to_continue
    wordpress_sec_menu
}
