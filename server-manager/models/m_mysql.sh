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

if ! declare -f is_db_exists >/dev/null 2>&1; then
    source "${MENU_DIR}/validate/rule.sh"
fi

export_database() {
    local db_name
    local backup_dir
    local compress=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --db_name)     db_name="$2"; shift 2 ;;
            --backup_dir)  backup_dir="$2"; shift 2 ;;
            --compress)    compress=true; shift ;;
            --no-compress) compress=false; shift ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$db_name" || -z "$backup_dir" || ! -d "$backup_dir" ]]; then
        msg "$ICON_EXIT export_database error: Tham so khong hop le: $1"
        exit 1
    fi

    if [ "$compress" == "yes" ]; then
        cmd="mariadb-dump --routines --triggers \"$db_name\" | gzip -9 > \"${backup_dir}/${db_name}.sql.gz\""
    else
        cmd="mariadb-dump --routines --triggers \"$db_name\" > \"${backup_dir}/${db_name}.sql\""
    fi

    if ! eval "$cmd"; then
        msg "$ICON_EXIT Khong the export database $db_name" "red"
        exit 1
    fi

    msg "$ICON_CHECK Xuat database $db_name thanh cong den $backup_dir" "blue"
}

create_database() {
    local db_name="$1"

    run_or_exit "Tao database ${db_name}" mariadb -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\`;"
}

create_mysql_user() {
    local db_user="$1"
    local db_pass="$2"

    local SQL="
        CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';
        CREATE USER IF NOT EXISTS '${db_user}'@'127.0.0.1' IDENTIFIED BY '${db_pass}';
    "

    run_or_exit "Tao user MySQL ${db_user}" mariadb -e "$SQL"
}

grant_mysql_user_privileges() {
    local db_name="$1"
    local db_user="$2"

    local SQL="
        GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost' WITH GRANT OPTION;
        GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'127.0.0.1' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
    "

    run_or_exit "Phan quyen cho user ${db_user}" mariadb -e "$SQL"
}

delete_mysql_db() {
    local db_name="$1"

    if [ -z "$db_name" ]; then
        # shellcheck disable=SC2034
        DELETE_MYSQL_DB_REPLY="Mysql DB Name is empty"
        return 1
    fi

    if mariadb -e "DROP DATABASE IF EXISTS \`${db_name}\`;" 2>/dev/null; then
        return 0
    fi

    # shellcheck disable=SC2034
    DELETE_MYSQL_DB_REPLY="Cannot delete DB $db_name"
    return 1
}

delete_mysql_user() {
    local mysql_user="${1}"

    if [ -z "$mysql_user" ]; then
        # shellcheck disable=SC2034
        DELETE_MYSQL_USER_REPLY="Mysql User is empty"
        return 1
    fi

    local SQL="
        DROP USER IF EXISTS '${mysql_user}'@'localhost';
        DROP USER IF EXISTS '${mysql_user}'@'127.0.0.1';
    "

    if mariadb -e "$SQL" 2>/dev/null; then
        return 0
    fi

    # shellcheck disable=SC2034
    DELETE_MYSQL_USER_REPLY="Cannot delete Mysql User $mysql_user"
    return 1
}

change_mysql_user_password() {
    local mysql_user="$1"
    local mysql_pass="$2"

    if [[ -z "$mysql_user" || -z "$mysql_pass" ]]; then
        # shellcheck disable=SC2034
        CHANGE_MYSQL_USER_PASSWORD_REPLY="Mysql User or password is empty"
        return 1
    fi

    if ! mariadb -e "
        ALTER USER '${mysql_user}'@'localhost' IDENTIFIED BY '${mysql_pass}';
        ALTER USER '${mysql_user}'@'127.0.0.1' IDENTIFIED BY '${mysql_pass}';
    " 2>/dev/null; then
        CHANGE_MYSQL_USER_PASSWORD_REPLY="$ICON_EXIT Khong the doi mat khau cho user $mysql_user" "red"
        return 1
    fi

    return 0
}

empty_db(){
    local db_name="$1"

    if ! is_db_exists "$db_name"; then
        return 1
    fi

    tables=$(mariadb "${db_name}" -e 'show tables' | awk '{ print $1}' | grep -v '^Tables')

    if [ "${#tables[@]}" -gt 0 ]; then
        {
            echo "SET FOREIGN_KEY_CHECKS=0;"

            for t in ${tables}; do
               echo "DROP TABLE \`$t\`;"
            done

            echo "SET FOREIGN_KEY_CHECKS=1;"
        } | mariadb "$db_name"
    fi
}
