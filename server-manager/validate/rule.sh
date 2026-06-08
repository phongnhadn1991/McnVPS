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

is_domain_exists() {
    local domain="$1"
    if [[ -e "${WEB_DATA_DIR}/${domain}.conf" || -e "${SITE_AVAILABLE_DIR}/${domain}.conf" ]]; then
        return 0
    fi

    return 1
}

is_db_exists(){
    local db_name="$1"
    local result
    result=$(/usr/bin/mariadb-show "${db_name}" | grep -v Wildcard | grep -o "${db_name}")

    if [ "$result" == "${db_name}" ]; then
        return 0
    else
        return 1
    fi
}

is_empty_db() {
    local db_name="$1"
    local tables_count
    tables_count=$(mariadb-show "$db_name" | grep -v -e 'Tables' -e '+--' -e 'Database:' | grep -c .)

    if [[ "$tables_count" == '0' ]]; then
        return 0
    fi

    return 1
}

is_mysql_user_exists(){
    local db_user="$1"
    RESULT_MYSQL_USER="$(mariadb -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '${db_user}')")"

    if [ "${RESULT_MYSQL_USER}" == 1 ]; then
        return 0
    else
        return 1
    fi
}

has_db_privileges() {
    local mysql_user=''
    local mysql_db=''

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mysql_user) mysql_user="$2"; shift 2 ;;
            --mysql_db)   mysql_db="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    local hosts=("localhost" "127.0.0.1")

    for host in "${hosts[@]}"; do
        local grants
        grants=$(mariadb -e "SHOW GRANTS FOR '${mysql_user}'@'${host}';" 2>/dev/null)

        if [[ -z "$grants" ]]; then
            return 1
        fi

        if ! echo "$grants" | grep -qE "GRANT (ALL PRIVILEGES|CREATE|DROP|ALTER).* ON \`${mysql_db}\`\.\*" \
           && ! echo "$grants" | grep -qE "GRANT ALL PRIVILEGES ON \*\.\*"; then
            return 1
        fi
    done

    return 0
}

check_mysql_password() {
    local user="$1"
    local password="$2"

    if mariadb -u"$user" -p"$password" -e "SELECT 1;" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

is_number(){
    local REGEX_NUMBER='^[0-9]+$'
    if [[ ${1} =~ ${REGEX_NUMBER} ]]; then
        return 0
    else
        return 1
    fi
}

is_valid_username(){
    local username="$1"
    local LEN=${#username}
    local USERNAME_TRAP

    USERNAME_TRAP=$(echo "${username}" | tr -d "_-" | tr -d "[:alnum:]")
    if [[ -z "${USERNAME_TRAP}" && ${LEN} -ge 4 ]] && ! is_number "$username"; then
        return 0
    else
        return 1
    fi
}

valid_ip() {
    local ip=$1

    if is_ipv4 "$ip" || is_ipv6 "$ip"; then
        return 0
    fi

    return 1
}

is_ipv4() {
    local ip="$1"

    ip="${ip#"${ip%%[![:space:]]*}"}"
    ip="${ip%"${ip##*[![:space:]]}"}"

    if [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})(/([0-9]{1,2}))?$ ]]; then
        for i in 1 2 3 4; do
            local octet="${BASH_REMATCH[$i]}"
            [[ -z "$octet" ]] && return 1
            if (( octet < 0 || octet > 255 )); then
                return 1
            fi
        done

        if [[ -n "${BASH_REMATCH[6]}" ]]; then
            local mask="${BASH_REMATCH[6]}"
            if (( mask < 0 || mask > 32 )); then
                return 1
            fi
        fi

        return 0
    fi

    return 1
}

is_ipv6() {
    local ip="$1"

    if [[ -z "$(which sipcalc)" ]]; then
        apt-get install sipcalc -y >/dev/null 2>&1
    fi

    if sipcalc "$ip" 2>/dev/null | grep -q "Expanded Address"; then
        return 0
    fi

    return 1
}

is_valid_domain() {
    local domain="$1"

    # https://data.iana.org/TLD/tlds-alpha-by-domain.txt
    # https://publicsuffix.org/list/public_suffix_list.dat
    #local tld_file="${SCRIPTS_DATA_DIR}/tld_list.txt"

    #if [[ ! -f "$tld_file" ]]; then
    #    msg "$ICON_EXIT Khong tim thay file danh sach TLD: $tld_file" "red"
    #    return 1
    #fi

    [[ -z "$domain" ]] && return 1

    [[ "$domain" =~ [[:space:]] ]] && return 1

    [[ "${domain:0:1}" == "-" ]] && return 1

    [[ "$domain" == *".."* ]] && return 1

    [[ "$domain" != *.* ]] && return 1
    [[ "$domain" =~ ^\. || "$domain" =~ \.$ ]] && return 1

    local part1="${domain%%.*}"
    local part2="${domain#*.}"
    [[ -z "$part1" || -z "$part2" ]] && return 1

    if [[ "$domain" =~ [^a-zA-Z0-9.-] ]]; then
        return 1
    fi

    #local tld="${domain##*.}"

    #if ! grep -iq "^${tld,,}$" "$tld_file"; then
    #    return 1
    #fi

    return 0
}

