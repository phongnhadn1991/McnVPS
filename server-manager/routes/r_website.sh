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

for website_controller in "${MENU_DIR}"/controllers/website/*.sh; do
    website_controller_name="$(basename "$website_controller")"

    if [[ -e "$website_controller" && "$website_controller_name" != 'c_alias_domain.sh' && "$website_controller_name" != 'c_redirect_domain.sh' ]]; then
        # shellcheck source=/var/mcnvps/server-manager/controllers/website/*.sh
        source "$website_controller"
    fi
done

for website_sub_route in "${MENU_DIR}"/routes/website/*.sh; do
    # shellcheck source="${MENU_DIR}/routes/website/*.sh"
    source "$website_sub_route"
done

website_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== QUAN LY Website ==========${NC}"
        echo "${BLUE}1. Them Website${NC}"
        echo "${BLUE}2. Xoa Website${NC}"
        echo "${BLUE}3. Clear Opcache${NC}"
        echo "${BLUE}4. Thay doi ten mien${NC}"
        echo "${BLUE}5. Clone Website${NC}"
        echo "${BLUE}6. Ky SSL${NC}"
        echo "${BLUE}7. Alias/Redirect Domain${NC}"
        echo "${BLUE}8. Quan ly Nginx Cache${NC}"
        echo "${BLUE}9. Danh Sach Website${NC}"
        echo "${BLUE}10. Cau hinh PHP${NC}"
        echo "${BLUE}11. Doi thong tin Database${NC}"
        echo "${BLUE}12. Phan quyen website${NC}"
        echo "${BLUE}13. Xem thong tin website${NC}"
        echo "${BLUE}14. Redirect HTTP to HTTPs${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " website_choice

        case "$website_choice" in
            1) add_website ;;
            2) delete_site ;;
            3) clear_php_opcache ;;
            4) change_domain_website ;;
            5) clone_website ;;
            6) sign_ssl_free ;;
            7) website_alias_redirect_menu ;;
            8) nginx_cache_menu ;;
            9) list_all_website ;;
            10) website_php_conf_menu ;;
            11) change_db_info ;;
            12) fix_website_permission ;;
            13) view_website_details ;;
            14) http_to_https ;;
            0) main_menu ;;
            *) msg "$ICON_EXIT Lua chon khong hop le!"; sleep 1 ;;
        esac
    done
}
