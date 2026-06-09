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

wp_cache_plugin_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== WordPress Cache Plugins ==========${NC}"
        echo "${BLUE}1. Cau hinh WP Rocket${NC}"
        echo "${BLUE}2. Cau hinh W3 Total Cache${NC}"
        echo "${BLUE}----------------------------------${NC}"
        echo "${BLUE}3. Cai dat Redis Server${NC}"
        echo "${BLUE}4. Bat Redis Object Cache cho website${NC}"
        echo "${BLUE}5. Tat Redis Object Cache cho website${NC}"
        echo "${BLUE}6. Kiem tra trang thai Redis${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " wp_cache_plugin_menu_choice

        case "$wp_cache_plugin_menu_choice" in
            1) enable_wp_rocket ;;
            2) enable_w3_total ;;
            3) install_redis_server ;;
            4) enable_redis_object_cache ;;
            5) disable_redis_object_cache ;;
            6) redis_server_status ;;
            0) wordpress_menu ; return 0 ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
