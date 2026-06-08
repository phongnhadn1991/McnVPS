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

wordpress_sec_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== WordPress Security ==========${NC}"
        echo "${BLUE}1. Disable/Enable Install themes/plugins${NC}"
        echo "${BLUE}2. Disable/Enable edit themes/plugins${NC}"
        echo "${BLUE}3. Block truy cap PHP trong thu muc plugins${NC}"
        echo "${BLUE}4. Block truy cap PHP trong thu muc themes${NC}"
        echo "${BLUE}5. Block truy cap user API${NC}"
        echo "${BLUE}6. Block truy cap xmlrpc.php${NC}"
        echo "${BLUE}7. Block scan author${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " wordpress_sec_menu_choice

        case "$wordpress_sec_menu_choice" in
            1) disable_install_plugins_theme ;;
            2) disable_edit_plugins_theme ;;
            3) block_php_in_wp_plugins ;;
            4) block_php_in_wp_themes ;;
            5) block_user_api ;;
            6) block_xmlrpc ;;
            7) block_author_scan ;;
            0) wordpress_menu ; return 0 ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
