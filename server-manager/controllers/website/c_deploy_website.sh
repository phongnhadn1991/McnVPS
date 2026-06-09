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

deploy_website() {
    clear_screen
    local domain base_dir db_name db_user db_pass owner owner_folder php_version website_source

    echo "${GREEN}========== DEPLOY WEBSITE ==========${NC}"
    echo ""
    echo "Huong dan:"
    echo " 1. Upload 2 file vao public_html cua domain qua SFTP:"
    echo "    ${BLUE}source.tar.gz${NC}   — file backup source code"
    echo "    ${BLUE}database.sql.gz${NC} — file backup database (co the la .sql)"
    echo " 2. Chon domain muon deploy"
    echo " 3. Script tu dong giai nen, import DB, cap nhat cau hinh"
    echo ""
    echo "${RED}----------------------------------${NC}"

    msg "$ICON_GLOBE Chon Website muon deploy"
    run_prompt_or_exit prompt_select_website domain "website_menu"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    local public_html="${base_dir}/public_html"

    # Tim file source backup trong public_html
    local source_file=""
    for f in "${public_html}"/*.tar.gz "${public_html}"/*.zip; do
        [[ -f "$f" ]] && source_file="$f" && break
    done

    # Tim file database backup trong public_html
    local db_file=""
    for f in "${public_html}"/*.sql.gz "${public_html}"/*.sql; do
        [[ -f "$f" ]] && db_file="$f" && break
    done

    if [[ -z "$source_file" && -z "$db_file" ]]; then
        msg "$ICON_EXIT Khong tim thay file backup nao trong ${public_html}"
        echo "Vui long upload file .tar.gz (source) va .sql.gz hoac .sql (database) vao thu muc tren qua SFTP"
        press_enter_to_continue; return 0
    fi

    echo ""
    echo "${GREEN}Tim thay file backup:${NC}"
    [[ -n "$source_file" ]] && echo "  Source   : ${BLUE}$(basename "$source_file")${NC} ($(du -sh "$source_file" | cut -f1))"
    [[ -n "$db_file" ]]     && echo "  Database : ${BLUE}$(basename "$db_file")${NC} ($(du -sh "$db_file" | cut -f1))"
    echo ""

    if ! prompt_yes_no "${RED}Bat dau deploy website ${domain}? Du lieu hien tai se bi ghi de!${NC}"; then
        msg "$ICON_EXIT Huy deploy"
        press_enter_to_continue; return 0
    fi

    # Deploy source
    if [[ -n "$source_file" ]]; then
        msg "$ICON_TOOL Dang giai nen source code..."
        rm -rf "${public_html:?}/"
        mkdir -p "$public_html"

        if [[ "$source_file" == *.tar.gz ]]; then
            # Thu giai nen truc tiep vao public_html
            if tar -xzf "$source_file" -C "$public_html" --strip-components=1 2>/dev/null; then
                : # thanh cong strip-components
            elif tar -xzf "$source_file" -C "${base_dir}/" 2>/dev/null; then
                : # thanh cong giai nen vao base_dir (cau truc co public_html ben trong)
            else
                msg "$ICON_EXIT Giai nen source that bai"
                press_enter_to_continue; return 0
            fi
        elif [[ "$source_file" == *.zip ]]; then
            if ! unzip -q "$source_file" -d "$public_html" 2>/dev/null; then
                msg "$ICON_EXIT Giai nen source that bai"
                press_enter_to_continue; return 0
            fi
        fi

        # Xoa file backup source khoi public_html sau khi giai nen
        rm -f "$source_file"
        msg "$ICON_CHECK Giai nen source thanh cong" 'green'
    fi

    # Cap nhat wp-config.php neu la WordPress
    local wp_config="${public_html}/wp-config.php"
    local old_domain=""
    if [[ -f "$wp_config" && -n "$db_name" && -n "$db_user" && -n "$db_pass" ]]; then
        msg "$ICON_TOOL Dang cap nhat wp-config.php..."
        # Doc domain cu truoc khi import DB
        old_domain=$(wp --path="$public_html" --allow-root option get siteurl 2>/dev/null \
            | sed 's|https\?://||' | sed 's|/.*||')
        wp --path="$public_html" --allow-root config set DB_NAME "$db_name" 2>/dev/null
        wp --path="$public_html" --allow-root config set DB_USER "$db_user" 2>/dev/null
        wp --path="$public_html" --allow-root config set DB_PASSWORD "$db_pass" 2>/dev/null
        msg "$ICON_CHECK Cap nhat wp-config.php thanh cong" 'green'
    fi

    # Deploy database
    if [[ -n "$db_file" && -n "$db_name" ]]; then
        if ! is_db_exists "$db_name"; then
            msg "$ICON_EXIT Database ${db_name} khong ton tai"
            press_enter_to_continue; return 0
        fi

        msg "$ICON_TOOL Dang import database ${db_name}..."
        local import_ok=false
        if [[ "$db_file" == *.sql.gz ]]; then
            gunzip < "$db_file" | mariadb "$db_name" 2>/dev/null && import_ok=true
        elif [[ "$db_file" == *.sql ]]; then
            mariadb "$db_name" < "$db_file" 2>/dev/null && import_ok=true
        fi

        if [[ "$import_ok" == true ]]; then
            msg "$ICON_CHECK Import database thanh cong" 'green'
            # Xoa file backup DB sau khi import
            rm -f "$db_file"
        else
            msg "$ICON_EXIT Import database that bai"
            press_enter_to_continue; return 0
        fi

        # Xu ly domain neu la WordPress
        if [[ -f "$wp_config" ]]; then
            # Doc lai domain cu tu DB vua import neu chua co
            if [[ -z "$old_domain" ]]; then
                old_domain=$(wp --path="$public_html" --allow-root option get siteurl 2>/dev/null \
                    | sed 's|https\?://||' | sed 's|/.*||')
            fi

            if [[ -n "$old_domain" && "$old_domain" != "$domain" ]]; then
                msg "$ICON_TOOL Dang replace URL tu ${old_domain} sang ${domain}..."
                wp --path="$public_html" --allow-root \
                    search-replace "https://${old_domain}" "https://${domain}" --all-tables 2>/dev/null
                wp --path="$public_html" --allow-root \
                    search-replace "http://${old_domain}" "https://${domain}" --all-tables 2>/dev/null
                msg "$ICON_CHECK Replace URL thanh cong" 'green'
            else
                wp --path="$public_html" --allow-root option update siteurl "https://${domain}" 2>/dev/null
                wp --path="$public_html" --allow-root option update home "https://${domain}" 2>/dev/null
            fi
        fi
    fi

    # Fix permissions
    set_site_dir_permission --owner "$owner" --owner_folder "$owner_folder" --domain "$domain"

    echo ""
    msg "$ICON_CHECK Deploy website ${domain} thanh cong!" 'green'
    echo "${GREEN}-----------------------------------${NC}"
    echo "${GREEN}Website  :${NC} ${RED}https://${domain}${NC}"
    echo "${GREEN}Web Dir  :${NC} ${RED}${public_html}${NC}"
    if [[ -n "$db_name" ]]; then
        echo "${GREEN}Database :${NC} ${RED}${db_name}${NC}"
    fi
    echo "${GREEN}-----------------------------------${NC}"

    press_enter_to_continue; return 0
}
