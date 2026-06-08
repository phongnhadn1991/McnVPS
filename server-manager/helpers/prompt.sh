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

if ! declare -f is_wordpress >/dev/null 2>&1; then
    source "${MENU_DIR}/validate/rule.sh"
fi

_wrap_prompt() {
    "$@" && return 0 || return 1
}

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

prompt_select_core() {
    local title=""
    local items_name=""
    local use_slug=false
    local page_size=20
    local cols=3
    local col_width='auto'
    local paginate=true
    local filtered_items_name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)        title="$2"; shift 2 ;;
            --items)        items_name="$2"; shift 2 ;;
            --filtered)     filtered_items_name="$2"; shift 2 ;;
            --use_slug)     use_slug=true; shift ;;
            --page_size)    page_size="$2"; shift 2 ;;
            --cols)         cols="$2"; shift 2 ;;
            --col_width)    col_width="$2"; shift 2 ;;
            --paginate)     paginate=true; shift ;;
            --no-paginate)  paginate=false; shift ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    local -n items="${filtered_items_name:-$items_name}"
    if [[ ${#items[@]} -eq 0 ]]; then
        ERR_REPLY="📭 Danh sach rong."
        return 1
    fi

    if [[ "$col_width" == "auto" || -z "$col_width" ]]; then
        get_max_item_width --array items --padding 2
        col_width="${MAX_ITEM_WIDTH_REPLY:-35}"
    fi

    local total=${#items[@]}
    local page=0
    local total_pages=$(( (total + page_size - 1) / page_size ))

    while true; do
        clear
        msg "📋 $title" 'green'
        [[ "$paginate" == true ]] && msg "(Trang $((page+1))/$total_pages)" 'green'
        echo

        local start end
        if [[ "$paginate" == true ]]; then
            start=$((page * page_size))
            end=$((start + page_size))
            (( end > total )) && end=$total
        else
            start=0
            end=$total
        fi

        local rows=$(( (end - start + cols - 1) / cols ))

        for ((r=0; r<rows; r++)); do
            local line=""
            for ((c=0; c<cols; c++)); do
                local idx=$((start + r + rows * c))
                if (( idx < end )); then
                    local number=$((idx+1))
                    local label="${items[idx]}"
                    printf -v item "%2d) %-*s" "$number" "$col_width" "$label"
                    line+="$item"
                fi
            done
            echo "$line"
        done

        echo
        [[ "$paginate" == true ]] && msg "n) Trang sau | p) Trang truoc" 'green'
        msg "0) Thoat"
        read -rp "${GREEN}Nhap lua chon:${NC} " input


        case "$input" in
            0|q) ERR_REPLY='Huy thao tac'; return 1 ;;
            n) [[ "$paginate" == true && $page -lt $((total_pages - 1)) ]] && ((page++)) ;;
            p) [[ "$paginate" == true && $page -gt 0 ]] && ((page--)) ;;
            ''|*[!0-9]*) msg "$ICON_EXIT Lua chon khong hop le."; sleep 1 ;;
            *)
                if (( input >= 1 && input <= total )); then
                    local value="${items[$((input - 1))]}"
                    REPLY="$value"
                    $use_slug && REPLY=$(echo "$REPLY" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+/-/g' | sed -E 's/[^a-z0-9\-]//g')
                    return 0
                else
                    msg "$ICON_EXIT Lua chon khong hop le."; sleep 1
                fi
                ;;
        esac
    done
}

