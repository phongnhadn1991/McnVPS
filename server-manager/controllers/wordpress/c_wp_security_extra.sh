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

if ! declare -f prompt_select_website >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/prompt.sh"
fi

if ! declare -f nginx_reload >/dev/null 2>&1; then
    source "${MENU_DIR}/models/m_nginx.sh"
fi

if ! declare -f format_nginx_config >/dev/null 2>&1; then
    source "${MENU_DIR}/helpers/function.sh"
fi

# ─────────────── 1. Block wp-comments-post.php (nginx level) ───────────────

block_wp_comments() {
    local domain vhost_file
    run_prompt_or_exit prompt_select_website domain 'wordpress_sec_menu' "$WEB_DATA_DIR" 'd' 'wordpress'
    vhost_file="${SITE_AVAILABLE_DIR}/${domain}.conf"

    if grep -q "wp-comments-post.php" "$vhost_file" 2>/dev/null; then
        if prompt_yes_no "Block comment dang bat cho ${domain}. Tat block?"; then
            sed -i '/# BEGIN_BLOCK_COMMENTS/,/# END_BLOCK_COMMENTS/d' "$vhost_file"
            format_nginx_config "$vhost_file"
            nginx_reload
            msg "$ICON_SUCCESS Da tat block comment cho ${domain}" 'green'
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    else
        if prompt_yes_no "Block comment spam cho ${domain}? (Chan wp-comments-post.php tai nginx)"; then
            sed -i "/location ~ \\\\\.php/i\\
    # BEGIN_BLOCK_COMMENTS\\
    location = /wp-comments-post.php {\\
        return 444;\\
    }\\
    # END_BLOCK_COMMENTS" "$vhost_file"
            format_nginx_config "$vhost_file"
            nginx_reload
            msg "$ICON_SUCCESS Da block comment cho ${domain}" 'green'
            echo "${GREEN}wp-comments-post.php bi chan hoan toan o nginx level${NC}"
            echo "${GREEN}Khong ai co the gui comment, ke ca tu dashboard${NC}"
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    fi

    press_enter_to_continue
    wordpress_sec_menu
}

# ─────────────── 2. Kiem tra & xoa user admin la ───────────────

wp_audit_users() {
    local domain base_dir owner php_version
    run_prompt_or_exit prompt_select_website domain 'wordpress_sec_menu' "$WEB_DATA_DIR" 'd' 'wordpress'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    local public_html="${base_dir}/public_html"

    echo ""
    msg "$ICON_TOOL Danh sach user co quyen Administrator:" 'green'
    echo ""
    wp user list --role=administrator --allow-root --path="${public_html}" \
        --format=table --fields=ID,user_login,user_email,user_registered 2>/dev/null

    echo ""
    local admin_count
    admin_count=$(wp user list --role=administrator --allow-root --path="${public_html}" --format=count 2>/dev/null)

    if [[ "$admin_count" -le 1 ]]; then
        msg "$ICON_SUCCESS Chi co 1 admin — binh thuong" 'green'
        press_enter_to_continue; return 0
    fi

    msg "$ICON_WARNING Co ${admin_count} admin users! Kiem tra xem co user la khong"

    echo ""
    read -rp "Nhap ID user muon xoa (0 = bo qua): " del_id
    [[ -z "$del_id" || "$del_id" == "0" ]] && { press_enter_to_continue; return 0; }

    local del_login
    del_login=$(wp user get "$del_id" --field=user_login --allow-root --path="${public_html}" 2>/dev/null)
    if [[ -z "$del_login" ]]; then
        msg "$ICON_EXIT User ID ${del_id} khong ton tai"
        press_enter_to_continue; return 0
    fi

    if prompt_yes_no "Xoa user '${del_login}' (ID: ${del_id})? Bai viet cua user nay se chuyen cho admin chinh"; then
        local main_admin
        main_admin=$(wp user list --role=administrator --allow-root --path="${public_html}" \
            --format=csv --fields=ID 2>/dev/null | tail -n +2 | head -1)

        wp user delete "$del_id" --reassign="$main_admin" --allow-root --path="${public_html}" 2>/dev/null
        msg "$ICON_SUCCESS Da xoa user '${del_login}'" 'green'
    else
        msg "$ICON_EXIT Huy thao tac"
    fi

    press_enter_to_continue
    wordpress_sec_menu
}

