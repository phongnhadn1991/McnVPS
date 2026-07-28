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

antivirus_menu() {
    while true; do
        clear_screen
        echo "${BLUE}========== Antivirus ==========${NC}"

        if command -v clamscan &>/dev/null; then
            echo "${GREEN}ClamAV: DA CAI DAT${NC}"
        elif command -v imunify-antivirus &>/dev/null; then
            echo "${GREEN}ImunifyAV: DA CAI DAT${NC}"
        else
            echo "${RED}Chua cai dat Antivirus${NC}"
        fi
        echo ""
        echo "${BLUE}1. Cai dat ClamAV${NC}"
        echo "${BLUE}2. Cai dat ImunifyAV${NC}"
        echo "${BLUE}3. Quet Malware (ClamAV)${NC}"
        echo "${BLUE}4. Go cai dat Antivirus${NC}"
        echo "${RED}----------------------------------${NC}"
        echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"
        read -rp "${BLUE}Chon mot tuy chon:${NC} " av_choice

        case "$av_choice" in
            1) _install_clamav ;;
            2) _install_imunifyav ;;
            3) _scan_malware ;;
            4) _uninstall_av ;;
            0) return ;;
            *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}"; sleep 1 ;;
        esac
    done
}

_install_clamav() {
    if command -v imunify-antivirus &>/dev/null; then
        msg "$ICON_EXIT ImunifyAV da duoc cai dat. Vui long go ImunifyAV truoc khi cai ClamAV"
        press_enter_to_continue; return 0
    fi

    if command -v clamscan &>/dev/null; then
        msg "$ICON_WARNING ClamAV da duoc cai dat roi"
        press_enter_to_continue; return 0
    fi

    local ram_kb
    ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    if [[ "$ram_kb" -lt 1048576 ]]; then
        msg "$ICON_EXIT ClamAV yeu cau toi thieu 1GB RAM. VPS hien tai: $((ram_kb / 1024))MB"
        press_enter_to_continue; return 0
    fi

    if ! prompt_yes_no "Cai dat ClamAV? (Can toi thieu 1GB RAM)"; then
        return 0
    fi

    msg "$ICON_TOOL Dang cai dat ClamAV..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y clamav clamav-daemon >/dev/null 2>&1

    if ! command -v clamscan &>/dev/null; then
        msg "$ICON_EXIT Cai dat ClamAV that bai"
        press_enter_to_continue; return 0
    fi

    systemctl stop clamav-freshclam 2>/dev/null

    if [[ -f /etc/clamav/freshclam.conf ]]; then
        if ! grep -q "malware.expert" /etc/clamav/freshclam.conf; then
            cat >> /etc/clamav/freshclam.conf <<'EOF'

# Custom malware databases
DatabaseCustomURL https://cdn.malware.expert/malware.expert.ndb
DatabaseCustomURL https://cdn.malware.expert/malware.expert.hdb
DatabaseCustomURL https://cdn.malware.expert/malware.expert.ldb
DatabaseCustomURL https://cdn.malware.expert/malware.expert.fp
EOF
        fi
    fi

    msg "$ICON_TOOL Dang cap nhat virus database..."
    freshclam 2>/dev/null

    systemctl start clamav-freshclam 2>/dev/null
    systemctl enable clamav-freshclam 2>/dev/null

    msg "$ICON_SUCCESS Cai dat ClamAV thanh cong!" 'green'
    press_enter_to_continue
}

_install_imunifyav() {
    if command -v clamscan &>/dev/null; then
        msg "$ICON_EXIT ClamAV da duoc cai dat. Vui long go ClamAV truoc khi cai ImunifyAV"
        press_enter_to_continue; return 0
    fi

    if command -v imunify-antivirus &>/dev/null; then
        msg "$ICON_WARNING ImunifyAV da duoc cai dat roi"
        press_enter_to_continue; return 0
    fi

    if ! prompt_yes_no "Cai dat ImunifyAV?"; then
        return 0
    fi

    msg "$ICON_TOOL Dang cai dat ImunifyAV..."

    mkdir -p /etc/sysconfig/imunify360
    cat > /etc/sysconfig/imunify360/integration.conf <<'EOF'
[paths]
ui_path = /var/www/html/imav/
EOF

    wget -qO /tmp/imav-deploy.sh https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh
    if [[ -f /tmp/imav-deploy.sh ]]; then
        bash /tmp/imav-deploy.sh
        rm -f /tmp/imav-deploy.sh
        msg "$ICON_SUCCESS Cai dat ImunifyAV thanh cong!" 'green'
    else
        msg "$ICON_EXIT Tai file cai dat that bai"
    fi

    press_enter_to_continue
}

_scan_malware() {
    if ! command -v clamscan &>/dev/null; then
        msg "$ICON_EXIT ClamAV chua duoc cai dat. Vui long cai dat truoc"
        press_enter_to_continue; return 0
    fi

    if ! prompt_yes_no "Quet malware trong /home? (Co the mat vai phut)"; then
        return 0
    fi

    msg "$ICON_TOOL Dang cap nhat virus database..."
    systemctl stop clamav-freshclam 2>/dev/null
    freshclam 2>/dev/null
    systemctl start clamav-freshclam 2>/dev/null

    msg "$ICON_TOOL Dang quet malware..."
    echo ""
    clamscan --infected --recursive /home 2>/dev/null
    echo ""
    msg "$ICON_SUCCESS Quet hoan tat!" 'green'

    press_enter_to_continue
}

_uninstall_av() {
    clear_screen
    echo "${BLUE}========== Go cai dat Antivirus ==========${NC}"
    echo "${BLUE}1. Go ClamAV${NC}"
    echo "${BLUE}2. Go ImunifyAV${NC}"
    echo "${RED}----------------------------------${NC}"
    echo "${GREEN}0.${NC} $ICON_BACK ${GREEN}Quay lai${NC}"
    read -rp "${BLUE}Chon mot tuy chon:${NC} " uninstall_choice

    case "$uninstall_choice" in
        1)
            if ! command -v clamscan &>/dev/null; then
                msg "$ICON_EXIT ClamAV chua duoc cai dat"
            elif prompt_yes_no "Go cai dat ClamAV?"; then
                apt-get remove -y clamav clamav-daemon >/dev/null 2>&1
                apt-get autoremove -y >/dev/null 2>&1
                msg "$ICON_SUCCESS Da go ClamAV" 'green'
            fi
            ;;
        2)
            if ! command -v imunify-antivirus &>/dev/null; then
                msg "$ICON_EXIT ImunifyAV chua duoc cai dat"
            elif prompt_yes_no "Go cai dat ImunifyAV?"; then
                wget -qO /tmp/imav-deploy.sh https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh
                bash /tmp/imav-deploy.sh --uninstall 2>/dev/null
                rm -f /tmp/imav-deploy.sh
                msg "$ICON_SUCCESS Da go ImunifyAV" 'green'
            fi
            ;;
        0) return ;;
        *) echo "${RED}$ICON_EXIT Lua chon khong hop le!${NC}" ;;
    esac

    press_enter_to_continue
}
