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

source "${MENU_DIR}/helpers/file.sh"
source "${MENU_DIR}/validate/rule.sh"

if ! declare -f msg >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

ssl_cleanup_lock() {
    [[ -f "$LOCK_SIGN_SSL_PROGRESS" ]] && rm -f "$LOCK_SIGN_SSL_PROGRESS"
}

is_letsencrypt_rate_limited_error() {
    local log_output="$1"
    grep -q -E 'rateLimited|rate-limits|too many certificates' <<< "$log_output"
}

retry_with_zero_ssl() {
    local acme_cmd="$1"
    shift
    local -a original_args=("$@")
    local -a filtered_args=()
    local skip_next=false

    for arg in "${original_args[@]}"; do
        if [[ "$arg" =~ ^--server= ]]; then
            continue
        elif [[ "$arg" == "--server" ]]; then
            skip_next=true
            continue
        elif [[ "$skip_next" == true ]]; then
            skip_next=false
            continue
        fi
        filtered_args+=("$arg")
    done

    local output
    output="$("$acme_cmd" "${filtered_args[@]}" 2>&1)"
    local exit_code=$?

    echo "$output" >> "${SSL_ERROR_LOG_FILE}"
    echo "$output"

    if [[ $exit_code -ne 0 ]]; then
        return 1
    else
        return 0
    fi
}

handle_acme_issue_failure() {
    local acme_cmd="$1"
    local staging="$2"
    local output="$3"
    shift 3
    local args=("$@")
    local -a domains=()

    for ((i = 0; i < ${#args[@]}; i++)); do
        if [[ "${args[$i]}" =~ ^(-d|--domain)$ && -n "${args[$((i+1))]}" ]]; then
            domains+=("${args[$((i+1))]}")
        fi
    done

    echo "$output" >> "${SSL_ERROR_LOG_FILE}"
    echo "$output"

    if [[ "$staging" != true ]] && is_letsencrypt_rate_limited_error "$output"; then
        msg "$ICON_EXIT Let's Encrypt Error: Too many certificates (5) already issued for this exact set of identifiers in the last 168h0m0s"
        msg "$ICON_TOOL Retrying with ZeroSSL. Please wait ..." 'green'

        if ! retry_with_zero_ssl "$acme_cmd" "${args[@]}"; then
            echo "$(date +'%F %T') - Retry with ZeroSSL failed for domain: ${domains[*]}" >> "${SSL_ERROR_LOG_FILE}"
            return 1
        fi

        return 0
    else
        msg "$(date +'%F %T') - $ICON_EXIT Error issuing cert for domain: ${domains[*]}"
        echo "$(date +'%F %T') - Error issuing cert for domain: ${domains[*]}" >> "${SSL_ERROR_LOG_FILE}"
        return 1
    fi
}

ssl_build_acme_args() {
    local staging_flag="$1"
    shift
    local -a domains=("$@")

    local -a args=()
    for d in "${domains[@]}"; do
        args+=("--domain $d")
    done

    if [ "$staging_flag" == 'true' ]; then
        args+=(" --staging")
    fi

    echo "${args[@]}"
}

ssl_initialize_ssl_signing() {
    mkdir -p "$SSL_LOG_PATH" "${SSL_LOG_PATH}/errors" "${SSL_LOG_PATH}/history" "$SSL_CERT_DIR"
    [[ -e "$LOCK_SIGN_SSL_PROGRESS" ]] && exit 0
    touch "$LOCK_SIGN_SSL_PROGRESS"
    trap ssl_cleanup_lock EXIT INT TERM ERR
}

ssl_issue_and_install_cert() {
    local cert_file=""
    local key_file=""
    local staging=false
    local -a domains=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cert-file) cert_file="$2"; shift 2 ;;
            --key-file)  key_file="$2"; shift 2 ;;
            --staging)   staging=true; shift ;;
            --domain)    domains+=("$2"); shift 2 ;;
            *) msg "$ICON_EXIT Tham so khong hop le: $1"; return 1 ;;
        esac
    done

    if [[ -z "$cert_file" || -z "$key_file" || "${#domains[@]}" -eq 0 ]]; then
        echo "$(date +'%F %T') - Thieu --cert-file, --key-file hoac --domain" >> "${SSL_ERROR_LOG_FILE}"
        msg "$(date +'%F %T') - Thieu --cert-file, --key-file hoac --domain"
        return 1
    fi

    local acme_cmd="/root/.acme.sh/acme.sh"
    local -a args=("--issue")

    for d in "${domains[@]}"; do
        args+=("-d" "$d")
    done

    args+=("-w" "/var/www/html")

    if [[ "$staging" == true ]]; then
        args+=("--staging")
    else
        args+=("--server" "letsencrypt")
    fi

    args+=(--force)

    local acme_output
    acme_output="$("$acme_cmd" "${args[@]}" 2>&1)"
    local acme_exit=$?

    if [[ $acme_exit -ne 0 ]]; then
        if ! handle_acme_issue_failure "$acme_cmd" "$staging" "$acme_output" "${args[@]}"; then
            return 1
        fi
    fi

    local install_args=()
    for d in "${domains[@]}"; do
        install_args+=("-d" "$d")
    done

    "$acme_cmd" --install-cert "${install_args[@]}" \
        --key-file "$key_file" \
        --fullchain-file "$cert_file" \
        2>> "${SSL_ERROR_LOG_FILE}"

    if [[ -s "$cert_file" && -s "$key_file" ]]; then
        return 0
    else
        return 1
    fi
}