# ─────────────── 3. Block REST API registration ───────────────

block_wp_rest_users() {
    local domain vhost_file
    run_prompt_or_exit prompt_select_website domain 'wordpress_sec_menu' "$WEB_DATA_DIR" 'd' 'wordpress'
    vhost_file="${SITE_AVAILABLE_DIR}/${domain}.conf"

    if grep -q "wp-json/wp/v2/users" "$vhost_file" 2>/dev/null; then
        if prompt_yes_no "Block REST API users dang bat cho ${domain}. Tat block?"; then
            sed -i '/# BEGIN_BLOCK_REST_USERS/,/# END_BLOCK_REST_USERS/d' "$vhost_file"
            format_nginx_config "$vhost_file"
            nginx_reload
            msg "$ICON_SUCCESS Da tat block REST API users cho ${domain}" 'green'
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    else
        if prompt_yes_no "Block REST API tao/xem user cho ${domain}?"; then
            sed -i "/location ~ \\\\\.php/i\\
    # BEGIN_BLOCK_REST_USERS\\
    location ~* /wp-json/wp/v2/users {\\
        return 403;\\
    }\\
    # END_BLOCK_REST_USERS" "$vhost_file"
            format_nginx_config "$vhost_file"
            nginx_reload
            msg "$ICON_SUCCESS Da block REST API users cho ${domain}" 'green'
            echo "${GREEN}Chan truy cap /wp-json/wp/v2/users — ngan tao user qua API${NC}"
        else
            msg "$ICON_EXIT Huy thao tac"
        fi
    fi

    press_enter_to_continue
    wordpress_sec_menu
}

# ─────────────── 4. Doi mat khau tat ca admin + reset secret keys ───────────────

wp_reset_all_admin_passwords() {
    local domain base_dir owner php_version
    run_prompt_or_exit prompt_select_website domain 'wordpress_sec_menu' "$WEB_DATA_DIR" 'd' 'wordpress'

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    local public_html="${base_dir}/public_html"

    echo ""
    msg "$ICON_WARNING Chuc nang nay se:"
    echo "  1. Doi mat khau TAT CA admin users"
    echo "  2. Reset WordPress secret keys (logout tat ca session)"
    echo ""

    if ! prompt_yes_no "Tiep tuc? (Tat ca admin phai dung mat khau moi)"; then
        press_enter_to_continue; return 0
    fi

    echo ""
    local admin_ids
    admin_ids=$(wp user list --role=administrator --allow-root --path="${public_html}" \
        --format=csv --fields=ID 2>/dev/null | tail -n +2)

    for uid in $admin_ids; do
        local ulogin new_pass
        ulogin=$(wp user get "$uid" --field=user_login --allow-root --path="${public_html}" 2>/dev/null)
        new_pass=$(gen_pass)
        wp user update "$uid" --user_pass="$new_pass" --allow-root --path="${public_html}" 2>/dev/null
        echo "${GREEN}User: ${ulogin} (ID: ${uid}) -> Mat khau moi: ${new_pass}${NC}"
    done

    echo ""
    msg "$ICON_TOOL Dang reset WordPress secret keys..."
    wp config shuffle-salts --allow-root --path="${public_html}" 2>/dev/null
    msg "$ICON_SUCCESS Da reset secret keys — tat ca session bi logout" 'green'

    echo ""
    msg "$ICON_SUCCESS Hoan tat! Luu mat khau moi o tren." 'green'

    press_enter_to_continue
    wordpress_sec_menu
}
