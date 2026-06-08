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

clear_screen() {
    clear
    #echo ""
}

msg() {
    local msg="$1"
    local color="${2:-red}"
    case "$color" in
        green|blue) printf "\n${BLUE}%s${NC}\n" "$msg" ;;
        red) printf "\n${RED}%s${NC}\n" "$msg" ;;
        yellow|orange) printf "\n${ORANGE}%s${NC}\n" "$msg" ;;
        *) echo "$msg" ;;
    esac
}

cd_dir(){
    local dir="$1"
    if ! cd "$dir"; then
        msg "$ICON_EXIT Khong the cd vao thu muc: $dir"
        exit 1
    fi
}

current_date() {
    date +"%d-%m-%Y"
}

run_with_countup() {
    local seconds=0
    shift
    local cmd=("$@")

    "${cmd[@]}" &
    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r⏳ Dang xu ly, vui long doi: %d" "$seconds"
        ((seconds++))
        sleep 1
    done

    wait "$pid"
}

count_down_old() {
    local count_down="${1:-5}"
    local text="$2"

    msg "$text" 'blue'
    for ((i=count_down; i>=1; i--)); do
        echo -ne "${RED}⏳ $i...${NC}\r"
        sleep 1
    done
}

countdown_timer() {
    local count_down="${1:-5}"
    local text="$2"
    local spinner=( '⠋' '⠙' '⠸' '⠼' '⠴' '⠦' '⠇' )

    if [ -n "$text" ]; then
        msg "$text" 'blue'
    fi

    for ((i=count_down; i>=1; i--)); do
        for frame in "${spinner[@]}"; do
            echo -ne "${RED}${frame} Doi $i giay...${NC}\r"
            sleep 0.1
        done
        sleep 0.4
    done
}

countdown() {
    local count_down="${1:-5}"
    local text="$2"
    countdown_timer "$count_down" "$text"
}

bytes_for_humans(){
    #https://stackoverflow.com/a/30872711
    local -i bytes=$1;
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(( (bytes + 1023)/1024 ))MB"
    else
        echo "$(( (bytes + 1048575)/1048576 ))GB"
    fi
}

gen_pass() {
    local length=16
    local part_upper=''
    local part_lower=''
    local part_digit=''
    local part_rest=''

    local upper_chars='ABCDEFGHJKLMNPQRSTUVWXYZ'
    local lower_chars='abcdefghijkmnopqrstuvwxyz'
    local digit_chars='123456789'

    part_upper=$(perl -e "print join('', map { substr('$upper_chars', int(rand(length('$upper_chars'))), 1) } 1..3)")
    part_lower=$(perl -e "print join('', map { substr('$lower_chars', int(rand(length('$lower_chars'))), 1) } 1..3)")
    part_digit=$(perl -e "print join('', map { substr('$digit_chars', int(rand(length('$digit_chars'))), 1) } 1..3)")

    local all_chars="${upper_chars}${lower_chars}${digit_chars}"

    local rest_len=$((length - 9))

    part_rest=$(perl -e "print join('', map { substr('$all_chars', int(rand(length('$all_chars'))), 1) } 1..$rest_len)")

    echo "${part_upper}${part_lower}${part_digit}${part_rest}" | fold -w1 | shuf | tr -d '\n'
}

get_all_ips() {
    ip -o addr show scope global | awk '{print $4}' | cut -d/ -f1
}

get_first_ip() {
    ip -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1
}

detect_country() {
    local ip
    local country

    if [ -z "$(which whois)" ]; then
        apt-get install whois -y
    fi

    ip="$(get_first_ip)"
    country=$(whois "$ip" | grep -i "^country" | head -n1 | awk '{print $2}')
    echo "${country:-UNKNOWN}"
}

create_symlink() {
    local target="$1"
    local link_name="$2"

    if [ ! -e "$target" ]; then
        return 1
    fi

    if [ -e "$link_name" ]; then
        rm -f "$link_name"
    fi

    ln -s "$target" "$link_name"

    if [ ! -e "$link_name" ]; then
        return 1
    fi
}

