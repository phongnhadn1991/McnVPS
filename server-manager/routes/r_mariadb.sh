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

for mariadb_controller in "${MENU_DIR}"/controllers/mariadb/*.sh; do
    if [ -e "$mariadb_controller" ]; then
        # shellcheck source=/var/mcnvps/server-manager/controllers/mariadb/*.sh
        source "$mariadb_controller"
    fi
done

mariadb_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== QUAN LY MariaDB ==========${NC}"
        echo "${BLUE}1. Restart MariaDB${NC}"
        echo "${BLUE}2. Stop MariaDB${NC}"
        echo "${BLUE}3. Tao MySQL user${NC}"
        echo "${BLUE}4. Tao MySQL Database${NC}"
        echo "${BLUE}5. Phan quyen cho user${NC}"
        echo "${BLUE}6. Doi mat khau MySQL user${NC}"
        echo "${BLUE}7. Xoa MySQL user${NC}"
        echo "${BLUE}8. Xoa MySQL Database${NC}"
        echo "${BLUE}9. Export Database${NC}"
        echo "${BLUE}10. Thong tin dang nhap phpMyAdmin${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " mariadb_choice

        case "$mariadb_choice" in
            1) mariadb_restart ;;
            2) mariadb_stop ;;
            3) mariadb_create_user ;;
            4) mariadb_create_db ;;
            5) mariadb_grant_user ;;
            6) mariadb_change_pass_user ;;
            7) mariadb_delete_user ;;
            8) mariadb_delete_database ;;
            9) mariadb_export_database ;;
            10) view_phpmyadmin_login_info ;;
            0) main_menu ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
