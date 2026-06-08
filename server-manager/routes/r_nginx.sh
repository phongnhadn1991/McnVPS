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

for nginx_controller in "${MENU_DIR}"/controllers/nginx/*.sh; do
    if [ -e "$nginx_controller" ]; then
        # shellcheck source=/var/mcnvps/server-manager/controllers/nginx/*.sh
        source "$nginx_controller"
    fi
done

nginx_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== QUAN LY Nginx ==========${NC}"
        echo "${BLUE}1. Reload Nginx${NC}"
        echo "${BLUE}2. Restart Nginx${NC}"
        echo "${BLUE}3. Stop Nginx${NC}"
        echo "${BLUE}4. Rebuild Nginx${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " nginx_choice

        case "$nginx_choice" in
            1) reload_nginx ;;
            2) restart_nginx ;;
            3) stop_nginx ;;
            4) rebuild_nginx ;;
            0) main_menu ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
