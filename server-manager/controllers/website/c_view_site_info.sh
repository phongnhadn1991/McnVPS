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

view_website_details() {
    local domain
    run_prompt_or_exit prompt_select_website domain "website_menu"

    local db_user
    local db_pass
    local db_name
    local base_dir
    local website_source
    local php_version
    local php_post_max_size
    local php_upload_max_filesize
    local php_memory_limit
    local sftp_user
    local sftp_pass

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        exit 1
    }

    printf "\n"
    echo "${GREEN}Duoi day la thong tin Website${NC} ${RED}$domain${NC}"
    echo "${GREEN}-----------------------------------${NC}"
    echo "${GREEN}MySQL User               :${NC} ${RED}$db_user${NC}"
    echo "${GREEN}MySQL Password           :${NC} ${RED}$db_pass${NC}"
    echo "${GREEN}Database name            :${NC} ${RED}$db_name${NC}"
    echo ""
    echo "${GREEN}Web basedir              :${NC} ${RED}$base_dir${NC}"
    echo "${GREEN}Website source           :${NC} ${RED}$website_source${NC}"
    echo ""
    echo "${GREEN}PHP Version              :${NC} ${RED}$php_version${NC}"
    echo "${GREEN}PHP post max size        :${NC} ${RED}$php_post_max_size M${NC}"
    echo "${GREEN}PHP upload max file size :${NC} ${RED}$php_upload_max_filesize M${NC}"
    echo "${GREEN}PHP memory limit         :${NC} ${RED}$php_memory_limit M${NC}"

    if [[ -n "$sftp_user" ]]; then
        echo ""
        echo "${GREEN}--- SFTP ---${NC}"
        echo "${GREEN}SFTP Host                :${NC} ${RED}${IP_ADDRESS}${NC}"
        echo "${GREEN}SFTP Port                :${NC} ${RED}22${NC}"
        echo "${GREEN}SFTP User                :${NC} ${RED}$sftp_user${NC}"
        echo "${GREEN}SFTP Password            :${NC} ${RED}$sftp_pass${NC}"
        echo "${GREEN}SFTP Directory           :${NC} ${RED}/${domain}/public_html${NC}"
    fi

    if [[ "$website_source" == "wordpress" && -f "${base_dir}/public_html/wp-config.php" ]]; then
        echo ""
        echo "${GREEN}--- WordPress Admin ---${NC}"
        local wp_token wp_admin_login wp_site_url wp_login_file wp_login_url
        wp_token=$(openssl rand -hex 16)
        wp_admin_login=$(cd "${base_dir}/public_html" && wp --allow-root user list --role=administrator --fields=user_login --format=csv 2>/dev/null | tail -n +2 | head -1)
        wp_site_url=$(cd "${base_dir}/public_html" && wp --allow-root option get siteurl 2>/dev/null)
        wp_login_file="${base_dir}/public_html/mcn_login_${wp_token}.php"

        cat > "$wp_login_file" << 'PHPEOF'
<?php
require_once dirname(__FILE__).'/wp-load.php';
$users = get_users(['role'=>'administrator','number'=>1]);
if (!empty($users)) {
    wp_set_auth_cookie($users[0]->ID, true);
}
unlink(__FILE__);
wp_redirect(admin_url());
exit;
PHPEOF

        chown "${owner}:${owner}" "$wp_login_file" 2>/dev/null
        chmod 644 "$wp_login_file"

        wp_login_url="${wp_site_url}/mcn_login_${wp_token}.php"

        if [[ -n "$wp_admin_login" ]]; then
            echo "${GREEN}WP Admin User            :${NC} ${RED}${wp_admin_login}${NC}"
        fi
        echo "${GREEN}Dang nhap nhanh (1 lan)  :${NC} ${RED}${wp_login_url}${NC}"
    fi

    press_enter_to_continue; return 0
}
