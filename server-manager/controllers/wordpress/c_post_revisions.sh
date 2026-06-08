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

if ! declare -f prompt_select_website >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/prompt.sh"
fi

delete_wp_post_revisions () {
    local domain
    local base_dir
    local backup='y'
    local backup_folder
    local db_name

    run_prompt_or_exit prompt_select_website domain "wordpress_menu" "$WEB_DATA_DIR" 'd' 'wordpress'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    if ! prompt_yes_no "Ban muon co muon backup database khong ?"; then
        backup='n'
    fi

    if [ "$backup" == 'y' ]; then
        msg "$ICON_TOOL Dang backup database cua domain: ${domain}"
        backup_folder="${BACKUP_DIR}/${domain}/$(current_date)"
        mkdir -p "$backup_folder"
        export_database --db_name "${db_name}" --backup_dir "${backup_folder}" --compress
    fi

    cd_dir "${base_dir}/public_html"

    wp revisions clean -1 --allow-root
    msg "$ICON_SUCCESS Da xoa toan bo revisions cua WordPress tren domain: ${domain}"
    wordpress_menu
}
