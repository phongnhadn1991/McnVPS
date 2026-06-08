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

if ! declare -f nginx_reload >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_nginx.sh"
fi

if ! declare -f toggle_wp_vhost >/dev/null 2>&1; then
    source "${MENU_DIR}/controllers/wordpress/c_base_controller.sh"
fi

block_php_in_wp_content() {
    toggle_wp_vhost --conf_file "block-php-wp-content.conf" \
        --enable_prompt "Ban muon chan truy cap PHP file trong thu muc wp-content ?" \
        --disable_prompt "Ban muon cho phep truy cap PHP file trong thu muc wp-content ?"
}

block_php_in_wp_plugins() {
    toggle_wp_vhost --conf_file "block-php-in-wp-plugins.conf" \
        --enable_prompt "Ban muon chan truy cap PHP file trong thu muc plugins ?" \
        --disable_prompt "Ban muon cho phep truy cap PHP file trong thu muc plugins ?"
}

block_php_in_wp_themes() {
    toggle_wp_vhost --conf_file "block-php-in-wp-themes.conf" \
        --enable_prompt "Ban muon chan truy cap PHP file trong thu muc themes ?" \
        --disable_prompt "Ban muon cho phep truy cap PHP file trong thu muc themes ?"
}

block_user_api() {
    toggle_wp_vhost --conf_file "block-user-api.conf" \
            --enable_prompt "Ban muon chan truy cap User API ?" \
            --disable_prompt "Ban muon cho phep truy cap User API ?"
}

block_xmlrpc () {
    toggle_wp_vhost --conf_file "block-wp-xmlrpc.conf" \
            --enable_prompt "Ban muon chan truy cap xmlrpc.php ?" \
            --disable_prompt "Ban muon cho phep truy cap xmlrpc.php ?"
}

block_author_scan () {
    toggle_wp_vhost --conf_file "block-author-scan.conf" \
            --enable_prompt "Ban muon chan scan author ?" \
            --disable_prompt "Ban muon cho phep scan author ?"
}

disable_edit_plugins_theme() {
    toggle_wp_config \
        --constant "DISALLOW_FILE_EDIT" \
        --enable_msg "Da chan chinh sua file plugins/themes trong wp-admin cho website" \
        --disable_msg "Da cho phep chinh sua file plugins/themes trong wp-admin cho website" \
        --enable_prompt "Ban muon chan chinh sua file plugins/themes trong wp-admin cho website" \
        --disable_prompt "Ban muon cho phep chinh sua file plugins/themes trong wp-admin cho website" \
        --callback_menu "wordpress_sec_menu"
}

disable_install_plugins_theme() {
    toggle_wp_config \
        --constant "DISALLOW_FILE_MODS" \
        --enable_msg "Da chan cai dat plugins/themes trong wp-admin cho website" \
        --disable_msg "Da cho phep cai dat plugins/themes trong wp-admin cho website" \
        --enable_prompt "Ban muon chan cai dat plugins/themes trong wp-admin cho website" \
        --disable_prompt "Ban muon cho phep cai dat plugins/themes trong wp-admin cho website" \
        --callback_menu "wordpress_sec_menu"
}
