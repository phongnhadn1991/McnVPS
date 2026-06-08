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

if ! declare -f validate_port_list >/dev/null 2>&1; then
    source "${MENU_DIR}/validate/rule.sh"
fi

_fw_require_active() {
    if [ "$(systemctl is-active nftables)" != 'active' ]; then
        msg "$ICON_ERROR Firewall chua duoc bat!" 'red'
        firewall_menu
        return 1
    fi

    press_enter_to_continue; return 0
}

_block_ip() {
    local input="$1"
    local block_ips

    IFS=',' read -ra block_ips <<< "$input"

    for ip in "${block_ips[@]}"; do
        if is_ipv4 "$ip"; then
            nft add element ip filter blocked_ips "{ $ip }" >/dev/null 2>&1
        elif is_ipv6 "$ip"; then
            nft add element ip6 filter blocked_ips "{ $ip }" >/dev/null 2>&1
        fi
    done
}

_unblock_ip() {
    local input="$1"
    local jails=()
    local unblock_ips

    if systemctl is-active --quiet fail2ban; then
        mapfile -t jails < <(fail2ban-client status | grep -i 'Jail list:' | sed -E 's/.*Jail list:[[:space:]]*//; s/,/ /g')
    fi

    IFS=',' read -ra unblock_ips <<< "$input"

    for ip in "${unblock_ips[@]}"; do
        if is_ipv4 "$ip"; then
            nft delete element ip filter blocked_ips "{ $ip }" >/dev/null 2>&1
        elif is_ipv6 "$ip"; then
            nft delete element ip6 filter blocked_ips "{ $ip }" >/dev/null 2>&1
        fi

        if [ "${#jails[@]}" -gt 0 ]; then
            for jail in "${jails[@]}"; do
                jail="$(trim "$jail")"
                if [ -n "$jail" ]; then
                    fail2ban-client set "$jail" unbanip "$ip" >/dev/null 2>&1
                fi
            done
        fi
    done
}

_update_nft_ruleset() {
    mv /etc/nftables.conf /etc/nftables.conf.bak
    nft list ruleset > /etc/nftables.conf
}

_fw_process_items() {
    local type="$1" action="$2" prompt_func="$3"
    local input protocol

    _fw_require_active || return

    [ "$type" = "port" ] && run_prompt_or_exit prompt_select_fw_protocol protocol "firewall_menu"

    if [ -n "$prompt_func" ]; then
        run_prompt_or_exit "$prompt_func" input "firewall_menu"
    fi

    case "$type" in
        port)
            case "$action" in
                allow)
                    nft add element ip filter allowed_"${protocol}"_ports \{ "$input" \} >/dev/null 2>&1
                    nft add element ip6 filter allowed_"${protocol}"_ports \{ "$input" \} >/dev/null 2>&1
                    _update_nft_ruleset
                    msg "$ICON_SUCCESS Port $input da duoc mo!" 'green'
                    ;;
                deny)
                    nft delete element ip filter allowed_"${protocol}"_ports \{ "$input" \} >/dev/null 2>&1
                    nft delete element ip6 filter allowed_"${protocol}"_ports \{ "$input" \} >/dev/null 2>&1
                    _update_nft_ruleset
                    msg "$ICON_SUCCESS Port $input da bi chan!" 'green'
                    ;;
            esac
            ;;
        ip)
            case "$action" in
                block)
                    _block_ip "$input"
                    _update_nft_ruleset
                    msg "$ICON_SUCCESS IP $input da bi chan!" 'green'
                    ;;
                unblock)
                    _unblock_ip "$input"
                    _update_nft_ruleset
                    msg "$ICON_SUCCESS Da bo chan IP: $input!" 'green'
                    ;;
            esac
            ;;
    esac

    firewall_menu
}

stop_start_firewall() {
    if [[ "$(systemctl is-active nftables)" == 'active' ]]; then
        if prompt_yes_no "Ban muon tat Firewall ?"; then
            systemctl stop nftables
            systemctl disable nftables
            systemctl stop fail2ban
            systemctl disable fail2ban
            msg "$ICON_SUCCESS Firewall da duoc tat!" 'green'
        else
            msg "$ICON_EXIT Huy thao tac!"
        fi
    else
        if prompt_yes_no "Ban muon bat Firewall ?"; then
            systemctl restart nftables
            systemctl enable nftables
            systemctl restart fail2ban
            systemctl enable fail2ban
            msg "$ICON_SUCCESS Firewall da duoc bat!" 'green'
        else
            msg "$ICON_EXIT Huy thao tac!"
        fi
    fi

    firewall_menu
}

fw_open_port()   { _fw_process_items "port" "allow" prompt_fw_port_input; }
fw_block_port()  { _fw_process_items "port" "deny"  prompt_fw_port_input; }
fw_block_ip()    { _fw_process_items "ip"   "block"  prompt_fw_ip_input; }
fw_unblock_ip()  { _fw_process_items "ip" "unblock" prompt_fw_ip_input; }
