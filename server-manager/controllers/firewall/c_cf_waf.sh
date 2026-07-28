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

# Dong bo Fail2ban -> Cloudflare WAF: khi fail2ban ban 1 IP, IP do cung bi
# chan tren Cloudflare (IP Access Rules muc zone).
#
# Token can 2 quyen (Permissions) o muc Zone:
#   1. Zone > Zone             > Read   (de tim zone ID tu ten domain)
#   2. Zone > Firewall Services > Edit  (de tao/xoa IP Access Rule)

CF_WAF_CONF="${HOSTVN_DIR}/.cf_waf.conf"
CF_WAF_ACTION_FILE="/etc/fail2ban/action.d/cloudflare-mcnvps.conf"
CF_WAF_ATTACH_FILE="/etc/fail2ban/jail.d/zz-cloudflare.local"
CF_WAF_WRAPPER="${MENU_DIR}/cronjob/cf_waf.sh"

cf_waf_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== Cloudflare WAF Sync ==========${NC}"
        if [ -f "${CF_WAF_CONF}" ]; then
            echo "${GREEN}Trang thai: DANG BAT (zone da cau hinh).${NC}"
        else
            echo "${RED}Trang thai: CHUA BAT.${NC}"
        fi
        echo ""
        echo "${BLUE}1. Bat / Cau hinh lai${NC}"
        echo "${BLUE}2. Tat dong bo${NC}"
        echo "${BLUE}3. Test ban/unban 1 IP${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " cf_waf_choice

        case "$cf_waf_choice" in
            1) _cf_waf_enable ;;
            2) _cf_waf_disable ;;
            3) _cf_waf_test ;;
            0) return ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}

_cf_waf_enable() {
    if ! command -v jq >/dev/null 2>&1; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y jq >/dev/null 2>&1
    fi

    clear_screen
    echo "${GREEN}=== Yeu cau ve Cloudflare API Token ===${NC}"
    echo "Token can 2 quyen (deu o muc Zone):"
    echo "  1. Zone > Zone > Read"
    echo "  2. Zone > Firewall Services > Edit"
    echo "Tao tai: Cloudflare > My Profile > API Tokens > Create Custom Token,"
    echo "chon Zone Resources = domain can bao ve."
    echo "${RED}(Token dung cho SSL wildcard chi co DNS:Edit -> KHONG du quyen o day.)${NC}"
    echo ""

    read -r -p "Nhap Cloudflare API Token [0=thoat]: " cf_token
    [[ -z "${cf_token}" || "${cf_token}" == "0" ]] && return

    if ! curl -s --max-time 15 "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer ${cf_token}" | jq -e '.success == true' >/dev/null 2>&1; then
        echo "${RED}Token khong hop le hoac het han.${NC}"
        read -r -p "Nhan Enter de quay lai..." _
        return
    fi

    read -r -p "Nhap domain nam tren Cloudflare (de xac dinh zone) [0=thoat]: " cf_domain
    [[ -z "${cf_domain}" || "${cf_domain}" == "0" ]] && return

    local zone_id="" try="${cf_domain}"
    while [ -n "${try}" ]; do
        zone_id=$(curl -s --max-time 15 "https://api.cloudflare.com/client/v4/zones?name=${try}" \
            -H "Authorization: Bearer ${cf_token}" | jq -r '.result[0].id // empty' 2>/dev/null)
        [ -n "${zone_id}" ] && break
        if [[ "${try}" == *.*.* ]]; then try="${try#*.}"; else break; fi
    done

    if [ -z "${zone_id}" ]; then
        echo "${RED}Khong tim thay zone cho '${cf_domain}'. Token co quyen zone nay khong?${NC}"
        read -r -p "Nhan Enter de quay lai..." _
        return
    fi

    local test_ip="203.0.113.250"
    local api="https://api.cloudflare.com/client/v4/zones/${zone_id}/firewall/access_rules/rules"
    local create_resp
    create_resp=$(curl -s --max-time 15 -X POST "${api}" \
        -H "Authorization: Bearer ${cf_token}" \
        -H "Content-Type: application/json" \
        --data "{\"mode\":\"block\",\"configuration\":{\"target\":\"ip\",\"value\":\"${test_ip}\"},\"notes\":\"fail2ban-mcnvps-test\"}")

    if ! echo "${create_resp}" | jq -e '.success == true' >/dev/null 2>&1; then
        echo "${RED}Token khong co quyen tao IP Access Rule cho zone nay.${NC}"
        echo "${RED}Token phai co quyen: Zone > Zone > Read VA Zone > Firewall Services > Edit.${NC}"
        local cf_err
        cf_err=$(echo "${create_resp}" | jq -r '.errors[0].message // empty' 2>/dev/null)
        [ -n "${cf_err}" ] && echo "${RED}Cloudflare bao: ${cf_err}${NC}"
        read -r -p "Nhan Enter de quay lai..." _
        return
    fi

    local test_id
    test_id=$(echo "${create_resp}" | jq -r '.result.id')
    curl -s --max-time 15 -X DELETE "${api}/${test_id}" -H "Authorization: Bearer ${cf_token}" >/dev/null 2>&1

    cat > "${CF_WAF_CONF}" <<EOF
CF_WAF_TOKEN="${cf_token}"
CF_WAF_ZONE="${zone_id}"
EOF
    chmod 600 "${CF_WAF_CONF}"

    cat > "${CF_WAF_ACTION_FILE}" <<EOF
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = /bin/bash ${CF_WAF_WRAPPER} ban <ip>
actionunban = /bin/bash ${CF_WAF_WRAPPER} unban <ip>
EOF

    chmod +x "${CF_WAF_WRAPPER}"

    cat > "${CF_WAF_ATTACH_FILE}" <<EOF
[DEFAULT]
action = %(action_)s
         cloudflare-mcnvps
EOF

    systemctl restart fail2ban
    sleep 2

    if systemctl is-active --quiet fail2ban; then
        echo "${GREEN}Da bat dong bo Fail2ban -> Cloudflare WAF (zone: ${zone_id}).${NC}"
        echo "${GREEN}Tu gio moi IP bi fail2ban ban se bi chan tren Cloudflare.${NC}"
    else
        echo "${RED}Fail2ban khong khoi dong duoc. Kiem tra: journalctl -u fail2ban${NC}"
    fi
    read -r -p "Nhan Enter de quay lai..." _
}

