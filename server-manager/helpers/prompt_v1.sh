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

run_prompt_or_exit() {
    local prompt_func="$1"
    local var_name="$2"
    local fallback_cmd="$3"
    shift 3

    if "$prompt_func" "$@"; then
        if [[ -n "$REPLY" ]]; then
            printf -v "$var_name" "%s" "$REPLY"
        else
            msg "$ICON_EXIT Gia tri tra ve tu $prompt_func bi rong."
            [[ -n "$fallback_cmd" ]] && eval "$fallback_cmd" || exit 1
        fi
    else
        local err="Da huy thao tac hoac loi khi thuc hien $prompt_func."
        if [ -n "$ERR_REPLY" ]; then
            err="$ERR_REPLY"
        fi

        msg "$ICON_EXIT $err"
        [[ -n "$fallback_cmd" ]] && eval "$fallback_cmd" || exit 1
    fi
}

prompt_yes_no() {
    local question="$1"
    while true; do
        read -rp "${BLUE}$question${NC} (y/n): " yn
        case "$yn" in
            y|Y|1) return 0 ;;
            n|N|0) return 1 ;;
            *) echo "${RED}Chi nhap y hoac n.${NC}" ;;
        esac
    done
}

prompt_domain_input() {
    local domain

    while true; do
        read -rp "Nhap ten mien (không co www, [0] de thoat): " domain
        [[ "$domain" == "0" ]] && REPLY="0" && return 1

        domain=$(clean_domain "$domain")

        if is_valid_domain "$domain"; then
            if is_domain_exists "$domain"; then
                msg "$ICON_EXIT Ten mien $domain da ton tai. Vui long nhap ten mien khac."
                continue
            fi

            REPLY="$domain"
            return 0
        else
            msg "$ICON_EXIT Ten mien khong hop le, vui long thu lai."
        fi
    done
}

prompt_mysql_user_input() {
    local mysql_user

    while true; do
        read -rp "Nhap user ban muon tao ([0] de thoat): " mysql_user
        [[ "$mysql_user" == "0" ]] && REPLY="0" && return 1

        mysql_user=$(trim "$mysql_user")

        if is_valid_username "$mysql_user"; then
            if is_mysql_user_exists "$mysql_user"; then
                msg "$ICON_EXIT User $mysql_user da ton tai. Vui long nhap user khac."
                continue
            fi

            REPLY="$mysql_user"
            return 0
        else
            msg "$ICON_EXIT User khong hop le, vui long nhap lai."
        fi
    done
}

prompt_mysql_db_input() {
    local mysql_db_name

    while true; do
        read -rp "Nhap ten database ban muon tao ([0] de thoat): " mysql_db_name
        [[ "$mysql_db_name" == "0" ]] && REPLY="0" && return 1

        mysql_db_name=$(trim "$mysql_db_name")

        if is_valid_username "$mysql_db_name"; then
            if is_db_exists "$mysql_db_name"; then
                msg "$ICON_EXIT Database $mysql_db_name da ton tai. Vui long nhap user khac."
                continue
            fi

            REPLY="$mysql_db_name"
            return 0
        else
            msg "$ICON_EXIT Database name khong hop le, vui long nhap lai."
        fi
    done
}

