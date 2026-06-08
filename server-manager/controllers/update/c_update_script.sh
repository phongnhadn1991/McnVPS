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

update_menu() {
    local script_current_major_version script_current_minor_version version_response
    local script_new_major_version script_new_minor_version

    source "${HOSTVN_DIR}/.mcnvps.conf"

    local current_version="${script_version}"

    script_current_major_version=$(echo "${current_version}" | cut -d'.' -f1)
    # shellcheck disable=SC2034
    script_current_minor_version=$(echo "${current_version}" | cut -d'.' -f2)

    version_response=$(curl_get_with_retry --url "${GET_VERSION_LINK}") || {
       msg "$ICON_EXIT Failed to get version information from $GET_VERSION_LINK"
       press_enter_to_continue; return 0
    }

    extract_key_value "$version_response" "script_version"
    script_new_version="$KEY_VALUE_REPLY"

    if [ -z "$script_version" ]; then
       msg "$ICON_EXIT Khong the lay duoc thong tin phien ban moi."
       press_enter_to_continue; return 0
    fi

    script_new_major_version=$(echo "${script_new_version}" | cut -d'.' -f1)
    # shellcheck disable=SC2034
    script_new_minor_version=$(echo "${script_new_version}" | cut -d'.' -f2)

    if [[ $script_new_major_version -gt $script_current_major_version || "$script_new_minor_version" != "$script_current_minor_version" ]]; then
        cd_dir "${HOSTVN_DIR}"
        rm -f update.bash

        wget_with_retry --url "${UPDATE_LINK}/update.bash" --output "update.bash"
        bash update.bash || {
            msg "$ICON_EXIT Cap nhat khong thanh cong. Vui long thu lai!" "red"
            rm -f update.bash
            press_enter_to_continue; return 0
        }

        sed -i '/script_version/d' "${HOSTVN_DIR}/.mcnvps.conf"
        echo "script_version='${script_new_version}'" >>"${HOSTVN_DIR}/.mcnvps.conf"
        rm -f update.bash
        press_enter_to_continue; return 0
    else
        msg "$ICON_SUCCESS Ban dang su dung phien ban moi nhat: ${current_version}" "green"
        main_menu
    fi
}