ssl_restore_backup() {
    local cert_file="$1"
    local key_file="$2"

    [[ -e "${cert_file}.bak" ]] && mv "${cert_file}.bak" "$cert_file"
    [[ -e "${key_file}.bak"  ]] && mv "${key_file}.bak" "$key_file"
}

ssl_update_nginx_config() {
    local domain="$1"
    local cert_file="$2"
    local key_file="$3"
    local conf

    for dir in "$SITE_AVAILABLE_DIR" "$SITE_ALIAS_CONF_DIR" "$SITE_REDIRECT_CONF_DIR"; do
        conf="$dir/$domain.conf"
        [[ -e "$conf" ]] && break
    done

    sed -i '/^\s*ssl_certificate\s\+[^;]*;/d' "$conf"
    sed -i '/^\s*ssl_certificate_key\s\+[^;]*;/d' "$conf"
    sed -i "/#SSL_CERT/a\ ssl_certificate ${cert_file};\n ssl_certificate_key ${key_file};" "$conf"
    run_or_exit "Format Nginx config" format_nginx_config "$conf"
}

ssl_reload_nginx_if_needed() {
    [[ "$SSL_NEED_RELOAD_NGINX" == 'true' ]] && /usr/bin/systemctl reload nginx
}

ssl_process_single_domain() {
    local domain="$1"
    local pending_file="$2"
    local cert_dir="${SSL_CERT_DIR}/${domain}"
    local cert_file="${cert_dir}/${SSL_CERT_FILE_NAME}"
    local key_file="${cert_dir}/${SSL_PRI_KEY_FILE_NAME}"

    mkdir -p "$cert_dir"

    ! is_valid_domain "$domain" && return
    #! is_domain_points_to_vps "$domain" && return

    if ! is_domain_points_to_vps "$domain" && ! is_behind_cloudflare "$domain"; then
        msg "$ICON_WARNING Ten mien $domain chua duoc tro DNS ve VPS. Bo qua ky SSL."
        return
    fi

    local acme_domains=("$domain")

    if [[ "$(get_cname_record "www.$domain" == '')" == "$domain" ]]; then
        acme_domains+=("www.$domain")
    elif is_domain_points_to_vps "www.$domain" || is_behind_cloudflare "ww.$domain"; then
        acme_domains+=("www.$domain")
    fi

    if ! is_ssl_need_renew "$domain"; then
        msg "$ICON_WARNING Ten mien $domain da co SSL"
        ssl_update_nginx_config "$domain" "$cert_file" "$key_file"
        SSL_NEED_RELOAD_NGINX='true'
        delete_file "$pending_file"
        return
    fi

    [[ -e "$cert_file" ]] && mv "$cert_file" "$cert_file.bak"
    [[ -e "$key_file"  ]] && mv "$key_file"  "$key_file.bak"

    local staging_acme_args prod_acme_args
    read -ra staging_acme_args < <(ssl_build_acme_args true "${acme_domains[@]}")
    read -ra prod_acme_args < <(ssl_build_acme_args false "${acme_domains[@]}")

    msg "$ICON_TOOL Test with staging" 'green'
    ssl_issue_and_install_cert --cert-file "$cert_file" --key-file "$key_file" "${staging_acme_args[@]}"

    if is_empty_file "$key_file" || is_empty_file "$cert_file"; then
        ssl_restore_backup "$cert_file" "$key_file"
        return
    fi

    msg "$ICON_TOOL Sign SSL" 'green'
    ssl_issue_and_install_cert --cert-file "$cert_file" --key-file "$key_file" "${prod_acme_args[@]}"

    if ! is_empty_file "$key_file" && ! is_empty_file "$cert_file"; then
        delete_file "$pending_file"
        ssl_update_nginx_config "$domain" "$cert_file" "$key_file"
        SSL_NEED_RELOAD_NGINX='true'
        delete_file "${SSL_PENDING_DIR}/${domain}"
        clear_screen
        msg "$ICON_CHECK Ky SSL cho ten mien $domain thanh cong!" 'green'
        return
    fi

    ssl_restore_backup "$cert_file" "$key_file"
}

