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

for backup_controller in "${MENU_DIR}"/controllers/backup/*.sh; do
    if [ -e "$backup_controller" ]; then
        # shellcheck source=/var/mcnvps/server-manager/controllers/backup/*.sh
        source "$backup_controller"
    fi
done

backup_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== QUAN LY Backup ==========${NC}"
        echo "${BLUE}1. Bat/Tat backup tu dong${NC}"
        echo "${BLUE}2. Restore tu dong${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${BLUE}3. Backup thu cong tung site${NC}"
        echo "${BLUE}4. Restore thu cong tung site${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " backup_menu_choice

        case "$backup_menu_choice" in
            1) backup_action ;;
            2) restore_backup ;;
            3) backup_site_manual ;;
            4) restore_site_manual ;;
            0) main_menu ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
