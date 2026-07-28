#!/bin/bash

# McnVPS Telegram Bot controller (start/stop/restart/status)

BOT_DIR="/var/mcnvps/server-manager/telegram_bot"
VENV_DIR="${BOT_DIR}/venv"
PID_FILE="/var/run/mcnvps-telegram-bot.pid"
LOG_FILE="/var/log/mcnvps-telegram-bot.log"

_ensure_venv() {
    if [[ ! -d "${VENV_DIR}" ]] || [[ ! -f "${VENV_DIR}/bin/python" ]]; then
        if ! python3 -m venv --help &>/dev/null; then
            echo "Dang cai dat python3-venv..."
            apt-get update -y >/dev/null 2>&1
            apt-get install -y python3-venv >/dev/null 2>&1
        fi
        echo "Dang tao Python virtual environment..."
        rm -rf "${VENV_DIR}"
        python3 -m venv "${VENV_DIR}"
        "${VENV_DIR}/bin/pip" install --upgrade pip >/dev/null 2>&1
        "${VENV_DIR}/bin/pip" install -r "${BOT_DIR}/requirements.txt" >/dev/null 2>&1
    fi
}

_is_running() {
    [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null
}

start_bot() {
    if _is_running; then
        echo "Bot dang chay (PID: $(cat "${PID_FILE}"))"
        return 0
    fi
    _ensure_venv
    cd "${BOT_DIR}" || exit 1
    nohup "${VENV_DIR}/bin/python" bot.py >> "${LOG_FILE}" 2>&1 &
    echo $! > "${PID_FILE}"
    echo "Bot da khoi dong (PID: $!)"
}

stop_bot() {
    if ! _is_running; then
        echo "Bot khong chay"
        rm -f "${PID_FILE}"
        return 0
    fi
    kill "$(cat "${PID_FILE}")" 2>/dev/null
    rm -f "${PID_FILE}"
    echo "Bot da dung"
}

restart_bot() {
    stop_bot
    sleep 1
    start_bot
}

status_bot() {
    if _is_running; then
        echo "Bot dang chay (PID: $(cat "${PID_FILE}"))"
    else
        echo "Bot khong chay"
    fi
}

case "${1}" in
    start)   start_bot ;;
    stop)    stop_bot ;;
    restart) restart_bot ;;
    status)  status_bot ;;
    *)       echo "Usage: $0 {start|stop|restart|status}" ;;
esac
