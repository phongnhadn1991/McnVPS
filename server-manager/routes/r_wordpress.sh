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

for wordpress_sub_route in "${MENU_DIR}"/routes/wordpress/*.sh; do
    # shellcheck source="${MENU_DIR}/routes/wordpress/*.sh"
    source "$wordpress_sub_route"
done

for wp_controller in "${MENU_DIR}"/controllers/wordpress/*.sh; do
    # shellcheck source=/var/mcnvps/server-manager/controllers/wordpress/*.sh
    source "$wp_controller"
done

wordpress_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== WordPress Tools ==========${NC}"
        echo "${BLUE}1. Cai dat WordPress${NC}"
        echo "${BLUE}2. WordPress Lockdown${NC}"
        echo "${BLUE}3. Doi mat khau admin${NC}"
        echo "${BLUE}4. Xoa post revisions${NC}"
        echo "${BLUE}5. Deactivate plugins${NC}"
        echo "${BLUE}6. Bat/Tat Debug mode${NC}"
        echo "${BLUE}7. Bat/Tat WP Cron${NC}"
        echo "${BLUE}8. Plugins SEO Config${NC}"
        echo "${BLUE}9. Plugins Cache Config${NC}"
        echo "${BLUE}10. WordPress Security${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " wordpress_menu_choice

        case "$wordpress_menu_choice" in
            1) install_new_wordpress ;;
            2) wp_lockdown ;;
            3) change_wp_admin_password ;;
            4) delete_wp_post_revisions ;;
            5) deactivate_plugins ;;
            6) wp_debug_mode ;;
            7) wp_cron ;;
            8) wp_seo_plugin_menu ;;
            9) wp_cache_plugin_menu ;;
            10) wordpress_sec_menu ;;
            0) main_menu ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
