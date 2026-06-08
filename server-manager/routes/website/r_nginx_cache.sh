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

if ! declare -f nginx_fast_cgi_cache >/dev/null 2>&1; then
    source "${MENU_DIR}/controllers/website/c_nginx_cache.sh"
fi

nginx_cache_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== Nginx Cache ==========${NC}"
        echo "${BLUE}1. Bat/Tat Nginx Cache${NC}"
        echo "${BLUE}2. Xoa Cache${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " nginx_cache_menu_choice

        case "$nginx_cache_menu_choice" in
            1) nginx_fast_cgi_cache ;;
            2) delete_nginx_cache ;;
            0) website_menu ; return 0 ;;
            *) msg "$ICON_EXIT Lua chon khong hop le!"; sleep 1 ;;
        esac
    done
}