random_string() {
    STRING=$($(which perl) -le "print map+(A..Z,a..z,0..9)[rand 62],0..$1")
    echo "$STRING"
}

trim() {
    local value=$1
    echo "$value" | tr -d '[:space:]'
}

str_to_lower() {
    local str="$1"
    echo "$str" | tr '[:upper:]' '[:lower:]'
}

clean_domain() {
    local domain="$1"
    local remove_www="${2:-true}"

    domain=$(trim "$domain")
    domain=${domain#http://}
    domain=${domain#https://}

    if [ "$remove_www" == 'true' ]; then
        domain=${domain//www./}
    fi

    domain=$(str_to_lower "$domain")
    echo "$domain"
}

run_or_exit() {
    local desc="$1"
    shift

    [[ -n "$desc" ]] && msg "$ICON_TOOL $desc..."

    "$@"
    local status=$?

    if [[ $status -ne 0 ]]; then
        [[ -n "$desc" ]] && msg "$ICON_EXIT Loi khi: $desc"

        # shellcheck disable=SC2059
        msg "$ICON_ARROW Lenh loi: $*"

        exit "$status"
    fi
}

extract_key_value() {
    local input=$1
    local key=$2
    local strip_space=${3:-true}
    local value

    value=$(echo "$input" | grep -m1 "^${key}=" | cut -d'=' -f2-)

    if [[ "$strip_space" == "true" ]]; then
        value=$(trim "$value")
    fi

    KEY_VALUE_REPLY="$value"
    return 0
}

retry_run() {
    local max_retry=$1
    local delay=$2
    local description=$3
    shift 3
    local count=1

    while ((count <= max_retry)); do
        msg "🔁 Attempt $count: $description"
        if "$@"; then
            return 0
        fi
        msg "$ICON_WARNING Failed (attempt $count). Retrying in ${delay}s..."
        ((count++))
        sleep "$delay"
    done

    msg "$ICON_EXIT Failed after $max_retry attempts: $description"
    exit 1
}

retry_with_capture() {
    local __result_var=$1
    local max_retry=$2
    local delay=$3
    local description=$4
    shift 4

    local count=1
    local output

    while ((count <= max_retry)); do
        echo "🔁 Attempt $count: $description"

        output="$("$@")" && {
            printf -v "$__result_var" "%s" "$output"
            return 0
        }

        msg "$ICON_WARNING Failed (attempt $count). Retrying in ${delay}s..."
        ((count++))
        sleep "$delay"
    done

    msg "$ICON_EXIT Failed after $max_retry attempts: $description"
    exit 1
}

wget_with_retry() {
    local url=''
    local output=''
    local max_retry=5
    local delay=3

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --url)       url="$2"; shift 2 ;;
            --output)    output="$2"; shift 2 ;;
            --max_retry) max_retry="${2:-$max_retry}"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    retry_run "$max_retry" "$delay" "Downloading $output" \
        wget --timeout=30 --tries=3 --waitretry=2 --retry-connrefused -O "$output" "$url"
}

curl_get_with_retry() {
    local url=$1
    local max_retry=5
    local timeout=10
    local delay=3
    local result=''

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --url)       url="$2"; shift 2 ;;
            --timeout)    timeout="${2:-$timeout}"; shift 2 ;;
            --max_retry) max_retry="${2:-$max_retry}"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    retry_with_capture result "$max_retry" "$delay" "Fetching $url" \
        curl -fsSL --connect-timeout "$timeout" "$url" || return 1

    echo "$result"
}

git_clone_with_retry() {
    local repo_url=''
    local repo_dir=''
    local max_retry=5
    local delay=3

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo_url)  repo_url="$2"; shift 2 ;;
            --repo_dir)  repo_dir="$2"; shift 2 ;;
            --max_retry) max_retry="${2:-$max_retry}"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    retry_run "$max_retry" "$delay" "Cloning $repo_url" bash -c "
        rm -rf '$repo_dir' && \
        git clone --recurse-submodules -j8 '$repo_url' '$repo_dir'
    "
}

