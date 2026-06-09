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

if ! declare -f extract_key_value >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

MCNVPS_GITHUB_ZIP="https://github.com/phongnhadn1991/McnVPS/raw/master/scripts/server-manager.zip"

update_menu() {
    msg "$ICON_TOOL Dang tai server-manager moi nhat tu GitHub..."

    cd_dir "${HOSTVN_DIR}"
    rm -f server-manager.zip

    wget_with_retry --url "${MCNVPS_GITHUB_ZIP}" --output "server-manager.zip" || {
        msg "$ICON_EXIT Khong the tai server-manager.zip. Vui long kiem tra ket noi!" "red"
        press_enter_to_continue; return 0
    }

    if [[ ! -f "server-manager.zip" ]]; then
        msg "$ICON_EXIT Tai file that bai!" "red"
        press_enter_to_continue; return 0
    fi

    rm -rf server-manager
    unzip -q server-manager.zip && rm -f server-manager.zip
    chmod +x server-manager/* server-manager/*/* server-manager/*/*/* 2>/dev/null
    dos2unix server-manager/* server-manager/*/* server-manager/*/*/* 2>/dev/null

    msg "$ICON_CHECK Cap nhat McnVPS thanh cong!" "green"
    press_enter_to_continue; return 0
}