# ssl_process_all_pending_domains --scan-type domain --domains "example.com www.example.com"
# ssl_process_all_pending_domains --scan-type f --dir /path/to/pending-files
# ssl_process_all_pending_domains --scan-type d --dir /path/to/pending-dirs
ssl_process_all_pending_domains() {
    local pending_dir=""
    local scan_type=""
    local domain_list_str=""
    local domain_list=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir)
                pending_dir="$2"
                shift 2
                ;;
            --scan-type)
                scan_type="$2"
                shift 2
                ;;
            --domains)
                domain_list_str="$2"
                shift 2
                ;;
            *)
                msg "$ICON_EXIT Tham so khong hop le: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$scan_type" ]]; then
        msg "$ICON_EXIT Thieu --scan-type"
        return 1
    fi

    if [[ "$scan_type" != "f" && "$scan_type" != "d" && "$scan_type" != "domain" ]]; then
        msg "$ICON_EXIT --scan-type khong hop le: $scan_type"
        return 1
    fi

    if [[ "$scan_type" != "domain" && ! -d "$pending_dir" ]]; then
        msg "$ICON_EXIT --dir khong hop le hoac khong ton tai"
        return 1
    fi

    if [[ "$scan_type" == "domain" && -z "$domain_list_str" ]]; then
        msg "$ICON_EXIT Phai truyen --domains khi scan-type la domain"
        return 1
    fi

    if [[ "$pending_dir" == "$SSL_CERT_DIR" && "$scan_type" == 'f' ]]; then
        msg "$ICON_EXIT --scan-type khong hop le: $scan_type"
        return 1
    fi

    if [[ "$pending_dir" == "$SSL_PENDING_DIR" && "$scan_type" == 'd' ]]; then
        msg "$ICON_EXIT --scan-type khong hop le: $scan_type"
        return 1
    fi

    ssl_initialize_ssl_signing

    case "$scan_type" in
        f)
            while IFS= read -r -d '' pending_item; do
                local domain
                domain="$(basename -- "$pending_item")"
                ssl_process_single_domain "$domain" "$pending_item"
            #done < <(find "$pending_dir" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)
            done < <(find -L "$pending_dir" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)
            ;;
        d)
            while IFS= read -r -d '' pending_item; do
                local domain
                domain="$(basename -- "$pending_item")"
                ssl_process_single_domain "$domain"
            done < <(find "$pending_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
            ;;
        domain)
            read -ra domain_list <<< "$domain_list_str"

            for domain in "${domain_list[@]}"; do
                ssl_process_single_domain "$domain"
            done
            ;;
    esac

    ssl_reload_nginx_if_needed
}