prompt_select_item() {
    local items_name=""
    local search_target=""
    local title=""
    local page_size=10
    local cols=1
    local col_width='auto'
    local prompt_text="${GREEN}${ICON_SEARCH} Nhap tu khoa de tim kiem${NC}"
    local use_slug=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)         title="$2"; shift 2 ;;
            --items)         items_name="$2"; shift 2 ;;
            --search_target) search_target="$2"; shift 2 ;;
            --page_size)     page_size="$2"; shift 2 ;;
            --cols)          cols="$2"; shift 2 ;;
            --col_width)     col_width="$2"; shift 2 ;;
            --prompt_text)   prompt_text="${2:-$prompt_text}"; shift 2 ;;
            --use_slug)      use_slug=true; shift ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$items_name" || -z "$title" ]]; then
        msg "$ICON_EXIT Thieu --title hoac --items"
        return 1
    fi

    local -n _items="$items_name"
    if [[ ${#_items[@]} -eq 0 ]]; then
        ERR_REPLY="$ICON_WARNING Khong co du lieu trong danh sach $search_target."
        return 1
    fi

    local filtered=()
    local keyword=""

    [[ -n "$search_target" ]] && prompt_text+=" ${GREEN}$search_target${NC}"
    prompt_text+=" ${RED}(Nhan Enter de hien thi tat ca)${NC}: "

    while true; do
        read -rp "$prompt_text" keyword
        filtered=()

        for item in "${_items[@]}"; do
            [[ -z "$keyword" || "$item" == *"$keyword"* ]] && filtered+=("$item")
        done

        if [[ ${#filtered[@]} -eq 0 ]]; then
            msg "$ICON_WARNING Khong tim thay ket qua voi tu khoa '$keyword'" "yellow"
            continue
        fi

        local use_slug_option=''
        if [ "$use_slug" == 'true' ]; then
            use_slug_option='--use_slug'
        fi

        prompt_select_core \
            --title "$title" \
            --items "$items_name" \
            --filtered filtered \
            --page_size "$page_size" \
            --cols "$cols" \
            --col_width "$col_width" \
            $use_slug_option

        return $?
    done
}

prompt_select_static_list() {
    prompt_select_core "$@"
}

prompt_input_with_check() {
    local prompt=""
    local validate_func=""
    local check_exists_func=""
    local default_value=""
    local allow_empty=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prompt)            prompt="$2"; shift 2 ;;
            --validate_func)     validate_func="$2"; shift 2 ;;
            --check_exists_func) check_exists_func="$2"; shift 2 ;;
            --default)           default_value="$2"; shift 2 ;;
            --allow_empty)       allow_empty=true; shift ;;
            *)
                echo "$ICON_EXIT Tham so khong hop le: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$prompt" ]]; then
        echo "$ICON_EXIT Thieu --prompt"
        return 1
    fi

    local input
    while true; do
        read -rp "$prompt ${RED}[0 de thoat]${NC}: " input
        input=$(trim "$input")

        [[ "$input" == "0" ]] && return 1

        if [[ -z "$input" ]]; then
            if [[ -n "$default_value" ]]; then
                REPLY="$default_value"
                return 0
            elif [[ "$allow_empty" != true ]]; then
                msg "$ICON_EXIT Khong duoc de trong."
                continue
            fi
        fi

        if [[ -n "$validate_func" ]]; then
            if ! "$validate_func" "$input"; then
                msg "$ICON_EXIT Du lieu khong hop le."
                continue
            fi
        fi

        if [[ -n "$check_exists_func" ]]; then
            if "$check_exists_func" "$input"; then
                msg "$ICON_EXIT '$input' da ton tai."
                continue
            fi
        fi

        REPLY="$input"
        return 0
    done
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
    local without_www="${1:-true}"
    local need_check_exist="${2:-true}"

    local prompt_extra='(khong co www)'
    if [ "$without_www" != 'true' ]; then
        prompt_extra=''
    fi

    local check_exists_option=""
    if [ "$need_check_exist" == 'true' ]; then
        check_exists_option="--check_exists_func is_domain_exists"
    fi

    while true; do
        # shellcheck disable=SC2086
        prompt_input_with_check --prompt "Nhap ten mien ${prompt_extra}" --validate_func is_valid_domain $check_exists_option

        # shellcheck disable=SC2181
        if [[ $? -ne 0 ]]; then
            REPLY="0"
            return 1
        fi

        if [ "$without_www" == 'true' ]; then
            REPLY=$(clean_domain "$REPLY")
        else
            REPLY=$(clean_domain "$REPLY" 'false')
        fi

        return 0
    done
}

prompt_mysql_user_input() {
    local need_check_exist="${1:-true}"

    if [ "$need_check_exist" == true ]; then
        prompt_input_with_check --prompt "Nhap Mysql user" --validate_func is_valid_username \
                --check_exists_func is_mysql_user_exists
    else
        prompt_input_with_check --prompt "Nhap Mysql user" --validate_func is_valid_username
    fi
}