is_valid_email() {
    local email="$1"

    [[ -z "$email" ]] && return 1

    local user="${email%@*}"
    local domain="${email#*@}"

    if [[ "$email" == "$user" || -z "$user" || -z "$domain" ]]; then
        return 1
    fi

    if [[ ! "$user" =~ ^[a-zA-Z0-9._%+-]+$ ]]; then
        return 1
    fi

    is_valid_domain "$domain" || return 1

    return 0

    #[[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(\.[a-zA-Z]{2,})*$ ]]
}

is_wordpress() {
    local domain="$1"

    if ls /home/*/"$domain"/public_html/wp-load.php >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

is_linux_user_exists() {
    local user="$1"
    if id -u "$user" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_service_before_action() {
    local php_ver="$1"

    if ! test_nginx_config; then
        msg "$NGINX_T_REPLY"
        return 1
    fi

    if [[ "$(systemctl is-active nginx)" != 'active' ]]; then
        msg "$ICON_EXIT Nginx is not running"
        return 1
    fi

    if [[ "$(systemctl is-active mariadb)" != 'active' ]]; then
        msg "$ICON_EXIT MariaDB is not running"
        return 1
    fi

    if [[ -n "$php_ver" && "$(systemctl is-active php"${php_ver}"-fpm.service)" != 'active' ]]; then
        msg "$ICON_EXIT PHP php${php_ver}-fpm is not running"
        return 1
    fi

    return 0
}

check_http_status() {
    local domain="$1"
    local timeout="${2:-3}"

    if [ -z "${domain}" ]; then
        CHECK_HTTP_STATUS_REPLY="$ICON_EXIT Cannot check Website Status because Domain is missing"
        return 1
    fi

    local status_code response reason

    # shellcheck disable=SC2086
    status_code=$(curl -k -s --resolve $domain:443:127.0.0.1 -o /dev/null -w "%{http_code}" --max-time "$timeout" 'https://'$domain'')

    if [[ "$status_code" =~ ^[234][0-9][0-9]$ ]]; then
        return 0
    elif [[ "$status_code" == "500" ]]; then
        response=$(curl -k -s --resolve "$domain:443:127.0.0.1" --max-time "$timeout" "https://$domain")
        reason=$(echo "$response" | head -n 10)
        CHECK_HTTP_STATUS_REPLY="$ICON_EXIT Website ${domain} bao loi 500 Internal Server Error.
            Nguyen nhan:
            $reason"

        return 1
    else
        nginx -t
        # shellcheck disable=SC2034
        CHECK_HTTP_STATUS_REPLY="$ICON_EXIT Website ${domain} loi cau hinh (HTTP Status Code: $status_code)"
        return 1
    fi
}

is_domain_points_to_vps() {
    local domain="$1"
    local my_ips=()

    mapfile -t my_ips < <(ip -o addr show scope global | awk '{print $4}' | cut -d/ -f1)

    local domain_ips
    domain_ips=$(dig +short "$domain" A @8.8.8.8)

    if [[ -z "$domain_ips" ]]; then
        return 1
    fi

    local ip
    while IFS= read -r ip; do
        for my_ip in "${my_ips[@]}"; do
            if [[ "$ip" == "$my_ip" ]]; then
                return 0
            fi
        done
    done <<< "$domain_ips"

    return 1
}

is_php_version_in_use() {
    local php_version="$1"
    local pool_dir="/etc/php/${php_version}/fpm/pool.d"

    if [[ -d "$pool_dir" ]]; then
        local sites=()

        while IFS= read -r -d '' file; do
            domain=$(basename "$file" .conf)

            if [ ! -s "$file" ]; then
                continue
            fi

            if is_valid_domain "$domain"; then
                sites+=("$domain")
            fi
        done < <(find "$pool_dir" -maxdepth 1 -type f -name "*.conf" -print0)

        if [[ ${#sites[@]} -gt 0 ]]; then
            local site_list
            site_list=$(IFS=', '; echo "${sites[*]}")

            # shellcheck disable=SC2034
            PHP_IN_USER_REPLY="${site_list}"
            return 0
        fi
    fi

    return 1
}

validate_php_version_requirement() {
    local website_source=""
    local php_ver=''

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --website_source) website_source="$2"; shift 2 ;;
            --php_ver)        php_ver="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Loi khi kiem tra PHP Version Requirement: Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$website_source" || -z "$php_ver" ]]; then
        msg "$ICON_EXIT Loi khi kiem tra PHP Version Requirement: Thieu --website_source hoac --php_ver"
        return 1
    fi

    local php_major_minor="${php_ver%%.*}.${php_ver#*.}"
    php_major_minor="${php_major_minor%%.*}.${php_major_minor#*.}"

    case "$website_source" in
        laravel|wordpress)
            if [[ $(awk "BEGIN {print ($php_major_minor < 8.2) ? 1 : 0}") -eq 1 ]]; then
                msg "$ICON_EXIT $website_source can PHP >= 8.2, ban dang chon PHP $php_ver"
                return 1
            fi
            ;;
        *)
            return 0
            ;;
    esac

    return 0
}

validate_ssl_domain() {
    local domain="$1"
    local cert_file="${SSL_CERT_DIR}/${domain}/${SSL_CERT_FILE_NAME}"

    if [[ ! -f "$cert_file" || ! -s "$cert_file" ]]; then
        return 1
    fi

    local cn
    local san
    cn=$(openssl x509 -noout -subject -in "$cert_file" | sed -n 's/.*CN=\([^,\/]*\).*/\1/p')
    san=$(openssl x509 -noout -text -in "$cert_file" | grep -A1 "Subject Alternative Name" | tail -n1 | sed -e 's/ *DNS://g' -e 's/,//g')

    if [[ "$domain" == "$cn" ]]; then
        return 0
    fi

    IFS=', ' read -r -a san_array <<< "$san"
    for san_domain in "${san_array[@]}"; do
        if [[ "$domain" == "$san_domain" ]]; then
            return 0
        fi
    done

    return 1
}

