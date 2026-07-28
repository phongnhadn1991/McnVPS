#!/bin/bash

##############################################################################################################
#                             Auto Install & Optimize LEMP Stack on Ubuntu                                   #
#                                                                                                            #
#                                    Author: Sanvv - MCN Technical                                           #
#                                        Website: https://mcnvps.net                                         #
#                                                                                                            #
#                                  Please do not remove copyright. Thank!                                    #
#  Copying or using this content for any commercial purpose is strictly prohibited under all circumstances!  #
##############################################################################################################

CF_TUNNEL_CONF="${HOSTVN_DIR}/.cf_tunnel.conf"
CF_TUNNEL_DNS_HELPER="${MENU_DIR}/cronjob/cf_tunnel.sh"
CF_API="https://api.cloudflare.com/client/v4"

cf_tunnel_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== Cloudflare Tunnel ==========${NC}"

        local current_mode="direct"
        # shellcheck disable=SC1090
        [[ -f "${FILE_INFO}" ]] && source "${FILE_INFO}"
        current_mode="${network_mode:-direct}"

        if [[ "$current_mode" == "tunnel" ]]; then
            echo "${GREEN}Trang thai: TUNNEL MODE (port 80/443 dong)${NC}"
        else
            echo "${RED}Trang thai: DIRECT MODE (port 80/443 mo)${NC}"
        fi
        echo ""
        echo "${BLUE}1. Bat Cloudflare Tunnel${NC}"
        echo "${BLUE}2. Tat Cloudflare Tunnel${NC}"
        echo "${BLUE}3. Trang thai${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " tunnel_choice

        case "$tunnel_choice" in
            1) _tunnel_enable ;;
            2) _tunnel_disable ;;
            3) _tunnel_status ;;
            0) return ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}

_install_cloudflared() {
    if command -v cloudflared &>/dev/null; then
        return 0
    fi

    msg "$ICON_TOOL Dang cai dat cloudflared..."
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/cloudflared.list
    apt-get update -y >/dev/null 2>&1
    apt-get install -y cloudflared >/dev/null 2>&1

    if ! command -v cloudflared &>/dev/null; then
        msg "$ICON_EXIT Cai dat cloudflared that bai"
        return 1
    fi
    msg "$ICON_SUCCESS Cai dat cloudflared thanh cong" 'green'
    return 0
}

