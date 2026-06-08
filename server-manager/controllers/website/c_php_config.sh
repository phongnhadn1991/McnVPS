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

if ! declare -f prompt_fw_php_param_value >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/prompt.sh"
fi

php_display_error() {
    local domain php_version action

    run_prompt_or_exit prompt_select_website domain "website_menu"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    local php_pool_file="${PHP_BASE_DIR}/${php_version}/fpm/pool.d/${domain}.conf"
    if [[ ! -f "$php_pool_file" ]]; then
        msg "$ICON_EXIT Khong tim thay PHP Pool: ${domain}"
        exit 1
    fi

    if grep -q "display_errors" "$php_pool_file"; then
        prompt_yes_no "Ban muon tat hien thi loi PHP cho website ${domain}?" && action="off"
    else
        prompt_yes_no "Ban muon bat hien thi loi PHP cho website ${domain}?" && action="on"
    fi

    if [[ -n "$action" ]]; then
        sed -i '/display_errors/d' "$php_pool_file"

        if [[ "$action" == "on" ]]; then
            echo "php_admin_value[display_errors] = On" >>"$php_pool_file"
            msg "$ICON_SUCCESS Da bat hien thi loi PHP cho website: ${domain}" 'green'
        else
            echo "php_admin_value[display_errors] = Off" >>"$php_pool_file"
            msg "$ICON_SUCCESS Da tat hien thi loi PHP cho website: ${domain}" 'green'
        fi

        systemctl reload "php${php_version}-fpm"
    fi

    website_php_conf_menu
}

change_php_param() {
    local php_version domain php_pool_file php_param php_param_current_value php_param_new_value

    run_prompt_or_exit prompt_select_website domain "website_menu"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    php_pool_file="${PHP_BASE_DIR}/${php_version}/fpm/pool.d/${domain}.conf"
    if [[ ! -f "$php_pool_file" ]]; then
        msg "$ICON_EXIT Khong tim thay PHP Pool: ${domain}"
        exit 1
    fi

    run_prompt_or_exit prompt_select_php_param php_param "website_php_conf_menu"

    php_param_current_value="$(grep "php_admin_value\[$php_param\]" "$php_pool_file" | awk -F'=' '{print $2}' | xargs)"
    echo "Gia tri hien tai cua $php_param la: ${RED}${php_param_current_value:-Not set}${NC}"
    run_prompt_or_exit prompt_fw_php_param_value php_param_new_value "website_php_conf_menu"

    sed -i "/${php_param}/d" "$php_pool_file"

    case "$php_param" in
        memory_limit|post_max_size|upload_max_filesize)
            php_param_new_value="${php_param_new_value}M"
            ;;
    esac

    echo "php_admin_value[${php_param}] = ${php_param_new_value}" >>"$php_pool_file"
    systemctl reload "php${php_version}-fpm"
    msg "$ICON_SUCCESS Da thay doi tham so PHP ${php_param} thanh ${php_param_new_value} cho website: ${domain}" 'green'
    website_php_conf_menu
}