prompt_select_php_version() {
    local need_active="${1:-true}"
    local php_versions=()
    local php_base_dir="/etc/php"

    # shellcheck disable=SC2010
    for version in $(ls "$php_base_dir" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$'); do
        local service="php${version}-fpm"

        if [ "$need_active" == 'true' ]; then
            if systemctl is-active --quiet "$service"; then
                php_versions+=("$version")
            fi
        else
            php_versions+=("$version")
        fi
    done

    if [[ ${#php_versions[@]} -eq 0 ]]; then
        # shellcheck disable=SC2034
        ERR_REPLY="Khong tim thay phien ban PHP nao dang chay hoac co socket hoat dong."
        return 1
    fi

    echo "${BLUE}Chon phien ban PHP:${NC}"

    for i in "${!php_versions[@]}"; do
        echo "$((i+1))) ${php_versions[$i]}"
    done
    echo "${RED}0) Huy thao tac${NC}"

    while true; do
        read -rp "Nhap lua chon cua ban (0-${#php_versions[@]}): " selection
        if [[ "$selection" == "0" ]]; then
            msg "Huy thao tac."
            return 1
        elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#php_versions[@]} )); then
            REPLY="${php_versions[$((selection-1))]}"
            return 0
        else
            msg "$ICON_EXIT Lua chon khong hop le. Vui long nhap lai."
        fi
    done
}

prompt_select_new_php_ver() {
    local version_response

    version_response=$(curl_get_with_retry --url "${GET_VERSION_LINK}") || {
        msg "$ICON_EXIT Da xay ra loi khi lay danh sach phien ban PHP"
        return 1
    }

    # shellcheck disable=SC2207
    extract_key_value "${version_response}" "php_list" 'false'
    # shellcheck disable=SC2206
    local all_versions=(${KEY_VALUE_REPLY})

    local php_base_dir="/etc/php"
    local available_versions=()

    for version in "${all_versions[@]}"; do
        version=${version//php/}
        local service="php${version}-fpm"

        if ! systemctl is-active --quiet "$service"; then
            available_versions+=("$version")
        fi
    done

    if [[ ${#available_versions[@]} -eq 0 ]]; then
        msg "👍 Ban da cai dat tat ca cac phien ban PHP." 'blue'
        exit 1
    fi

    msg "📦 Chon phien ban PHP muon cai dat tu danh sach:"
    for i in "${!available_versions[@]}"; do
        echo "$((i + 1))) ${available_versions[$i]}"
    done

    echo "${RED}0) Huy thao tac${NC}"

    while true; do
        read -rp "Nhap lua chon cua ban (0-${#available_versions[@]}): " selection
        if [[ "$selection" == "0" ]]; then
            msg "$ICON_EXIT Da chon huy thao tac."
            exit 1
        elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#available_versions[@]} )); then
            REPLY="${available_versions[$((selection - 1))]}"
            return 0
        else
            msg "$ICON_EXIT Lua chon khong hop le. Vui long thu lai."
        fi
    done
}

prompt_select_website_source() {
    local sources=( "WordPress" "Laravel" "CodeIgniter" "Nodejs" "WHMCS" "Yii" "CakePHP" "CS-Cart"
        "Magento 2" "Nextcloud" "Moodle" "Mautic" "Other" )

    msg "Chon ma nguon website ban muon su dung:" "green"

    for i in "${!sources[@]}"; do
        echo "$((i+1))) ${sources[$i]}"
    done
    echo "${RED}0) Huy thao tac${NC}"

    while true; do
        read -rp "Nhap lua chon cua ban (0-${#sources[@]}): " selection

        if [[ "$selection" == "0" ]]; then
            msg "Da chon thoat."
            return 1
        elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#sources[@]} )); then
            local slug
            slug=$(echo "${sources[$((selection-1))]}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+/-/g' | sed -E 's/[^a-z0-9\-]//g')
            REPLY="$slug"
            return 0
        else
            msg "$ICON_EXIT Lua chon khong hop le. Vui long nhap lai."
        fi
    done
}

prompt_wp_admin_user() {
    local input=""
    while true; do
        read -rp "Nhap Username WP-Admin (nhap 0 de thoat): " input
        echo

        if [[ "$input" == "0" ]]; then
            return 1
        fi

        if [[ "$input" == "admin" || "$input" == "administrator" || "$input" == "root" ]]; then
            msg "$ICON_EXIT Username 'admin' khong an toan. Vui long chon ten khac."
        elif is_valid_username "$input"; then
            REPLY="$input"
            return 0
        else
            msg "$ICON_EXIT Username WP-Admin khong duoc chua ky tu dac biet va phai dai it nhat 5 ky tu. Vui long thu lai."
        fi
    done
}

prompt_wp_admin_email() {
    local input=""
    while true; do
        read -rp "Nhap Email quan tri (nhap 0 de thoat): " input
        echo

        if [[ "$input" == "0" ]]; then
            return 1
        fi

        if is_valid_email "$input"; then
            REPLY="$input"
            return 0
        else
            msg "$ICON_EXIT Email khong dung dinh dang. Vui long thu lai."
        fi
    done
}

prompt_wp_site_name() {
    local input=""
    read -rp "Nhap ten website (nhap 0 de thoat): " input

    if [[ "$input" == "0" ]]; then
        return 1
    fi

    if [[ -z "$input" ]]; then
        REPLY="Just another WordPress site"
    else
        REPLY="$input"
    fi
    return 0
}

prompt_select_laravel_version() {
    local options
    run_or_exit "" get_app_version "laravel_version"
    IFS=" " read -r -a options <<< "$APP_VERSION_REPLY"

    echo "${BLUE}Chon phien ban Laravel ban muon cai dat:${NC}"

    for i in "${!options[@]}"; do
        echo "$((i+1))) ${options[$i]}"
    done

    echo "${RED}0) Huy thao tac ${NC}"

    while true; do
        read -rp "Nhap lua chon cua ban (0-${#options[@]}): " selection

        if [[ "$selection" == "0" ]]; then
            return 1
        elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#options[@]} )); then
            REPLY="${options[$((selection-1))]}"
            return 0
        else
            msg "$ICON_EXIT Lua chon khong hop le. Vui long nhap lai."
        fi
    done
}

prompt_select_website() {
    local websites_dir="/var/mcnvps/data/websites"
    local -a domains=()

    if [[ ! -d "$websites_dir" ]]; then
        msg "$ICON_EXIT Thu muc $websites_dir khong ton tai!"
        exit 1
    fi

    while IFS= read -r -d '' dir; do
        domains+=( "$(basename "$dir")" )
    done < <(find "$websites_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    if [[ ${#domains[@]} -eq 0 ]]; then
        msg "$ICON_EXIT Khong tim thay website nao"
        exit 1
    fi

    msg "$ICON_GLOBE Danh sach website co san:"
    for i in "${!domains[@]}"; do
        echo "$((i+1))) ${domains[$i]}"
    done
    echo "${RED}0) Huy thao tac${NC}"

    while true; do
        read -rp "Nhap lua chon cua ban (0-${#domains[@]}): " selection

        if [[ "$selection" == "0" ]]; then
            msg "$ICON_BLOCK Da chon thoat."
            exit 1
        elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#domains[@]} )); then
            REPLY="${domains[$((selection - 1))]}"
            return 0
        else
            msg "$ICON_EXIT Lua chon khong hop le. Vui long nhap lai."
        fi
    done
}

prompt_mysql_user_filtered_paginated() {
    local users=()
    if [[ -z "$all_mysql_users" ]]; then
        all_mysql_users=$(mariadb -N -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'mysql', 'mariadb.sys', 'sqladmin');" 2>/dev/null)
    fi
    while IFS= read -r line; do
        users+=("$line")
    done <<< "$all_mysql_users"

    if [[ ${#users[@]} -eq 0 ]]; then
        msg "Khong tim thay User MySQL hop le." "red"
        return 1
    fi

    local filtered=("${users[@]}")
    local page_size=10
    local page=0

    while true; do
        local keyword
        read -rp "Nhap tu khoa de loc user (Bam Enter de hien thi tat ca): " keyword

        filtered=()
        for u in "${users[@]}"; do
            if [[ -z "$keyword" || "$u" == *"$keyword"* ]]; then
                filtered+=("$u")
            fi
        done

        if [[ ${#filtered[@]} -eq 0 ]]; then
            msg "$ICON_WARNING Khong tim thay user nao khop voi tu khoa '$keyword'." "yellow"
            continue
        fi

        page=0
        while true; do
            clear
            local total=${#filtered[@]}
            local total_pages=$(( (total + page_size - 1) / page_size ))
            msg "Chon MySQL user (Trang $((page+1))/$total_pages):" "green"
            echo

            for ((i=page*page_size; i< (page+1)*page_size && i<total; i++)); do
                printf "%2d) %s\n" $((i+1)) "${filtered[i]}"
            done

            echo
            echo "n) Trang ke tiep | p) Trang truoc | r) Loc lai | 0) Huy thao tac"
            read -rp "Nhap so de chon database: " input

            case "$input" in
                n)
                    if (( (page+1)*page_size < total )); then ((page++)); else msg "$ICON_BLOCK Khong co trang tiep theo." "yellow"; sleep 1; fi
                    ;;
                p)
                    if (( page > 0 )); then ((page--)); else msg "$ICON_BLOCK Dang o trang dau tien." "yellow"; sleep 1; fi
                    ;;
                r)
                    break
                    ;;
                0)
                    msg "Da chon thoat."
                    return 1
                    ;;
                ''|*[!0-9]*) msg "$ICON_EXIT Lua chon khong hop le."; sleep 1 ;;
                *)
                    if (( input >= 1 && input <= total )); then
                        REPLY="${filtered[$((input-1))]}"
                        return 0
                    else
                        msg "$ICON_EXIT Lua chon khong hop le."; sleep 1
                    fi
                    ;;
            esac
        done
    done
}

prompt_mysql_database_filtered_paginated() {
    local users=()

    if [[ -z "$all_mysql_users" ]]; then
        all_dbs=$(mariadb -N -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "^(mysql|performance_schema|information_schema|sys|phpmyadmin)$")
    fi

    while IFS= read -r line; do
        users+=("$line")
    done <<< "$all_dbs"

    if [[ ${#users[@]} -eq 0 ]]; then
        msg "Khong tim thay MySQL Database hop le." "red"
        return 1
    fi

    local filtered=("${users[@]}")
    local page_size=10
    local page=0

    while true; do
        local keyword
        read -rp "Nhap tu khoa de loc database (Bam Enter de hien thi tat ca): " keyword

        filtered=()
        for u in "${users[@]}"; do
            if [[ -z "$keyword" || "$u" == *"$keyword"* ]]; then
                filtered+=("$u")
            fi
        done

        if [[ ${#filtered[@]} -eq 0 ]]; then
            msg "$ICON_WARNING Khong tim thay database nao khop voi tu khoa '$keyword'." "yellow"
            continue
        fi

        page=0
        while true; do
            clear
            local total=${#filtered[@]}
            local total_pages=$(( (total + page_size - 1) / page_size ))
            msg "Chon database (Trang $((page+1))/$total_pages):" "green"
            echo

            for ((i=page*page_size; i< (page+1)*page_size && i<total; i++)); do
                printf "%2d) %s\n" $((i+1)) "${filtered[i]}"
            done

            echo
            echo "n) Trang ke tiep | p) Trang truoc | r) Loc lai | 0) Huy thao tac"
            read -rp "Nhap so de chon database: " input

            case "$input" in
                n)
                    if (( (page+1)*page_size < total )); then ((page++)); else msg "$ICON_BLOCK Khong co trang tiep theo." "yellow"; sleep 1; fi
                    ;;
                p)
                    if (( page > 0 )); then ((page--)); else msg "$ICON_BLOCK Dang o trang dau tien." "yellow"; sleep 1; fi
                    ;;
                r)
                    break
                    ;;
                0)
                    msg "Da chon thoat."
                    return 1
                    ;;
                ''|*[!0-9]*) msg "❌$ICON_EXIT Lua chon khong hop le."; sleep 1 ;;
                *)
                    if (( input >= 1 && input <= total )); then
                        REPLY="${filtered[$((input-1))]}"
                        return 0
                    else
                        msg "$ICON_EXIT Lua chon khong hop le."; sleep 1
                    fi
                    ;;
            esac
        done
    done
}