safe_apt_install() {
    local description="$1"
    shift
    echo "📦 Dang cai: ${description}"
    if ! apt-get install -y "$@"; then
        msg "$ICON_EXIT Loi khi cai dat: ${description}"
        exit 1
    fi
}

get_app_version(){
    local app_name="$1"
    local response=''
    local app_version=''

    response=$(curl_get_with_retry --url "${GET_VERSION_LINK}")

    extract_key_value "${response}" "${app_name}" 'false'
    app_version="${KEY_VALUE_REPLY}"

    if [ -z "$app_version" ]; then
        msg "$ICON_EXIT Khong the lay phien ban cua ${app_name}"
        exit 1
    fi

    # shellcheck disable=SC2034
    APP_VERSION_REPLY="$app_version"
    return 0
}

print_header() {
    local title="$1"
    msg "============== $title ==============" 'green'
}

generate_user_from_domain() {
    local domain="$1"
    local base_user
    local user
    local suffix

    if [ -z "$domain" ]; then
        return 1
    fi

    base_user=$(echo "$domain" | tr -dc 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]')
    base_user="${base_user:0:7}"

    while true; do
        suffix=$(tr -dc '[:lower:]' </dev/urandom | head -c 3)
        user="${base_user}${suffix}"

        if ! id -u "$user" &>/dev/null; then
            echo "$user"
            return 0
        fi
    done
}

generate_web_owner_folder() {
    local domain="$1"

    if [ -z "$domain" ]; then
        return 1
    fi

    echo "$domain" | tr -dc 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]'
}

set_site_dir_permission() {
    local owner=""
    local owner_folder=""
    local domain=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --owner)        owner="$2"; shift 2 ;;
            --owner_folder) owner_folder="$2"; shift 2 ;;
            --domain)       domain="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ ! -d "/home/${owner_folder}" || ! -d "/home/${owner_folder}/${domain}" ]]; then
        msg "$ICON_EXIT Thu muc /home/${owner_folder} hoac /home/${owner_folder}/${domain} khong ton tai"
        exit 1
    fi

    local base_dir
    base_dir="/home/${owner_folder}"

    chmod 711 /home
    chmod 755 "${base_dir}"
    chmod 711 "${base_dir}/${domain}"
    chmod 711 "${base_dir}/${domain}/logs"
    chmod 755 "${base_dir}/${domain}/public_html"
    find "${base_dir}/${domain}/public_html/" -type d -print0 | xargs -I {} -0 chmod 0755 {}
    find "${base_dir}/${domain}/public_html/" -type f -print0 | xargs -I {} -0 chmod 0644 {}
    chown root:root "/home/${owner_folder}"
    chown -R "${owner}:${owner}" "${base_dir}/${domain}"

    if [ -d "${base_dir}/tmp" ]; then
        chown -R "${owner}:${owner}" "${base_dir}/tmp"
    fi

    if [ -d "${base_dir}/php" ]; then
        chown -R "${owner}:${owner}" "${base_dir}/php"
    fi
}

patch_systemd_unit_file() {
    local service_name="$1"
    local unit_file=""

    if [[ -f "/usr/lib/systemd/system/${service_name}.service" ]]; then
        unit_file="/usr/lib/systemd/system/${service_name}.service"
    elif [[ -f "/lib/systemd/system/${service_name}.service" ]]; then
        unit_file="/lib/systemd/system/${service_name}.service"
    else
        msg "$ICON_EXIT Khong tim thay systemd unit cho ${service_name}"
        return 1
    fi

    msg "📦 Dang patch unit file: ${unit_file}"
    cp "$unit_file" "${unit_file}.bak.$(date +%F_%H%M%S)"

    if [[ "$service_name" == 'mariadb' ]]; then
        sed -i "s/LimitNOFILE=.*/LimitNOFILE=655350/g" "$unit_file"
        sed -i "s/PrivateTmp=false/PrivateTmp=true/g" "$unit_file"
    elif [ "$service_name" == 'php' ]; then
        local patches=(
            "LimitNOFILE=65535"
            "LimitMEMLOCK=infinity"
            "PrivateTmp=true"
            "ProtectKernelModules=true"
            "ProtectKernelTunables=true"
            "ProtectControlGroups=true"
            "RestrictRealtime=true"
            "RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX"
        )

        for patch in "${patches[@]}"; do
            if ! grep -q "^${patch}$" "$unit_file"; then
                sed -i "/^ExecReload=/a ${patch}" "$unit_file"
            fi
        done
    fi

    systemctl daemon-reload
}

