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

CURRENT_DATE="$(date +"%d-%m-%Y %H:%M")"
IP_ADDRESS=$(ip -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)

# shellcheck disable=SC1090
source "/var/mcnvps/.mcnvps.conf" || {
    msg "$ICON_EXIT Khong the load file cau hinh"
    exit 1
}

if [[ -z "$notify_status" || "$notify_status" == 'no' ]]; then
    exit 0
fi

if [[ -z "${notify_telegram_bot_token}" || -z "${notify_telegram_chat_id}"  ]]; then
    exit 0
fi

if [ -z "$(which jq)" ]; then
    apt-get install jq -y
fi

send_telegram_message() {
    local message="$1"
    local bot_token="${notify_telegram_bot_token}"
    local chat_id="${notify_telegram_chat_id}"
    local url="https://api.telegram.org/bot${bot_token}/sendMessage"

    local payload
    payload=$(jq -n --arg chat_id "$chat_id" --arg text "$message" '{chat_id: $chat_id, text: $text, parse_mode: "HTML"}')

    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$url")

    if [[ $(echo "$response" | jq -r '.ok') != "true" ]]; then
        echo "Khong the gui tin nhan Telegram: $(echo "$response" | jq -r '.description')"
        return 1
    fi

    return 0
}

check_service() {
    local service="$1"
    if ! systemctl is-active --quiet "$service"; then
        send_telegram_message "⚠️ [${CURRENT_DATE}] [Server ${IP_ADDRESS}] - Service <b>${service}</b> đã bị <b>STOP</b>"
    fi
}

check_cpu_load() {
    local load threshold cores
    cores=$(nproc)
    threshold=$((cores * 0))
    load=$(awk '{print int($1)}' /proc/loadavg)
    if (( load > threshold )); then
        send_telegram_message "⚠️ [${CURRENT_DATE}] [Server ${IP_ADDRESS}] - CPU load cao: <b>${load}</b> (ngưỡng ${threshold})"
    fi
}

check_ram() {
    local used total percent
    read -r _ total used _ < <(free -m | awk '/^Mem:/ {print $1, $2, $3, $4}')
    percent=$((used * 100 / total))
    if (( percent > 90 )); then
        send_telegram_message "⚠️ [${CURRENT_DATE}] [Server ${IP_ADDRESS}] - RAM sử dụng quá cao: <b>${percent}%</b>"
    fi
}

check_inode() {
    local inode_usage
    inode_usage="$(df -hi | awk '{if ($6 == "/") { print $5 }}' | head -1 | cut -d'%' -f1)"

    if (( inode_usage > 90 )); then
        send_telegram_message "⚠️ [${CURRENT_DATE}] [Server ${IP_ADDRESS}] - Inode sử dụng quá cao: <b>${inode_usage}%</b>"
    fi
}

check_disk() {
    local disk_usage
    disk_usage="$(df -h | awk '{if ($6 == "/") { print $5 }}' | head -1 | cut -d'%' -f1)"

    if (( disk_usage > 90 )); then
        send_telegram_message "⚠️ [${CURRENT_DATE}] [Server ${IP_ADDRESS}] - Disk sử dụng quá cao: <b>${disk_usage}%</b>"
    fi
}

check_php_fpm_services() {
    local services
    services=$(systemctl list-unit-files --type=service | awk '/php[0-9]+\.[0-9]+-fpm/ {print $1}' | sort -u)

    for svc in $services; do
        local version pool_dir
        version=$(echo "$svc" | grep -oP 'php\K[0-9]+\.[0-9]+')
        pool_dir="/etc/php/${version}/fpm/pool.d"

        if [[ -d "$pool_dir" ]]; then
            local valid_pool=0
            for f in "$pool_dir"/*.conf; do
                [[ -e "$f" ]] || continue
                pool_name=$(basename "$f" .conf)

                if [[ "$pool_name" =~ ^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$ ]]; then
                    valid_pool=1
                    break
                fi
            done

            if [[ $valid_pool -eq 1 ]]; then
                if ! systemctl is-active --quiet "$svc"; then
                    send_telegram_message "⚠️ [${CURRENT_DATE}] [Server ${IP_ADDRESS}] - <b>${svc}</b> đang <b>STOP</b>"
                fi
            fi
        fi
    done
}

run_health_check() {
    check_service nginx
    check_service mariadb
    check_php_fpm_services

    check_cpu_load
    check_ram
    check_inode
    check_disk
}

run_health_check
