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

if ! declare -f parse_args >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

_restore_database() {
    local backup_file db_name

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backup_file)       backup_file="$2"; shift 2 ;;
            --db_name) db_name="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$backup_file" || -z "$db_name" ]]; then
        msg "Usage: _restore_database --backup_file <file> --db_name <db name>"
        exit 1
    fi

    [[ -f "$backup_file" ]] || { msg "$ICON_EXIT File backup khong ton tai: $backup_file"; return 1; }
    is_db_exists "$db_name" || { msg "$ICON_EXIT Database ${db_name} khong ton tai"; return 1; }

    msg "$ICON_TOOL Dang giai nen va khoi phuc database. Vui long doi..."
    pv "$backup_file" | gunzip | mariadb "$db_name"
}

_restore_source() {
    local backup_file base_dir

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backup_file) backup_file="$2"; shift 2 ;;
            --base_dir)    base_dir="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$backup_file" || -z "$base_dir" ]]; then
        msg "Usage: _restore_source --backup_file <file> --base_dir </base_dir>"
        exit 1
    fi

    [[ -f "$backup_file" ]] || { msg "$ICON_EXIT File backup khong ton tai: $backup_file"; return 1; }
    [[ -d "$base_dir" ]] || { msg "$ICON_EXIT Thu muc khong ton tai: $base_dir"; return 1; }

    msg "$ICON_TOOL Dang giai nen va khoi phuc ma nguon. Vui long doi..."
    rm -rf "${base_dir:?}/public_html/"
    pv "$backup_file" | tar -C "${base_dir}/" -xz
}

_restore_full() {
    local domain backup_dir db_name base_dir

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backup_dir) backup_dir="$2"; shift 2 ;;
            --db_name)    db_name="$2"; shift 2 ;;
            --base_dir)   base_dir="$2"; shift 2 ;;
            --domain)     domain="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$backup_dir" || -z "$base_dir" || -z "$db_name" ]]; then
        msg "Usage: _restore_full --backup_dir </backup_dir> --base_dir </base_dir> --db_name <db name>"
        exit 1
    fi

    _restore_source   --backup_file "${backup_dir}/${domain}.tar.gz" --base_dir "$base_dir"
    _restore_database --backup_file "${backup_dir}/${db_name}.sql.gz" --db_name "$db_name"
}

_restore_common() {
    local domain="$1" backup_date="$2" backup_path="$3" restore_type="$4" use_rclone="$5"
    local db_name base_dir owner owner_folder
    local backup_dir="/backup/${backup_date}/${domain}"

    mkdir -p "$backup_dir"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    if [[ "$use_rclone" == "yes" ]]; then
        case "$restore_type" in
            source)
                rclone copy "${backup_path}/${backup_date}/${domain}/${domain}.tar.gz" "$backup_dir" --bwlimit 30M
                ;;
            database)
                rclone copy "${backup_path}/${backup_date}/${domain}/${db_name}.sql.gz" "$backup_dir" --bwlimit 30M
                ;;
            full|*)
                rclone copy "${backup_path}/${backup_date}/${domain}" "$backup_dir" --bwlimit 30M
                ;;
        esac
    fi

    case "$restore_type" in
        source)   _restore_source --backup_file "${backup_dir}/${domain}.tar.gz" --base_dir "$base_dir" ;;
        database) _restore_database --backup_file "${backup_dir}/${db_name}.sql.gz" --db_name "$db_name" ;;
        full|*)   _restore_full --domain "$domain" --backup_dir "$backup_dir" --base_dir "$base_dir" --db_name "$db_name" ;;
    esac

    set_site_dir_permission --owner "$owner" --owner_folder "$owner_folder" --domain "$domain"

    [[ "$use_rclone" == "yes" ]] && rm -rf "/backup/${backup_date:?}"
}

restore_backup() {
    local backup_scope backup_remote_name backup_path domain backup_date restore_type

    source "${HOSTVN_DIR}/.mcnvps.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh"
        exit 1
    }

    case "$backup_scope" in
        drive|sftp|local)
            if [ "$backup_scope" == 'sftp' ]; then
                backup_path="${backup_remote_name}:/backup/${IP_ADDRESS}"
            elif [ "$backup_scope" == 'drive' ]; then
                backup_path="${backup_remote_name}:${IP_ADDRESS}"
            else
                backup_path="/backup"
            fi

            run_prompt_or_exit prompt_select_backup backup_date "backup_menu" "$backup_scope" "$backup_path" \
                "Chon ngay backup muon restore" "Nhap tu khoa de tim kiem ngay backup"

            run_prompt_or_exit prompt_select_backup domain "backup_menu" "$backup_scope" "$backup_path/$backup_date" \
                "Chon domain de restore" "Nhap tu khoa de tim kiem ten mien muon restore"

            run_prompt_or_exit prompt_select_restore_type restore_type "backup_menu"

            if ! prompt_yes_no "${RED}Ban muon kho phuc du lieu cho website ${domain}?${NC}"; then
                msg "$ICON_EXIT Huy bo phuc hoi du lieu"
                backup_menu
                press_enter_to_continue; return 0
            fi

            if [ "$backup_scope" == "local" ]; then
                _restore_common "$domain" "$backup_date" "$backup_path" "$restore_type" "no"
            else
                _restore_common "$domain" "$backup_date" "$backup_path" "$restore_type" "yes"
            fi
            ;;
        *)
            msg "$ICON_EXIT Hien chua ho tro restore thong qua $backup_scope"
            exit 1
            ;;
    esac

    msg "$ICON_SUCCESS Restore backup thanh cong" 'green'
}
