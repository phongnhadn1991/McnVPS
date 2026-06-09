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

_list_site_backups() {
    local domain="$1"
    local backup_base="${LOCAL_BACKUP_DIR}/${domain}"

    if [[ ! -d "$backup_base" ]]; then
        return 1
    fi

    local -a dates=()
    while IFS= read -r -d '' dir; do
        dates+=("$(basename "$dir")")
    done < <(find "$backup_base" -mindepth 1 -maxdepth 1 -type d -print0 | sort -rz)

    if [[ ${#dates[@]} -eq 0 ]]; then
        return 1
    fi

    printf '%s\n' "${dates[@]}"
}

_select_backup_date() {
    local domain="$1"
    local -n __result="$2"
    local -a dates=()

    while IFS= read -r line; do
        dates+=("$line")
    done < <(_list_site_backups "$domain")

    if [[ ${#dates[@]} -eq 0 ]]; then
        msg "$ICON_EXIT Khong tim thay ban backup nao cho website ${domain}"
        return 1
    fi

    echo ""
    echo "${GREEN}Danh sach ban backup cua ${domain}:${NC}"
    echo "${GREEN}-----------------------------------${NC}"
    local i=1
    for d in "${dates[@]}"; do
        local dir_size
        dir_size=$(du -sh "${LOCAL_BACKUP_DIR}/${domain}/${d}" 2>/dev/null | cut -f1)
        echo "${BLUE}${i}.${NC} ${d} ${GREEN}(${dir_size})${NC}"
        ((i++))
    done
    echo "${RED}----------------------------------${NC}"
    echo "${RED}0. Huy${NC}"
    echo ""

    local choice
    while true; do
        read -rp "${BLUE}Chon ban backup muon restore:${NC} " choice
        if [[ "$choice" == "0" ]]; then
            return 1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#dates[@]} )); then
            __result="${dates[$((choice-1))]}"
            return 0
        fi
        msg "$ICON_EXIT Lua chon khong hop le"
    done
}

_select_restore_type() {
    local -n __result="$1"
    echo ""
    echo "${GREEN}Chon loai restore:${NC}"
    echo "${BLUE}1.${NC} Full (source + database)"
    echo "${BLUE}2.${NC} Chi source code"
    echo "${BLUE}3.${NC} Chi database"
    echo "${RED}0. Huy${NC}"
    echo ""

    local choice
    while true; do
        read -rp "${BLUE}Chon:${NC} " choice
        case "$choice" in
            1) __result="full";     return 0 ;;
            2) __result="source";   return 0 ;;
            3) __result="database"; return 0 ;;
            0) return 1 ;;
            *) msg "$ICON_EXIT Lua chon khong hop le" ;;
        esac
    done
}

restore_site_manual() {
    clear_screen
    local domain base_dir db_name owner owner_folder php_version
    local backup_date restore_type backup_dir

    msg "$ICON_GLOBE Chon Website muon restore"
    run_prompt_or_exit prompt_select_website domain "backup_menu"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    if ! _select_backup_date "$domain" backup_date; then
        press_enter_to_continue; return 0
    fi

    if ! _select_restore_type restore_type; then
        press_enter_to_continue; return 0
    fi

    backup_dir="${LOCAL_BACKUP_DIR}/${domain}/${backup_date}"

    if ! prompt_yes_no "${RED}Ban muon restore website ${domain} tu ban backup ${backup_date}? Du lieu hien tai se bi ghi de!${NC}"; then
        msg "$ICON_EXIT Huy restore"
        press_enter_to_continue; return 0
    fi

    case "$restore_type" in
        full|source)
            local source_file="${backup_dir}/${domain}.tar.gz"
            if [[ ! -f "$source_file" ]]; then
                msg "$ICON_EXIT Khong tim thay file source backup: ${source_file}"
                press_enter_to_continue; return 0
            fi
            if [[ ! -d "${base_dir}" ]]; then
                msg "$ICON_EXIT Thu muc website khong ton tai: ${base_dir}"
                press_enter_to_continue; return 0
            fi
            msg "$ICON_TOOL Dang restore source code..."
            rm -rf "${base_dir:?}/public_html/"
            if tar -xzf "$source_file" -C "${base_dir}/" 2>/dev/null; then
                msg "$ICON_CHECK Restore source thanh cong" 'green'
            else
                msg "$ICON_EXIT Restore source that bai"
                press_enter_to_continue; return 0
            fi

            # Cap nhat wp-config.php voi DB credentials moi neu la WordPress
            local wp_config="${base_dir}/public_html/wp-config.php"
            if [[ -f "$wp_config" && -n "$db_name" && -n "$db_user" && -n "$db_pass" ]]; then
                msg "$ICON_TOOL Dang cap nhat wp-config.php voi thong tin DB moi..."
                wp --path="${base_dir}/public_html" --allow-root config set DB_NAME "$db_name" 2>/dev/null
                wp --path="${base_dir}/public_html" --allow-root config set DB_USER "$db_user" 2>/dev/null
                wp --path="${base_dir}/public_html" --allow-root config set DB_PASSWORD "$db_pass" 2>/dev/null
                msg "$ICON_CHECK Cap nhat wp-config.php thanh cong" 'green'
            fi
            ;;&
        full|database)
            if [[ -n "$db_name" ]]; then
                local db_file="${backup_dir}/${db_name}.sql.gz"
                if [[ ! -f "$db_file" ]]; then
                    msg "$ICON_EXIT Khong tim thay file database backup: ${db_file}"
                    press_enter_to_continue; return 0
                fi
                if ! is_db_exists "$db_name"; then
                    msg "$ICON_EXIT Database ${db_name} khong ton tai"
                    press_enter_to_continue; return 0
                fi

                # Doc domain cu tu DB truoc khi import (de search-replace sau)
                local wp_config="${base_dir}/public_html/wp-config.php"
                local old_domain=""
                if [[ -f "$wp_config" ]]; then
                    old_domain=$(wp --path="${base_dir}/public_html" --allow-root option get siteurl 2>/dev/null \
                        | sed 's|https\?://||' | sed 's|/.*||')
                fi

                msg "$ICON_TOOL Dang restore database ${db_name}..."
                if gunzip < "$db_file" | mariadb "$db_name" 2>/dev/null; then
                    msg "$ICON_CHECK Restore database thanh cong" 'green'
                else
                    msg "$ICON_EXIT Restore database that bai"
                    press_enter_to_continue; return 0
                fi

                # Neu la WordPress, xu ly domain sau khi import
                if [[ -f "$wp_config" ]]; then
                    # Doc domain cu tu DB vua import (neu chua doc duoc o tren)
                    if [[ -z "$old_domain" ]]; then
                        old_domain=$(wp --path="${base_dir}/public_html" --allow-root option get siteurl 2>/dev/null \
                            | sed 's|https\?://||' | sed 's|/.*||')
                    fi

                    if [[ -n "$old_domain" && "$old_domain" != "$domain" ]]; then
                        # Domain moi khac domain cu -> search-replace toan bo DB
                        msg "$ICON_TOOL Dang replace URL tu ${old_domain} sang ${domain}..."
                        wp --path="${base_dir}/public_html" --allow-root \
                            search-replace "https://${old_domain}" "https://${domain}" --all-tables 2>/dev/null
                        wp --path="${base_dir}/public_html" --allow-root \
                            search-replace "http://${old_domain}" "https://${domain}" --all-tables 2>/dev/null
                        msg "$ICON_CHECK Replace URL thanh cong" 'green'
                    else
                        # Cung domain -> chi update siteurl/home cho chac
                        wp --path="${base_dir}/public_html" --allow-root option update siteurl "https://${domain}" 2>/dev/null
                        wp --path="${base_dir}/public_html" --allow-root option update home "https://${domain}" 2>/dev/null
                    fi
                fi
            fi
            ;;
    esac

    # Fix permissions
    set_site_dir_permission --owner "$owner" --owner_folder "$owner_folder" --domain "$domain"

    echo ""
    msg "$ICON_CHECK Restore website ${domain} thanh cong!" 'green'
    echo "${GREEN}-----------------------------------${NC}"
    echo "${GREEN}Website  :${NC} ${RED}${domain}${NC}"
    echo "${GREEN}Ban backup  :${NC} ${RED}${backup_date}${NC}"
    echo "${GREEN}Loai restore :${NC} ${RED}${restore_type}${NC}"
    echo "${GREEN}-----------------------------------${NC}"

    press_enter_to_continue; return 0
}