# Su dung: get_max_item_width --array items --padding 2
# Gia tri tra ve duoc gan vao REPLY
get_max_item_width() {
    local array_name=""
    local padding=2

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --array)   array_name="$2"; shift 2 ;;
            --padding) padding="$2"; shift 2 ;;
            *)
                echo "$ICON_EXIT Tham so khong hop le: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$array_name" ]]; then
        echo "$ICON_EXIT Thieu --array"
        return 1
    fi

    local -n arr="$array_name"
    local max=0

    for item in "${arr[@]}"; do
        (( ${#item} > max )) && max=${#item}
    done

    (( max += padding ))
    MAX_ITEM_WIDTH_REPLY="$max"
}

print_paginated_list() {
    local title="${GREEN}=====================${NC}"
    local filtered_items=""
    local page_size=20
    local cols=3
    local col_width="auto"
    local fallback_cmd=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)        title="${2:-$title}"; shift 2 ;;
            --items)        filtered_items="$2"; shift 2 ;;
            --page_size)    page_size="${2:-$page_size}"; shift 2 ;;
            --cols)         cols="${2:-$cols}"; shift 2 ;;
            --col_width)    col_width="${2:-auto}"; shift 2 ;;
            --fallback_cmd) fallback_cmd="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [ -z "$filtered_items" ]; then
        msg "${ICON_EXIT} Thieu tham so --items."
        return 1
    fi

    local -n items="${filtered_items}"

    local total=${#items[@]}
    if [[ $total -eq 0 ]]; then
        msg "${ICON_EXIT} Khong co du lieu de hien thi."
        return 1
    fi

    if [[ -z "$col_width" || "$col_width" == "auto" ]]; then
        # shellcheck disable=SC2086
        get_max_item_width --array items
        col_width="${MAX_ITEM_WIDTH_REPLY:-35}"
    fi

    local page=0
    local total_pages=$(( (total + page_size - 1) / page_size ))

    while true; do
        clear_screen
        echo "$title (Trang $((page+1))/$total_pages):"
        echo

        local start=$((page * page_size))
        local end=$((start + page_size))
        (( end > total )) && end=$total

        local rows=$(( (end - start + cols - 1) / cols ))

        for ((r=0; r<rows; r++)); do
            local line=""
            for ((c=0; c<cols; c++)); do
                local idx=$((start + r + rows * c))
                if (( idx < end )); then
                    # shellcheck disable=SC2086
                    printf -v item "%2d) %-*s" $((idx+1)) $col_width "${items[idx]}"
                    line+="$item"
                fi
            done
            echo "$line"
        done

        echo
        msg "n) Trang sau | p) Trang truoc | 0) Thoat"
        read -rp "${GREEN}${ICON_ARROW} Nhap lua chon (n, p hoac 0):${NC} " cmd

        case "$cmd" in
            n) (( page < total_pages - 1 )) && ((page++)) ;;
            p) (( page > 0 )) && ((page--)) ;;
            q|0)
                if [ -z "$fallback_cmd" ]; then
                    return 0
                else
                    eval "$fallback_cmd"
                fi
            ;;
            *) echo "$ICON_EXIT Lua chon khong hop le."; sleep 1 ;;
        esac
    done
}

get_cname_record() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        echo ""
    fi

    local cname
    cname=$(dig +short CNAME "$domain" @8.8.8.8 | sed 's/\.$//')

    if [[ -z "$cname" ]]; then
        echo ""
    fi

    cname="$(str_to_lower "$cname")"
    echo "$cname"
}

