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

source "${MENU_DIR}/models/m_nginx.sh"

reload_nginx() {
    nginx_reload || {
        exit 1
    }

    msg "${ICON_CHECK} ${GREEN}Nginx configuration reloaded successfully!${NC}"
    nginx_menu
}

restart_nginx() {
    nginx_restart || {
        exit 1
    }

    msg "${ICON_CHECK} ${GREEN}Nginx configuration restarted successfully!${NC}"
    nginx_menu
}

stop_nginx() {
    nginx_stop
    msg "${ICON_CHECK} ${GREEN}Nginx configuration restarted successfully!${NC}"
    nginx_menu
}

rebuild_nginx() {
    if ! prompt_yes_no "Ban chac chan muon Rebuild Nginx ?"; then
        nginx_menu
    fi

    if ! nginx_rebuild; then
        exit 1
    fi

    msg "${ICON_CHECK} ${GREEN}Nginx configuration rebuilt successfully!${NC}"
    nginx_menu
}

rewrite_nginx_vhost() {
    local domain
    local website_source

    msg "$ICON_GLOBE Lua chon Website muon rewrite vhost"
    run_prompt_or_exit prompt_select_website domain "nginx_menu"

    if ! prompt_yes_no "Ban chac chan muon rewrite vhost cua website: $domain ?"; then
        nginx_menu
    fi

    if [ -e "${SITE_ALIAS_CONF_DIR}/${domain}.conf" ]; then
        local origin_domain
        msg "$ICON_GLOBE Domain ban chon dang dung lam Alias. Hay lua chon Website goc"
        run_prompt_or_exit prompt_select_website origin_domain "website_menu"
        sleep 0.5
    fi

    if [ -e "${SITE_ALIAS_CONF_DIR}/${domain}.conf" ]; then
        local target_domain
        msg "$ICON_GLOBE Nhap ten mien cua website ban muon redirect toi"
        run_prompt_or_exit prompt_select_website target_domain "website_menu"
        sleep 0.5
    fi

    file_settings="${WEB_DATA_DIR}/${domain}/.settings.conf"

    # shellcheck disable=SC1090
    source "$file_settings" || {
        trap - EXIT
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }
}
