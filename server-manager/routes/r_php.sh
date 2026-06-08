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

for php_controller in "${MENU_DIR}"/controllers/php/*.sh; do
    if [ -e "$php_controller" ]; then
        # shellcheck source=/var/mcnvps/server-manager/controllers/php/*.sh
        source "$php_controller"
    fi
done

php_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== QUAN LY PHP ==========${NC}"
        echo "${BLUE}1. Cai dat PHP${NC}"
        echo "${BLUE}2. Reload PHP${NC}"
        echo "${BLUE}3. Restart PHP${NC}"
        echo "${BLUE}4. Stop PHP${NC}"
        echo "${BLUE}5. Uninstall PHP${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " php_choice

        case "$php_choice" in
            1) add_new_php_ver ;;
            2) php_reload ;;
            3) php_restart ;;
            4) php_stop ;;
            5) fore_remove_php ;;
            0) main_menu ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
