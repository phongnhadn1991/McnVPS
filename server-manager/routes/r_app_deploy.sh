#!/bin/bash

##############################################################################################################
#                             Auto Install & Optimize LEMP Stack on Ubuntu                                   #
#                                                                                                            #
#                                    Author: Sanvv - MCN Technical                                           #
#                                        Website: https://mcnvps.net                                         #
#                                                                                                            #
#                                  Please do not remove copyright. Thank!                                    #
#  Copying or using this content for any commercial purpose is strictly prohibited under all circumstances!  #
##############################################################################################################

for app_controller in "${MENU_DIR}"/controllers/app/*.sh; do
    if [ -f "$app_controller" ]; then
        # shellcheck source=/var/mcnvps/server-manager/controllers/app/*.sh
        source "$app_controller"
    fi
done

app_deploy_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== DEPLOY APPLICATION ==========${NC}"
        echo ""

        if command -v node &>/dev/null; then
            printf "${BLUE}Node.js : %s${NC}\n" "$(node -v)"
        else
            printf "${RED}Node.js : Chua cai dat${NC}\n"
        fi

        if command -v pm2 &>/dev/null; then
            local pm2_count
            pm2_count=$(pm2 jlist 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
            printf "${BLUE}PM2     : %s app(s)${NC}\n" "$pm2_count"
        else
            printf "${RED}PM2     : Chua cai dat${NC}\n"
        fi

        if command -v psql &>/dev/null; then
            printf "${BLUE}PostgreSQL : Da cai dat${NC}\n"
        fi

        echo ""
        echo "${BLUE}1. Deploy ung dung moi${NC}"
        echo "${BLUE}2. Quan ly ung dung${NC}"
        echo "${BLUE}3. Quan ly PostgreSQL${NC}"
        echo "${BLUE}4. Cai dat/Cap nhat Node.js${NC}"
        echo "${BLUE}5. Xem Log ung dung${NC}"
        echo "${BLUE}6. Quan ly Webhook (Auto Deploy)${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai menu chinh${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " app_menu_choice

        case "$app_menu_choice" in
            1) deploy_new_app ;;
            2) manage_apps ;;
            3) manage_postgresql_menu ;;
            4) install_nodejs_menu ;;
            5) view_app_logs ;;
            6) manage_webhook_menu ;;
            0) main_menu ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}