get_cache_tool_version() {
    local cache_tool_ver version_response

    case "$PHP_CLI_MAJOR_VERSION" in
        8)
            if (( PHP_CLI_MINOR_VERSION >= 1 )); then
                version_response=$(curl_get_with_retry --url "${GET_VERSION_LINK}") || {
                    msg "$ICON_EXIT Da xay ra loi khi lay danh sach phien ban"
                    return 1
                }

                extract_key_value "${version_response}" "cache_tool_ver" 'true'
                # shellcheck disable=SC2206
                cache_tool_ver="${KEY_VALUE_REPLY}"
            else
                cache_tool_ver="8.6.1"
            fi
            ;;
        7)
            if (( PHP_CLI_MINOR_VERSION >= 3 )); then
                cache_tool_ver="7.1.0"
            elif (( PHP_CLI_MINOR_VERSION == 2 )); then
                cache_tool_ver="5.1.3"
            else
                cache_tool_ver=''
            fi
            ;;
        *)
            cache_tool_ver=''
            ;;
    esac

    echo "$cache_tool_ver"
}

get_ssl_cert_path() {
    local domain="$1"
    local cert_file

    cert_file=$(sed -n '0,/^\s*ssl_certificate\s\+\(.*\);/s//\1/p' "${SITE_AVAILABLE_DIR}/${domain}.conf")
    echo "$cert_file"
}

get_ssl_pri_key_path() {
    local domain="$1"
    local key_file

    key_file=$(sed -n '0,/^\s*ssl_certificate_key\s\+\(.*\);/s//\1/p' "${SITE_AVAILABLE_DIR}/${domain}.conf")
    echo "$key_file"
}

get_block_between_flags() {
    local file start_flag end_flag

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)       file="$2"; shift 2 ;;
            --start_flag) start_flag="$2"; shift 2 ;;
            --end_flag)   end_flag="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$file" || -z "$start_flag" || -z "$end_flag" ]]; then
        msg "Usage: get_block_between_flags --file <file> --start_flag <start_flag> --end_flag <end_flag>" >&2
        return 1
    fi

    awk -v start="$start_flag" -v end="$end_flag" '
        $0 ~ start {flag=1; next}
        $0 ~ end   {flag=0; exit}
        flag
    ' "$file"
}

get_nested_block() {
    local file="$1"
    local outer_start="$2"
    local outer_end="$3"
    local inner_start="$4"
    local inner_end="$5"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)       file="$2"; shift 2 ;;
            --outer_start) outer_start="$2"; shift 2 ;;
            --outer_end)   outer_end="$2"; shift 2 ;;
            --inner_start) inner_start="$2"; shift 2 ;;
            --inner_end)   inner_end="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$file" || -z "$outer_start" || -z "$outer_end" || -z "$inner_start" || -z "$inner_end" ]]; then
        msg "Usage: get_nested_block --file <file> --outer_start <outer_start> --outer_end <outer_end> --inner_start <inner_start> --inner_end <inner_end>" >&2
        return 1
    fi

    awk -v os="$outer_start" -v oe="$outer_end" -v is="$inner_start" -v ie="$inner_end" '
        $0 ~ os {outer=1; next}        # bắt đầu outer
        $0 ~ oe {outer=0}              # kết thúc outer
        outer && $0 ~ is {inner=1; next}
        outer && $0 ~ ie {inner=0; exit}
        inner
    ' "$file"
}

remove_block_between_flags() {
    local file
    local start_flag
    local end_flag

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)       file="$2"; shift 2 ;;
            --start_flag) start_flag="$2"; shift 2 ;;
            --end_flag)   end_flag="$2"; shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$file" || -z "$start_flag" || -z "$end_flag" ]]; then
        msg "Usage: remove_block_between_flags --file <file> --start_flag <start_flag> --end_flag <end_flag> --keep_flags [keep_flags]" >&2
        return 1
    fi

    sed -i "/$start_flag/,/$end_flag/{ /$start_flag/b; /$end_flag/b; d }" "$file"
}