_cf_waf_disable() {
    rm -f "${CF_WAF_ATTACH_FILE}" "${CF_WAF_ACTION_FILE}" "${CF_WAF_CONF}"
    systemctl restart fail2ban
    echo "${GREEN}Da tat dong bo Cloudflare WAF.${NC}"
    read -r -p "Nhan Enter de quay lai..." _
}

_cf_waf_test() {
    if [ ! -f "${CF_WAF_CONF}" ]; then
        echo "${RED}Chua bat dong bo. Vui long cau hinh truoc.${NC}"
        read -r -p "Nhan Enter de quay lai..." _
        return
    fi

    local test_ip="203.0.113.251"
    echo "${GREEN}Test: ban IP ${test_ip} len Cloudflare...${NC}"
    bash "${CF_WAF_WRAPPER}" ban "${test_ip}"
    sleep 2

    # shellcheck disable=SC1090
    source "${CF_WAF_CONF}"
    local found
    found=$(curl -s --max-time 15 -G "https://api.cloudflare.com/client/v4/zones/${CF_WAF_ZONE}/firewall/access_rules/rules" \
        -H "Authorization: Bearer ${CF_WAF_TOKEN}" --data-urlencode "configuration.value=${test_ip}" \
        | jq -r '.result[0].id // empty' 2>/dev/null)

    if [ -n "${found}" ]; then
        echo "${GREEN}OK: IP da xuat hien tren Cloudflare WAF. Dang go bo test...${NC}"
        bash "${CF_WAF_WRAPPER}" unban "${test_ip}"
        echo "${GREEN}Da go IP test. Dong bo hoat dong tot.${NC}"
    else
        echo "${RED}Khong thay IP tren Cloudflare. Kiem tra lai token/quyen.${NC}"
    fi
    read -r -p "Nhan Enter de quay lai..." _
}
