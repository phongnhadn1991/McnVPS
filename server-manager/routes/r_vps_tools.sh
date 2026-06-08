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

for vps_controller in "${MENU_DIR}"/controllers/vps/*.sh; do
    if [ -f "$vps_controller" ]; then
        # shellcheck source=/var/mcnvps/server-manager/vps/php/*.sh
        source "$vps_controller"
    fi
done

vps_tools_menu() {
    local mem_total mem_free swap_total swap_free
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_free=$(awk '/MemFree/ { print $2 }' /proc/meminfo)
    swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    swap_free=$(awk '/SwapFree/ {print $2}' /proc/meminfo)

    while true; do
        clear_screen
        echo "${BLUE}========== Cong cu VPS ================${NC}"
        echo "${BLUE}=======================================${NC}"
        printf "${BLUE}CPU loading     : %s${NC}\n" "$(top -b -n1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
        printf "${BLUE}Ram             : %s${NC}\n" "$(bytes_for_humans "${mem_total}") (Con trong: $(bytes_for_humans "${mem_free}"))"
        printf "${BLUE}Swap            : %s${NC}\n" "$(bytes_for_humans "${swap_total}") (Con trong: $(bytes_for_humans "${swap_free}") )"
        printf "${BLUE}Disk da su dung : %s${NC}\n" "$(df -lh | awk '{if ($6 == "/") { print $5 }}' | head -1 | cut -d'%' -f1)%"
        printf "${BLUE}Inode da su dung: %s${NC}\n" "$(df -hi | awk '{if ($6 == "/") { print $5 }}' | head -1 | cut -d'%' -f1)%"
        echo "${BLUE}=======================================${NC}"
        echo ""
        echo "${BLUE}1. Thong tin VPS${NC}"
        echo "${BLUE}2. Tim kiem file dung luong lon${NC}"
        echo "${BLUE}3. Tim kiem process chiem dung ram, cpu${NC}"
        echo "${BLUE}4. Bat/Tat Notify Telegram${NC}"
        echo "${RED}----------------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " vps_tools_menu_choice

        case "$vps_tools_menu_choice" in
            1) vps_info ;;
            2) vps_find_large_file ;;
            3) vps_find_process_occupying_ram_cpu ;;
            4) notify_service ;;
            0) main_menu ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
