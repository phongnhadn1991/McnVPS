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

source /var/mcnvps/server-manager/config/variables.sh
source "${MENU_DIR}/helpers/function.sh"
source "${MENU_DIR}/validate/rule.sh"

if [ -e "${HOSTVN_DIR}/.mcnvps.conf" ]; then
    source "${HOSTVN_DIR}/.mcnvps.conf"
else
    echo "${RED}$ICON_EXIT Khong tim thay file cau hinh .mcnvps.conf${NC}"
    exit 1
fi

for route in "${MENU_DIR}"/routes/*.sh; do
    if [[ -e "$route" && "$(basename "$route")" != 'main_menu.sh' ]]; then
        # shellcheck source=/var/mcnvps/server-manager/routes/*.sh
        source "$route"
    fi
done

source "${MENU_DIR}/controllers/update/c_update_script.sh"

main_menu() {
    clear_screen
    printf "%s==================================================%s\n" "${BLUE}" "${NC}"
    printf "%s          McnVPS Scripts - VPS Manager Scripts    %s\n" "${BLUE}" "${NC}"
    printf "%s                      Version %s (Beta)           %s\n" "${BLUE}" "${script_version}" "${NC}"
    printf "%s==================================================%s\n" "${BLUE}" "${NC}"
    printf "%sIP VPS:     %s%s\n" "${BLUE}" "$(get_all_ips)" "${NC}"
    printf "%sOS:         %s%s\n" "${RED}" "$PRETTY_NAME" "${NC}"
    # shellcheck disable=SC2154
    printf "%sphpMyAdmin: %s%s\n" "${RED}" "http://$(get_first_ip):${admin_port}/phpmyadmin" "${NC}"
    printf "%s==================================================%s\n" "${BLUE}" "${NC}"

    while true; do
        echo "${BLUE}========== QUAN LY VPS ==========${NC}"
        echo "${BLUE}1. Quan ly Website${NC}"
        echo "${BLUE}2. Quan ly MariaDB${NC}"
        echo "${BLUE}3. Quan ly PHP${NC}"
        echo "${BLUE}4. Quan ly Nginx${NC}"
        echo "${BLUE}5. WordPress tools${NC}"
        echo "${BLUE}6. Quan ly Backup${NC}"
        echo "${BLUE}7. Quan ly Firewall${NC}"
        echo "${BLUE}8. VPS Tools${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${BLUE}9. Update Script${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${RED}0.${NC} $ICON_EXIT ${RED}Thoat${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " main_choice

        case "$main_choice" in
            1) website_menu ;;
            2) mariadb_menu ;;
            3) php_menu ;;
            4) nginx_menu ;;
            5) wordpress_menu ;;
            6) backup_menu ;;
            7) firewall_menu ;;
            8) vps_tools_menu ;;
            9) update_menu ;;
            0) clear_screen && exit 0 ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1; clear_screen ;;
        esac
    done
}

main_menu