prompt_mysql_db_input() {
    local need_check_exist="${1:-true}"

    if [ "$need_check_exist" == true ]; then
        prompt_input_with_check --prompt "Nhap ten database" --validate_func is_valid_username \
                --check_exists_func is_db_exists
    else
        prompt_input_with_check --prompt "Nhap ten database" --validate_func is_valid_username
    fi
}

prompt_mysql_password_input() {
    prompt_input_with_check --prompt "Nhap mat khau MySQL"
}

prompt_input_remote_name() {
    echo "Ten ket noi khong chua ky tu dac biet va dai 5 ky tu tro len."
    prompt_input_with_check --prompt "Nhap ten ket noi ban muon tao" --validate_func is_valid_username
}

prompt_backup_num_input() {
    echo "Nhap so ban backup ban muon luu tru: "
    echo "VD: Nhap 14 - Se luu backup 14 ngay gan nhat - Cac ban cu hon se bi xoa"
    prompt_input_with_check --prompt "Nhap vao lua chon cua ban" --validate_func is_number
}

prompt_ssh_username_input() {
    prompt_input_with_check --prompt "Nhap SSH username" --validate_func is_valid_username
}

prompt_ssh_password_input() {
    prompt_input_with_check --prompt "Nhap password SSH"
}

prompt_ssh_port_input() {
    prompt_input_with_check --prompt "Nhap SSH port" --validate_func is_number
}

prompt_ssh_host_input() {
    prompt_input_with_check --prompt "Nhap dia chi IP" --validate_func valid_ip
}

prompt_wp_admin_user() {
    while true; do
        prompt_input_with_check --prompt "Nhap Username WP-Admin" --validate_func is_valid_username
        # shellcheck disable=SC2181
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        if [[ "$REPLY" =~ ^(admin|administrator|root|hostvn)$ ]]; then
            msg "$ICON_EXIT Username '$REPLY' khong an toan. Vui long chon ten khac."
        else
            return 0
        fi
    done
}

prompt_wp_admin_email() {
    prompt_input_with_check --prompt "Nhap Email quan tri" --validate_func is_valid_email
}

prompt_wp_site_name() {
    prompt_input_with_check --prompt "Nhap ten website" --default "Just another WordPress site" --allow_empty
}

prompt_telegram_token_input() {
    prompt_input_with_check --prompt "Nhap token bot telegram"
}

prompt_telegram_chat_id_input() {
    prompt_input_with_check --prompt "Nhap chat ID"
}

prompt_fw_port_input() {
    prompt_input_with_check --prompt "Nhap port (Phan tach bang dau phay. VD: 22,80,443) [0 = Exit]" \
        --validate_func validate_port_list
}

prompt_fw_ip_input() {
    prompt_input_with_check --prompt "Nhap IP (Phan tach bang dau phay. VD: 1.2.3.4,5.6.7.8) [0 = Exit]" \
        --validate_func validate_ip_list
}

prompt_fw_php_param_value() {
    prompt_input_with_check --prompt "Nhap gia tri moi [Ex: 50] [0 = Exit]" \
        --validate_func is_number
}

prompt_select_fw_protocol() {
    # shellcheck disable=SC2034
    local protocols=( "tcp" "udp")
    prompt_select_static_list --title "Chon protocol" --items protocols --use_slug --cols 1 --no-paginate
}

