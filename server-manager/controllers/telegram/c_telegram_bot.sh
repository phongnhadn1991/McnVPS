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

TELEGRAM_BOT_CONF="${HOSTVN_DIR}/.telegram_bot.conf"
BOT_CTL="${MENU_DIR}/telegram_bot/bot_ctl.sh"

telegram_bot_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== Telegram Bot ==========${NC}"

        if [[ -f "${TELEGRAM_BOT_CONF}" ]]; then
            local bot_mode
            bot_mode=$(grep '^BOT_MODE=' "${TELEGRAM_BOT_CONF}" 2>/dev/null | cut -d= -f2 | tr -d '"')
            echo "${GREEN}Trang thai: DA CAU HINH (mode: ${bot_mode:-menu})${NC}"
        else
            echo "${RED}Trang thai: CHUA CAU HINH${NC}"
        fi

        local pid_file="/var/run/mcnvps-telegram-bot.pid"
        if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
            echo "${GREEN}Bot: DANG CHAY (PID: $(cat "$pid_file"))${NC}"
        else
            echo "${RED}Bot: KHONG CHAY${NC}"
        fi
        echo ""
        echo "${BLUE}1. Cau hinh Bot${NC}"
        echo "${BLUE}2. Start Bot${NC}"
        echo "${BLUE}3. Stop Bot${NC}"
        echo "${BLUE}4. Restart Bot${NC}"
        echo "${BLUE}5. Xem Log${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " tg_choice

        case "$tg_choice" in
            1) _setup_telegram_bot ;;
            2) bash "${BOT_CTL}" start; press_enter_to_continue ;;
            3) bash "${BOT_CTL}" stop; press_enter_to_continue ;;
            4) bash "${BOT_CTL}" restart; press_enter_to_continue ;;
            5) tail -50 /var/log/mcnvps-telegram-bot.log 2>/dev/null || echo "Chua co log"; press_enter_to_continue ;;
            0) return ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}

_setup_telegram_bot() {
    clear_screen
    echo "${GREEN}=== Cau hinh Telegram Bot ===${NC}"
    echo ""
    echo "${BLUE}Buoc 1: Tao Bot tren Telegram${NC}"
    echo "  1. Mo Telegram, tim @BotFather"
    echo "  2. Gui lenh /newbot"
    echo "  3. Dat ten cho bot (vd: McnVPS Bot)"
    echo "  4. Dat username cho bot (vd: mcnvps_bot)"
    echo "  5. BotFather se tra ve BOT_TOKEN (dang: 123456789:ABCdef...)"
    echo ""
    echo "${BLUE}Buoc 2: Lay Chat ID cua ban${NC}"
    echo "  1. Mo Telegram, tim @userinfobot hoac @getidsbot"
    echo "  2. Gui /start — bot se tra ve Chat ID cua ban (vd: 352725269)"
    echo "  3. Neu muon gui thong bao vao group: them bot vao group,"
    echo "     gui 1 tin nhan, Chat ID group la so am (vd: -1001234567890)"
    echo ""

    local bot_token chat_ids bot_mode

    read -rp "Nhap BOT_TOKEN (tu BotFather) [0=thoat]: " bot_token
    [[ -z "$bot_token" || "$bot_token" == "0" ]] && return

    read -rp "Nhap Chat ID (nhieu ID cach nhau boi dau phay): " chat_ids
    [[ -z "$chat_ids" ]] && { msg "$ICON_EXIT Chat ID khong duoc de trong"; press_enter_to_continue; return; }

    echo ""
    echo "${BLUE}Buoc 3: Chon che do hoat dong${NC}"
    echo "  1. notify - Chi gui thong bao khi dich vu chet, dia day (an toan)"
    echo "  2. menu   - Dieu khien server qua Telegram: restart service,"
    echo "              xem domain, VPS info... (chi admin moi duoc thao tac)"
    read -rp "Chon [1/2, mac dinh=1]: " mode_choice

    case "$mode_choice" in
        2) bot_mode="menu" ;;
        *) bot_mode="notify" ;;
    esac

    cat > "${TELEGRAM_BOT_CONF}" <<EOF
BOT_TOKEN="${bot_token}"
ALLOWED_CHAT_IDS="${chat_ids}"
BOT_MODE="${bot_mode}"
EOF
    chmod 600 "${TELEGRAM_BOT_CONF}"

    if ! command -v python3 &>/dev/null || ! python3 -m venv --help &>/dev/null; then
        msg "$ICON_TOOL Dang cai dat Python3 va python3-venv..."
        apt-get update -y >/dev/null 2>&1
        apt-get install -y python3 python3-venv python3-pip >/dev/null 2>&1
    fi

    msg "$ICON_TOOL Dang cai dat dependencies..."
    local bot_dir="${MENU_DIR}/telegram_bot"
    if [[ -d "${bot_dir}/venv" ]]; then
        rm -rf "${bot_dir}/venv"
    fi
    python3 -m venv "${bot_dir}/venv"
    "${bot_dir}/venv/bin/pip" install --upgrade pip >/dev/null 2>&1
    "${bot_dir}/venv/bin/pip" install -r "${bot_dir}/requirements.txt" >/dev/null 2>&1

    chmod +x "${BOT_CTL}"

    msg "$ICON_SUCCESS Cau hinh bot thanh cong!" 'green'
    echo "${GREEN}Mode: ${bot_mode}${NC}"
    echo ""

    if prompt_yes_no "Khoi dong bot ngay?"; then
        bash "${BOT_CTL}" start
    fi

    press_enter_to_continue
}