generate_cache_zone() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        echo "Usage: generate_cache_zone <domain>" >&2
        return 1
    fi

    local cache_zone
    cache_zone=$(echo "$domain" | tr -cd 'a-zA-Z0-9')

    echo "$cache_zone"
}

check_remote_shell_clean() {
    local output
    local ssh_cmd
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

    if [[ -n "$password" ]]; then
        ssh_cmd=(sshpass -p "$bk_sftp_password" ssh \
                    -p "$bk_sftp_port" \
                    -o StrictHostKeyChecking=no \
                    -T "${bk_sftp_username}@${bk_sftp_host}" /bin/true)
    else
        ssh_cmd=(ssh -p "$port" -o BatchMode=yes -o StrictHostKeyChecking=no -T \
                     "${user}@${host}" /bin/true)
    fi

    output=$("${ssh_cmd[@]}" 2>&1 | cat -A)

    if [[ -n "$output" ]]; then
        clear
        msg "${ICON_ERROR} Remote shell is NOT clean on ${user}@${host}"
        echo "    Extra output detected: [$output]"
        msg "${ICON_HAND} Please check ~/.bashrc, ~/.bash_profile, ~/.cshrc, /etc/motd, /etc/profile or Banner in sshd_config"
        exit 1
    fi
}

update_conf_vars() {
    local file="$1"
    shift
    local pairs=("$@")

    if [ ! -e "$file" ]; then
        msg "${ICON_ERROR} update_conf_vars: Config File does not exists ${user}@${host}"
        exit 1
    fi

    for pair in "${pairs[@]}"; do
        local key="${pair%%=*}"
        local value="${pair#*=}"
        sed -i "/^${key}=.*/d" "$file"
        echo "${key}='${value}'" >> "$file"
    done
}

detect_ssh_port() {
    if sshd_path=$(command -v sshd 2>/dev/null); then
        if port_from_t=$($sshd_path -T 2>/dev/null | awk '/^port /{print $2; exit}'); then
            if [[ -n "$port_from_t" ]]; then
                printf '%s' "$port_from_t"
                return 0
            fi
        fi
    fi

    if [[ -r /etc/ssh/sshd_config ]]; then
        port_from_conf=$(awk '
            BEGIN{port=""}
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*Port[[:space:]]+/ {
                for(i=2;i<=NF;i++){
                    if($i ~ /^[0-9]+$/){ print $i; exit }
                }
            }
        ' /etc/ssh/sshd_config)
        if [[ -n "$port_from_conf" ]]; then
            printf '%s' "$port_from_conf"
            return 0
        fi
    fi

    if command -v ss >/dev/null 2>&1; then
        port_from_ss=$(ss -tlnp 2>/dev/null | awk '/sshd/ {
            for(i=1;i<=NF;i++){
                if($i ~ /:[0-9]+$/){
                    split($i,a,":"); print a[length(a)]; exit
                }
            }
        }')
        if [[ -n "$port_from_ss" ]]; then
            printf '%s' "$port_from_ss"
            return 0
        fi
    elif command -v netstat >/dev/null 2>&1; then
        port_from_netstat=$(netstat -tlnp 2>/dev/null | awk '/sshd/ {
            for(i=1;i<=NF;i++){
                if($i ~ /:[0-9]+$/){
                    split($i,a,":"); print a[length(a)]; exit
                }
            }
        }')
        if [[ -n "$port_from_netstat" ]]; then
            printf '%s' "$port_from_netstat"
            return 0
        fi
    fi

    printf '22'
    return 0
}

format_nginx_config() {
    local vhost_file="$1"

    if [[ ! -f "$vhost_file" ]]; then
        msg "$ICON_ERROR File does not exist: $vhost_file"
        return 1
    fi

    chmod +x "${HVN_BIN_DIR}/nginx_formater"
    "${HVN_BIN_DIR}/nginx_formater" "${vhost_file}"

    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
        msg "$ICON_ERROR Error formatting nginx config"
        return 1
    fi
}

press_enter_to_continue() {
    printf "\n"
    read -rp "$(echo -e "\033[0;32mNhan Enter de quay lai menu...\033[0m")" _
}
