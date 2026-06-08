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

source "${MENU_DIR}/models/m_mysql.sh"

mariadb_restart() {
    systemctl restart mariadb

    if [ "$(systemctl is-active mariadb)" != 'active' ]; then
        msg "$ICON_EXIT Restart MariaDB that bai"
        exit 1
    fi

    msg "$ICON_CHECK Restart MariaDB thanh cong" "blue"
    sleep 2
    mariadb_menu
}

mariadb_stop() {
    systemctl stop mariadb

    if [ "$(systemctl is-active mariadb)" == 'active' ]; then
        msg "$ICON_EXIT Stop MariaDB that bai"
        exit 1
    fi

    msg "$ICON_CHECK Stop MariaDB thanh cong" "blue"
    sleep 2
    mariadb_menu
}

_show_mysql_user_info() {
    local mysql_user="$1"
    local mysql_pass="$2"

    if [[ -n "$mysql_user" && -n "$mysql_pass" ]]; then
        printf "\n"
        echo "${GREEN}Duoi day la thong tin Mysql User cua ban!${NC}"
        echo "${GREEN}---------------------------${NC}"
        echo "${GREEN}User         :${NC} ${RED}${mysql_user}${NC}"
        echo "${GREEN}Password     :${NC} ${RED}${mysql_pass}${NC}"
        echo "${GREEN}---------------------------${NC}"
        printf "\n"
    fi
}

mariadb_create_user() {
    local mysql_user
    local mysql_pass
    local db_name

    mysql_pass=$(gen_pass)

    run_prompt_or_exit prompt_mysql_user_input mysql_user "mariadb_menu"
    sleep 0.5

    create_mysql_user "$mysql_user" "$mysql_pass"
    clear_screen
    # shellcheck disable=SC2064
    trap "_show_mysql_user_info '$mysql_user' '$mysql_pass'" EXIT

    if prompt_yes_no 'Ban co muon gan user vao MySQL Database khong ?'; then
        run_prompt_or_exit prompt_select_mysql_database db_name 'wordpress_menu'
        grant_mysql_user_privileges "$db_name" "$mysql_user"
        msg "$ICON_CHECK Phan quyen cho user $mysql_user tren database $db_name thanh cong" 'blue'
    fi

    press_enter_to_continue; return 0
}

mariadb_create_db() {
    local mysql_db

    run_prompt_or_exit prompt_mysql_db_input mysql_db 'mariadb_menu'
    sleep 0.5

    create_database "$mysql_db"

    msg "$ICON_CHECK Tao Database $mysql_db thanh cong" 'blue'
    mariadb_menu
}

mariadb_grant_user() {
    local mysql_user
    local mysql_db

    run_prompt_or_exit prompt_select_mysql_user mysql_user 'mariadb_menu'
    run_prompt_or_exit prompt_select_mysql_database mysql_db 'mariadb_menu'

    grant_mysql_user_privileges "$mysql_db" "$mysql_user"
    msg "$ICON_CHECK Phan quyen cho user $mysql_user tren database $mysql_db thanh cong" 'blue'
    mariadb_menu
}

mariadb_delete_user() {
    local mysql_user

    run_prompt_or_exit prompt_select_mysql_user mysql_user 'mariadb_menu'

    if delete_mysql_user "$mysql_user"; then
        msg "$ICON_CHECK Xoa user $mysql_user thanh cong" 'blue'
    else
        msg "$ICON_EXIT $DELETE_MYSQL_USER_REPLY" 'red'
    fi

    mariadb_menu
}

mariadb_delete_database() {
    local mysql_db

    run_prompt_or_exit prompt_select_mysql_database mysql_db 'mariadb_menu'

    if delete_mysql_db "$mysql_db"; then
        msg "$ICON_CHECK Xoa database $mysql_db thanh cong" 'blue'
    else
        msg "$ICON_EXIT $DELETE_MYSQL_USER_REPLY"
    fi

    mariadb_menu
}

mariadb_export_database() {
    local mysql_db
    local compress='no'
    local export_path

    run_prompt_or_exit prompt_select_mysql_database mysql_db 'mariadb_menu'
    if prompt_yes_no "Ban co muon nen sql khong ?"; then
        compress='yes'
    fi

    mkdir -p "$LOCAL_BACKUP_DIR"

    export_path="${LOCAL_BACKUP_DIR}/${mysql_db}-$(date +%Y%m%d).sql"
    [ "$compress" == "yes" ] && export_path="${export_path}.gz"

    if [ "$compress" == "yes" ]; then
        cmd="mariadb-dump --routines --triggers \"$mysql_db\" | gzip -9 > \"$export_path\""
    else
        cmd="mariadb-dump --routines --triggers \"$mysql_db\" > \"$export_path\""
    fi

    if ! eval "$cmd"; then
        msg "$ICON_EXIT Khong the xuat database $mysql_db" "red"
        exit 1
    fi

    msg "$ICON_CHECK Xuat database $mysql_db thanh cong den $export_path" "blue"
    mariadb_menu
}

mariadb_change_pass_user() {
    local mysql_user
    local mysql_pass

    run_prompt_or_exit prompt_select_mysql_user mysql_user 'mariadb_menu'

    mysql_pass=$(gen_pass)

    if ! change_mysql_user_password "$mysql_user" "$mysql_pass"; then
        msg "$ICON_EXIT Khong the doi mat khau cho user $mysql_user"
        exit 1
    fi

    printf "\n"
    echo "${GREEN}Duoi day la thong tin MySQL User cua ban${NC}"
    echo "${GREEN}---------------------------${NC}"
    echo "${GREEN}MySQL User     :${NC} ${RED}$mysql_user${NC}"
    echo "${GREEN}MySQL Password :${NC} ${RED}$mysql_pass${NC}"
    echo "${GREEN}phpMyAdmin Url :${NC} ${RED}http://${IP_ADDRESS}:${admin_port}/phpmyadmin${NC}"
    echo "${GREEN}---------------------------${NC}"
    press_enter_to_continue; return 0
}

view_phpmyadmin_login_info() {
    local mysql_user
    local mysql_admin_pwd
    local admin_port

    # shellcheck disable=SC1090
     source "${FILE_INFO}" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${FILE_INFO}"
        exit 1
    }

    printf "\n"
    echo "${GREEN}Duoi day la thong tin dang nhap phpMyAdmin cua ban${NC}"
    echo "${GREEN}---------------------------${NC}"
    echo "${GREEN}User     :${NC} ${RED}$mysql_user${NC}"
    echo "${GREEN}Password :${NC} ${RED}$mysql_admin_pwd${NC}"
    echo "${GREEN}Url      :${NC} ${RED}http://${IP_ADDRESS}:${admin_port}/phpmyadmin${NC}"
    echo "${GREEN}---------------------------${NC}"
    press_enter_to_continue; return 0
}
