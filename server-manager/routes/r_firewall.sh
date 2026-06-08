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

for backup_controller in "${MENU_DIR}"/controllers/firewall/*.sh; do
    if [ -e "$backup_controller" ]; then
        # shellcheck source=/var/mcnvps/server-manager/controllers/firewall/*.sh
        source "$backup_controller"
    fi
done

firewall_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== QUAN LY Firewall ==========${NC}"
        echo "${BLUE}1. Stop/Start Firewall${NC}"
        echo "${BLUE}2. Open Port${NC}"
        echo "${BLUE}3. Block Port${NC}"
        echo "${BLUE}4. Block IP${NC}"
        echo "${BLUE}5. Unblock IP${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " firewall_menu_choice

        case "$firewall_menu_choice" in
            1) stop_start_firewall ;;
            2) fw_open_port ;;
            3) fw_block_port ;;
            4) fw_block_ip ;;
            5) fw_unblock_ip ;;
            0) main_menu ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
