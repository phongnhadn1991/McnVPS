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

__add_domain_to_list() {
    local name="$1"
    local note="$2"
    if [[ -z "${seen_domains[$name]}" ]]; then
        seen_domains["$name"]=1
        domains+=( "$name$note" )
    fi
}

list_all_website() {
    local -A seen_domains=()
    local -a domains=()

    if [[ -d "$SITE_AVAILABLE_DIR" ]]; then
        while IFS= read -r -d '' conf; do
            __add_domain_to_list "$(basename "${conf%.conf}")" ""
        done < <(find "$SITE_AVAILABLE_DIR" -maxdepth 1 -type f -name "*.conf" -print0 | sort -z)
    fi

    if [[ -d "$SITE_ALIAS_CONF_DIR" ]]; then
        while IFS= read -r -d '' conf; do
            __add_domain_to_list "$(basename "${conf%.conf}")" " ${GREEN}(Alias)${NC}"
        done < <(find "$SITE_ALIAS_CONF_DIR" -maxdepth 1 -type f -name "*.conf" -print0 | sort -z)
    fi

    if [[ -d "$SITE_REDIRECT_CONF_DIR" ]]; then
        while IFS= read -r -d '' conf; do
            __add_domain_to_list "$(basename "${conf%.conf}")" " ${GREEN}(Redirect)${NC}"
        done < <(find "$SITE_REDIRECT_CONF_DIR" -maxdepth 1 -type f -name "*.conf" -print0 | sort -z)
    fi

    if [[ ${#domains[@]} -eq 0 ]]; then
        msg "${ICON_EXIT} Khong tim thay website nao tren server"
        website_menu
    fi

    print_paginated_list --title "${GREEN}${ICON_GLOBE} Danh sach website${NC}" \
                --items domains --page_size 20 --cols 3 --fallback_cmd 'website_menu'
    press_enter_to_continue; return 0
}
