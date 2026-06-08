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

source "${MENU_DIR}"/controllers/website/c_alias_domain.sh
source "${MENU_DIR}"/controllers/website/c_redirect_domain.sh

website_alias_redirect_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== QUAN LY Alias/Redirect Website ==========${NC}"
        echo "${BLUE}1. Them Alias Domain${NC}"
        echo "${BLUE}2. Xoa Alias Domain${NC}"
        echo "${BLUE}3. Redirect Domain${NC}"
        echo "${BLUE}4. Xoa Redirect Domain${NC}"
        echo "${BLUE}5. List Redirect Domain${NC}"
        echo "${BLUE}6. List Alias Domain${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " website_alias_redirect_choice

        case "$website_alias_redirect_choice" in
            1) add_alias_domain ;;
            2) delete_alias_domain ;;
            3) add_redirect_domain ;;
            4) delete_redirect_domain ;;
            5) list_all_redirect_domain ;;
            6) list_all_alias_domain ;;
            0) website_menu ; return 0 ;;
            *) msg "$ICON_EXIT Lua chon khong hop le!"; sleep 1 ;;
        esac
    done
}
