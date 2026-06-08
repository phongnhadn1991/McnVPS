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

website_php_conf_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== QUAN LY Website ==========${NC}"
        echo "${BLUE}1. Thay doi phien ban PHP${NC}"
        echo "${BLUE}2. Thay thong so PHP${NC}"
        echo "${BLUE}3. PHP Display Error${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " website_php_conf_menu_choice

        case "$website_php_conf_menu_choice" in
            1) php_selector ;;
            2) change_php_param ;;
            3) php_display_error ;;
            0) website_menu ; return 0 ;;
            *) msg "$ICON_EXIT Lua chon khong hop le!"; sleep 1 ;;
        esac
    done
}