prompt_select_laravel_version() {
    local version_list
    run_or_exit "" get_app_version "laravel_version"
    IFS=" " read -r -a version_list <<< "$APP_VERSION_REPLY"

    if [[ ${#version_list[@]} -eq 0 ]]; then
        ERR_REPLY="$ICON_EXIT Khong co phien ban Laravel nao kha dung."
        return 1
    fi

    prompt_select_static_list --title "📦 Chon phien ban Laravel ban muon cai dat" --items version_list --cols 1 --no-paginate
}

prompt_select_php_version() {
    local need_active="${1:-true}"
    local versions=()
    local php_base_dir="/etc/php"

    # shellcheck disable=SC2010
    for v in $(ls "$php_base_dir" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$'); do
        local svc="php${v}-fpm"
        [[ "$need_active" == "false" || "$(systemctl is-active "$svc" 2>/dev/null)" == "active" ]] && versions+=("$v")
    done

    [[ ${#versions[@]} -eq 0 ]] && ERR_REPLY="Khong co phien ban PHP kha dung" && return 1

    prompt_select_static_list --title "Chon phien ban PHP" --items versions --cols 1 --no-paginate
}

prompt_select_new_php_ver() {
    local version_response

    version_response=$(curl_get_with_retry --url "${GET_VERSION_LINK}") || {
        ERR_REPLY="$ICON_EXIT Khong the lay danh sach phien ban PHP."
        return 1
    }

    extract_key_value "${version_response}" "php_list" 'false'
    # shellcheck disable=SC2206
    local all_versions=(${KEY_VALUE_REPLY})

    local php_base_dir="/etc/php"
    local available_versions=()

    for version in "${all_versions[@]}"; do
        version="${version//php/}"
        local service="php${version}-fpm"

        if ! systemctl is-active --quiet "$service"; then
            available_versions+=("$version")
        fi
    done

    if [[ ${#available_versions[@]} -eq 0 ]]; then
        ERR_REPLY="👍 Ban da cai dat tat ca cac phien ban PHP duoc de xuat."
        return 1
    fi

    prompt_select_static_list --title "📦 Chon phien ban PHP muon cai dat" --items available_versions --cols 1 --no-paginate
}

prompt_select_website_source() {
    # shellcheck disable=SC2034
    local sources=( "WordPress" "Laravel" "CodeIgniter" "Yii 2" "CakePHP" "Magento 2" "Nextcloud" "Moodle" "Mautic" "Other" )
    prompt_select_static_list --title "Chon ma nguon website ban muon su dung" --items sources --use_slug --cols 1 --no-paginate
}

prompt_select_website() {
    local scan_dir="${1:-$WEB_DATA_DIR}"
    local scan_type="${2:-d}"
    local scan_source="${3:-none}"
    local -a domains=()

    if [[ ! -d "$scan_dir" ]]; then
        ERR_REPLY="Thu muc $scan_dir khong ton tai!"
        return 1
    fi

    case "$scan_type" in
        f)
            while IFS= read -r -d '' file; do
                local domain=""
                domain="$(basename -- "${file%.conf}")"

                if [ "$scan_source" == 'wordpress' ]; then
                    if ! is_wordpress "$domain"; then
                        continue
                    fi
                fi
                domains+=( "$domain" )
            done < <(find -L "$scan_dir" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)
            ;;
        d)
            while IFS= read -r -d '' dir; do
                local domain=""
                domain="$(basename -- "$dir")"

                if [ "$scan_source" == 'wordpress' ]; then
                    if ! is_wordpress "$domain"; then
                        continue
                    fi
                fi

                domains+=( "$domain" )
            done < <(find "$scan_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
            ;;
    esac

    if [[ ${#domains[@]} -eq 0 ]]; then
        ERR_REPLY="Khong tim thay website nao tren server"
        return 1
    fi

    prompt_select_item --title "$ICON_GLOBE Chon website ban muon thao tac" --items domains \
        --search_target 'website' --cols 3
}

prompt_select_mysql_user() {
    local users=()
    local all_mysql_users

    all_mysql_users=$(mariadb -N -e "SELECT DISTINCT User FROM mysql.user WHERE User NOT IN ('root', 'mysql', 'mariadb.sys', 'sqladmin');" 2>/dev/null)
    while IFS= read -r line; do users+=("$line"); done <<< "$all_mysql_users"

    prompt_select_item --title "Chon MySQL user" --items users --search_target 'MySQL user' --cols 3
}

prompt_select_mysql_database() {
    local dbs=()
    local all_dbs

    all_dbs=$(mariadb -N -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "^(mysql|performance_schema|information_schema|sys|phpmyadmin)$")
    while IFS= read -r line; do dbs+=("$line"); done <<< "$all_dbs"

    prompt_select_item --title "Chon Database" --items dbs --search_target 'database' --cols 3
}

prompt_select_wp_admin_user() {
    local domain="$1"
    local wp_path
    local -a admins_list=()

    if [[ -z "$domain" ]]; then
        ERR_REPLY="Domain is missing"
        return 1
    fi

    if [[ -z "$base_dir" ]]; then
        # shellcheck disable=SC1090
        source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
            ERR_REPLY="Khong the load file cau hinh: ${domain}"
            return 1
        }
    fi

    wp_path="${base_dir}/public_html"

    mapfile -t admins_list < <(
        wp --path="$wp_path" user list --role=administrator --fields=ID,user_login --format=csv --allow-root \
            | tail -n +2
    )

    if [[ ${#admins_list[@]} -eq 0 ]]; then
        ERR_REPLY="Khong tim thay admin nao."
        return 1
    fi

    printf "\n"
    msg "Danh sach admin users" 'green'
    PS3="${GREEN}$ICON_ARROW Nhap vào lua chon cua ban:${NC} "
    select admin in "${admins_list[@]}"; do
        if [[ -n "$admin" ]]; then
            local id login
            id=$(echo "$admin" | cut -d',' -f1)
            login=$(echo "$admin" | cut -d',' -f2)
            REPLY="${id}:${login}"
            return 0
        else
            msg "$ICON_EXIT Lua chon khong hop le, thu lai."
        fi
    done
}

prompt_select_wordpress_plugins() {
    local wp_dir="$1"

    if [[ -z "$wp_dir" || ! -d "${wp_dir}/public_html" ]]; then
        ERR_REPLY="WordPress directory is missing"
        return 1
    fi

    local -a wp_plugins=()

    mapfile -t wp_plugins < <(wp plugin list --field=name --status=active --path="${wp_dir}/public_html" --allow-root)

    if [[ ${#wp_plugins[@]} -eq 0 ]]; then
        ERR_REPLY="Khong co plugin nao duoc kich hoat tren website: ${domain}"
        return 1
    fi

    prompt_select_item --title "$ICON_GLOBE Chon website ban muon thao tac" --items wp_plugins \
        --search_target 'WP plugins' --cols 3
}

prompt_select_backup_scope() {
    # shellcheck disable=SC2034
    local scopes=( "drive" "sftp" "telegram" "local")
    prompt_select_static_list --title "Chon kieu backup ban muon su dung" --items scopes --cols 1 --no-paginate
}

prompt_select_ssh_auth_type() {
    # shellcheck disable=SC2034
    local scopes=( "password" "ssh-key")
    prompt_select_static_list --title "Chon loai xac thuc" --items scopes --cols 1 --no-paginate
}

prompt_select_php_param() {
    # shellcheck disable=SC2034
    local scopes=( 'memory_limit' 'max_execution_time' 'max_input_time' 'post_max_size' 'upload_max_filesize')
    prompt_select_static_list --title "Chon thong so PHP" --items scopes --cols 1 --no-paginate
}

prompt_select_backup() {
    local backup_scope="$1"
    local backup_path="$2"
    local title="${2:-"Chon ban backup ban muon khoi phuc"}"
    local prompt="${3:-"Chon ban backup ban muon khoi phuc"}"

    if [[ -z "$backup_path" || -z "$backup_scope" ]]; then
        ERR_REPLY="Missing remote path or scope"
        return 1
    fi

    local -a backup_dirs=()

    if [ "$backup_scope" == 'local' ]; then
        mapfile -t backup_dirs < <(
            find "$backup_path" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
            | grep -v '^orphaned-dbs$'
        )
    else
        mapfile -t backup_dirs < <(rclone lsf "$backup_path" | sed 's:/$::' | grep -v '^orphaned-dbs$')
    fi

    if [[ ${#backup_dirs[@]} -eq 0 ]]; then
        ERR_REPLY="Khong tim thay ban backup nao tren server"
        return 1
    fi

    prompt_select_item --title "$ICON_GLOBE $title" --items backup_dirs \
        --prompt_text "${prompt}" --cols 3
}

prompt_select_restore_type() {
    # shellcheck disable=SC2034
    local scopes=( 'source' 'database' 'all')
    prompt_select_static_list --title "Lua chon kieu khoi phuc du lieu" --items scopes --cols 1 --no-paginate
}

