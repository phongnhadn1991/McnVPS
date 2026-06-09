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

backup_site_manual() {
    clear_screen
    local domain base_dir db_name db_user db_pass owner owner_folder php_version
    local backup_date backup_dir

    msg "$ICON_GLOBE Chon Website muon backup"
    run_prompt_or_exit prompt_select_website domain "backup_menu"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    backup_date=$(date +%Y-%m-%d_%H-%M-%S)
    backup_dir="${LOCAL_BACKUP_DIR}/${domain}/${backup_date}"

    msg "$ICON_TOOL Dang tao thu muc backup: ${backup_dir}"
    mkdir -p "${backup_dir}"

    # Backup source
    msg "$ICON_TOOL Dang backup source code..."
    if tar -czf "${backup_dir}/${domain}.tar.gz" -C "${base_dir}" public_html 2>/dev/null; then
        msg "$ICON_CHECK Backup source thanh cong" 'green'
    else
        msg "$ICON_EXIT Backup source that bai"
        rm -rf "${backup_dir}"
        press_enter_to_continue; return 0
    fi

    # Backup database
    if [[ -n "$db_name" ]]; then
        msg "$ICON_TOOL Dang backup database ${db_name}..."
        if mariadb-dump --routines --triggers "${db_name}" 2>/dev/null | gzip -9 > "${backup_dir}/${db_name}.sql.gz"; then
            msg "$ICON_CHECK Backup database thanh cong" 'green'
        else
            msg "$ICON_WARNING Backup database that bai — chi backup source"
        fi
    fi

    # Hien thi ket qua
    local source_size db_size
    source_size=$(du -sh "${backup_dir}/${domain}.tar.gz" 2>/dev/null | cut -f1)
    db_size=$(du -sh "${backup_dir}/${db_name}.sql.gz" 2>/dev/null | cut -f1)

    echo ""
    msg "$ICON_CHECK Backup website ${domain} thanh cong!" 'green'
    echo "${GREEN}-----------------------------------${NC}"
    echo "${GREEN}Thu muc backup  :${NC} ${RED}${backup_dir}${NC}"
    echo "${GREEN}Source          :${NC} ${RED}${domain}.tar.gz${NC} ${GREEN}(${source_size})${NC}"
    if [[ -n "$db_name" && -f "${backup_dir}/${db_name}.sql.gz" ]]; then
        echo "${GREEN}Database        :${NC} ${RED}${db_name}.sql.gz${NC} ${GREEN}(${db_size})${NC}"
    fi
    echo "${GREEN}-----------------------------------${NC}"

    press_enter_to_continue; return 0
}