is_ssl_need_renew() {
    local domain="$1"

    local cert_dir="${SSL_CERT_DIR}/${domain}"
    local cert_file="${cert_dir}/${SSL_CERT_FILE_NAME}"
    local key_file="${cert_dir}/${SSL_PRI_KEY_FILE_NAME}"

    if [[ ! -f "$cert_file" || ! -s "$cert_file" ]]; then
        return 0
    fi

    if [[ ! -f "$key_file" || ! -s "$key_file" ]]; then
        return 0
    fi

    local end_date now_date end_sec ssl_day_remaining
    end_date=$(/usr/bin/openssl x509 -noout -enddate -in "$cert_file" | awk -F= '{print $2}')
    now_date=$(/usr/bin/date +%s)
    end_sec=$(/usr/bin/date -d "$end_date" +%s 2>/dev/null || echo 0)
    ssl_day_remaining=$(( (end_sec - now_date) / 86400 ))

    if [[ -n "$ssl_day_remaining" && $ssl_day_remaining -gt 15 ]]; then
        return 1
    fi

    return 0
}

is_behind_cloudflare() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        return 1
    fi

    for cmd in dig grepcidr; do
        if ! command -v "$cmd" &> /dev/null; then
            apt-get install "$cmd" -y > /dev/null 2>&1
        fi
    done

    if [[ ! -f "$CF_IPV4_LIST" || ! -f "$CF_IPV6_LIST" ]]; then
        wget_with_retry --url "https://www.cloudflare.com/ips-v4" --output "$CF_IPV4_LIST" > /dev/null 2>&1 || return 1
        wget_with_retry --url "https://www.cloudflare.com/ips-v6" --output "$CF_IPV6_LIST" > /dev/null 2>&1 || return 1
    fi

    local domain_ips
    domain_ips=$( (dig +short A "$domain" @8.8.8.8; dig +short AAAA "$domain" @8.8.8.8) | sed '/^$/d' )

    if [[ -z "$domain_ips" ]]; then
        return 1
    fi

    local matching_ips
    matching_ips=$(echo "$domain_ips" | grepcidr -f "$CF_IPV4_LIST" -f "$CF_IPV6_LIST")

    if [[ -n "$matching_ips" ]]; then
        return 0
    else
        return 1
    fi
}

is_dir_empty() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        return 2
    fi

    shopt -s nullglob dotglob
    local files=("$dir"/*)
    shopt -u nullglob dotglob

    if (( ${#files[@]} == 0 )); then
        return 0
    fi

    return 1
}

is_ssh_login_ok() {
    local user
    local host
    local port=22
    local password

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user)     user="$2"; shift 2 ;;
            --host)     host="$2"; shift 2 ;;
            --port)     port=${2:-$port}; shift 2 ;;
            --password) password="${2:-}"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [ -z "$(which sshpass)" ]; then
        apt-get install sshpass -y
        clear
    fi

    if [[ -n "$password" ]]; then
        sshpass -p "$password" ssh -o StrictHostKeyChecking=no -p "$port" "${user}@${host}" 'exit' >/dev/null 2>&1
    else
        ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p "$port" "${user}@${host}" 'exit'
    fi

    if [[ $? -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

validate_port_list() {
    local port_list="$1"
    local port

    [[ -z "$port_list" ]] && return 1

    if [[ ! "$port_list" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        return 1
    fi

    IFS=',' read -ra PORTS <<<"$port_list"
    for port in "${PORTS[@]}"; do
        port="$(trim "$port")"
        if ! [[ "$port" =~ ^[0-9]+$ ]]; then
            return 1
        fi
        if (( port < 1 || port > 65535 )); then
            return 1
        fi
    done

    return 0
}

validate_ip_list() {
    local ip_list="$1"
    local ip

    [[ -z "$ip_list" ]] && return 1

    IFS=',' read -ra IPS <<<"$ip_list"
    for ip in "${IPS[@]}"; do
        ip="$(trim "$ip")"
        if ! valid_ip "$ip"; then
            return 1
        fi
    done

    return 0
}
