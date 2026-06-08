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

if ! declare -f toggle_wp_config >/dev/null 2>&1; then
    source "${MENU_DIR}/controllers/wordpress/c_base_controller.sh"
fi

wp_debug_mode() {
    toggle_wp_config \
            --constant "WP_DEBUG" \
            --enable_msg "Da bat che do debug cua WordPress tren website" \
            --disable_msg "Da tat che do debug cua WordPress tren website" \
            --enable_prompt "Ban muon bat debug mode" \
            --disable_prompt "Ban muon tat debug mode" \
            --callback_menu "wordpress_menu"
}

wp_cron() {
    toggle_wp_config \
            --constant "DISABLE_WP_CRON" \
            --enable_msg "Da tat WP Cron tren website" \
            --disable_msg "Da bat WP Cron tren website" \
            --enable_prompt "Ban muon tat WP Cron" \
            --disable_prompt "Ban muon bat WP Cron" \
            --callback_menu "wordpress_menu"
}