_tunnel_enable() {
    if ! command -v jq &>/dev/null; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y jq >/dev/null 2>&1
    fi

    clear_screen
    echo "${GREEN}=== Yeu cau ve Cloudflare API Token ===${NC}"
    echo "Token can cac quyen sau:"
    echo "  1. Account > Cloudflare Tunnel > Edit"
    echo "  2. Zone > Zone > Read"
    echo "  3. Zone > DNS > Edit"
    echo ""

    read -r -p "Nhap Cloudflare API Token [0=thoat]: " cf_token
    [[ -z "${cf_token}" || "${cf_token}" == "0" ]] && return

    if ! curl -s --max-time 15 "${CF_API}/user/tokens/verify" \
        -H "Authorization: Bearer ${cf_token}" | jq -e '.success == true' >/dev/null 2>&1; then
        msg "$ICON_EXIT Token khong hop le hoac het han"
        press_enter_to_continue; return
    fi

    msg "$ICON_SUCCESS Token hop le" 'green'

    local account_id=""
    account_id=$(curl -s --max-time 15 "${CF_API}/accounts?page=1&per_page=1" \
        -H "Authorization: Bearer ${cf_token}" | jq -r '.result[0].id // empty' 2>/dev/null)

    if [[ -z "$account_id" ]]; then
        read -r -p "Nhap domain de tim Account ID [0=thoat]: " cf_domain
        [[ -z "${cf_domain}" || "${cf_domain}" == "0" ]] && return
        account_id=$(curl -s --max-time 15 "${CF_API}/zones?name=${cf_domain}" \
            -H "Authorization: Bearer ${cf_token}" | jq -r '.result[0].account.id // empty' 2>/dev/null)
    fi

    if [[ -z "$account_id" ]]; then
        msg "$ICON_EXIT Khong tim thay Account ID"
        press_enter_to_continue; return
    fi

    _install_cloudflared || { press_enter_to_continue; return; }

    read -r -p "Dat ten cho tunnel (vd: my-vps): " tunnel_name
    [[ -z "$tunnel_name" ]] && tunnel_name="mcnvps-$(hostname -s)"

    msg "$ICON_TOOL Dang tao tunnel '${tunnel_name}'..."
    local tunnel_secret
    tunnel_secret=$(head -c 32 /dev/urandom | base64)

    local create_resp
    create_resp=$(curl -s --max-time 30 -X POST "${CF_API}/accounts/${account_id}/cfd_tunnel" \
        -H "Authorization: Bearer ${cf_token}" \
        -H "Content-Type: application/json" \
        --data "{\"name\":\"${tunnel_name}\",\"tunnel_secret\":\"${tunnel_secret}\"}")

    local tunnel_id
    tunnel_id=$(echo "$create_resp" | jq -r '.result.id // empty' 2>/dev/null)
    if [[ -z "$tunnel_id" ]]; then
        local err_msg
        err_msg=$(echo "$create_resp" | jq -r '.errors[0].message // "Unknown error"' 2>/dev/null)
        msg "$ICON_EXIT Tao tunnel that bai: ${err_msg}"
        press_enter_to_continue; return
    fi

    msg "$ICON_SUCCESS Tao tunnel thanh cong: ${tunnel_id}" 'green'

    local tunnel_token
    tunnel_token=$(echo "$create_resp" | jq -r '.result.token // empty' 2>/dev/null)

    if [[ -z "$tunnel_token" ]]; then
        tunnel_token=$(printf '{"a":"%s","t":"%s","s":"%s"}' "$account_id" "$tunnel_id" "$tunnel_secret" | base64 -w0)
    fi

    msg "$ICON_TOOL Dang cau hinh ingress..."
    curl -s --max-time 15 -X PUT "${CF_API}/accounts/${account_id}/cfd_tunnel/${tunnel_id}/configurations" \
        -H "Authorization: Bearer ${cf_token}" \
        -H "Content-Type: application/json" \
        --data '{"config":{"ingress":[{"service":"http://localhost:80"}]}}' >/dev/null 2>&1

    msg "$ICON_TOOL Dang cai dat systemd service..."
    cloudflared service uninstall 2>/dev/null
    cloudflared service install "$tunnel_token" 2>/dev/null
    systemctl enable cloudflared 2>/dev/null
    systemctl start cloudflared 2>/dev/null

    cat > "${CF_TUNNEL_CONF}" <<EOF
CF_API_TOKEN="${cf_token}"
CF_ACCOUNT_ID="${account_id}"
CF_TUNNEL_ID="${tunnel_id}"
EOF
    chmod 600 "${CF_TUNNEL_CONF}"

    msg "$ICON_TOOL Dang cau hinh nginx real_ip..."
    cat > /etc/nginx/extra/cloudflare.conf <<'NGINX'
set_real_ip_from 127.0.0.1;
real_ip_header CF-Connecting-IP;
real_ip_recursive on;
NGINX
    nginx -t 2>/dev/null && systemctl reload nginx

    msg "$ICON_TOOL Dang dong port 80/443..."
    nft delete element inet filter allowed_tcp_ports "{ 80, 443 }" 2>/dev/null
    nft delete element inet filter allowed_udp_ports "{ 443 }" 2>/dev/null
    nft list ruleset > /etc/nftables.conf 2>/dev/null

    if [[ -f /etc/fail2ban/jail.d/00-defaults-debian.local ]]; then
        if ! grep -q "::1" /etc/fail2ban/jail.d/00-defaults-debian.local; then
            sed -i 's/ignoreip.*=.*/& ::1/' /etc/fail2ban/jail.d/00-defaults-debian.local
        fi
        systemctl restart fail2ban 2>/dev/null
    fi

    update_conf_vars "${FILE_INFO}" "network_mode" "tunnel"

    msg "$ICON_TOOL Dang dong bo DNS cho cac domain hien co..."
    chmod +x "${CF_TUNNEL_DNS_HELPER}"
    for site_conf in "${WEB_DATA_DIR}"/*/.settings.conf; do
        [[ -f "$site_conf" ]] || continue
        local site_domain=""
        site_domain=$(grep '^domain=' "$site_conf" | cut -d= -f2 | tr -d '"')
        [[ -n "$site_domain" ]] && bash "${CF_TUNNEL_DNS_HELPER}" add-dns "$site_domain"
    done

    echo ""
    msg "$ICON_SUCCESS Cloudflare Tunnel da duoc bat!" 'green'
    echo "${GREEN}Tunnel ID : ${tunnel_id}${NC}"
    echo "${GREEN}Port 80/443 da dong. Traffic di qua Cloudflare Tunnel.${NC}"

    press_enter_to_continue
}

_tunnel_disable() {
    if [[ ! -f "${CF_TUNNEL_CONF}" ]]; then
        msg "$ICON_EXIT Cloudflare Tunnel chua duoc cau hinh"
        press_enter_to_continue; return
    fi

    if ! prompt_yes_no "Tat Cloudflare Tunnel va mo lai port 80/443?"; then
        return
    fi

    cloudflared service uninstall 2>/dev/null
    systemctl stop cloudflared 2>/dev/null

    # Restore CF IP ranges for real_ip
    msg "$ICON_TOOL Dang khoi phuc nginx real_ip tu Cloudflare IP ranges..."
    local cf_ips_v4="${CLOUDFLARE_IPS_V4_URL:-https://www.cloudflare.com/ips-v4}"
    local cf_ips_v6="${CLOUDFLARE_IPS_V6_URL:-https://www.cloudflare.com/ips-v6}"

    {
        echo "# Cloudflare IP ranges"
        curl -s --max-time 10 "$cf_ips_v4" 2>/dev/null | while read -r ip; do
            [[ -n "$ip" ]] && echo "set_real_ip_from ${ip};"
        done
        curl -s --max-time 10 "$cf_ips_v6" 2>/dev/null | while read -r ip; do
            [[ -n "$ip" ]] && echo "set_real_ip_from ${ip};"
        done
        echo "real_ip_header CF-Connecting-IP;"
        echo "real_ip_recursive on;"
    } > /etc/nginx/extra/cloudflare.conf

    nginx -t 2>/dev/null && systemctl reload nginx

    msg "$ICON_TOOL Dang mo lai port 80/443..."
    nft add element inet filter allowed_tcp_ports "{ 80, 443 }" 2>/dev/null
    nft add element inet filter allowed_udp_ports "{ 443 }" 2>/dev/null
    nft list ruleset > /etc/nftables.conf 2>/dev/null

    update_conf_vars "${FILE_INFO}" "network_mode" "direct"
    rm -f "${CF_TUNNEL_CONF}"

    msg "$ICON_SUCCESS Cloudflare Tunnel da tat. Port 80/443 da mo lai." 'green'
    press_enter_to_continue
}

_tunnel_status() {
    clear_screen
    echo "${BLUE}========== Cloudflare Tunnel Status ==========${NC}"

    local current_mode="direct"
    # shellcheck disable=SC1090
    [[ -f "${FILE_INFO}" ]] && source "${FILE_INFO}"
    current_mode="${network_mode:-direct}"

    echo "${GREEN}Network mode  : ${current_mode}${NC}"

    if [[ -f "${CF_TUNNEL_CONF}" ]]; then
        # shellcheck disable=SC1090
        source "${CF_TUNNEL_CONF}"
        echo "${GREEN}Tunnel ID     : ${CF_TUNNEL_ID}${NC}"
        echo "${GREEN}Account ID    : ${CF_ACCOUNT_ID}${NC}"
    else
        echo "${RED}Chua cau hinh Cloudflare Tunnel${NC}"
    fi

    echo ""
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        echo "${GREEN}cloudflared   : RUNNING${NC}"
    else
        echo "${RED}cloudflared   : STOPPED${NC}"
    fi

    echo ""
    echo "${BLUE}Port 80  :${NC} $(nft list set inet filter allowed_tcp_ports 2>/dev/null | grep -q ' 80' && echo '${GREEN}OPEN${NC}' || echo '${RED}CLOSED${NC}')"
    echo "${BLUE}Port 443 :${NC} $(nft list set inet filter allowed_tcp_ports 2>/dev/null | grep -q ' 443' && echo '${GREEN}OPEN${NC}' || echo '${RED}CLOSED${NC}')"

    press_enter_to_continue
}
