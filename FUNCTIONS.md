# McnVPS Server Manager — Bản đồ chức năng

## Changelog

| Ngày | Thay đổi |
|------|----------|
| 2026-06-08 | Khởi tạo McnVPS từ hostvn script, đổi toàn bộ branding |
| 2026-06-08 | Sub-menu: số `0` = Quay lại, bỏ Thoát (giữ Thoát ở main menu) |
| 2026-06-08 | Thêm `create_sftp_user` / `delete_sftp_user` vào `m_linux_user.sh` |
| 2026-06-08 | `c_add.sh`: tự động tạo SFTP user khi thêm website mới |
| 2026-06-08 | `c_view_site_info.sh`: hiển thị thông tin SFTP trong xem thông tin website |
| 2026-06-08 | `helpers/prompt.sh`: bỏ `countdown 3` khi huỷ thao tác → quay về menu ngay |
| 2026-06-08 | Controllers: đổi `exit 0` → `return 0` để không thoát khỏi menu |
| 2026-06-08 | `helpers/function.sh`: thêm `press_enter_to_continue` — chờ Enter trước khi quay menu |
| 2026-06-08 | `m_website.sh` `change_website_domain`: fix rename user (dùng `usermod -l` thay vì tạo mới), rename SFTP user, rename DB + DB user, fix `base_dir` sai biến, xóa SSL cert thư mục cũ, cập nhật đầy đủ settings file |
| 2026-06-08 | `m_website.sh` `_change_site_domain_success`: đổi `exit 0` → `press_enter_to_continue` để không thoát khỏi menu sau khi đổi domain thành công |
| 2026-06-08 | `m_php.sh`: đổi `exit 0` → `press_enter_to_continue; return 0` sau khi cài PHP thành công. Giữ nguyên `exit 0` ở `m_ssl.sh` (lock file cronjob), `cronjob/service_notify.bash` (script nền), `main_menu.sh` (nút Thoát) |
| 2026-06-08 | `c_clone.sh`: fix lỗi sed SSL cert (dùng `s\|...\|` thay vì `/a\`), thêm tạo SFTP user cho domain clone, lưu sftp vào settings, hiển thị thông tin sau clone |
| 2026-06-08 | `c_clone.sh`: fix nginx test thất bại do sock PHP chưa tồn tại — restart PHP-FPM trước khi clone vhost; tạo thư mục logs trước khi `nginx -t` |
| 2026-06-09 | `c_view_site_info.sh`: thêm section "WordPress Admin" — hiển thị username admin và link đăng nhập nhanh 1 lần (tạo file PHP tạm dùng `wp_set_auth_cookie`, file tự xóa sau khi click, không thay đổi mật khẩu cũ) |
| 2026-06-09 | `c_view_site_info.sh`: bỏ section WordPress Admin dùng `get_password_reset_key` (yêu cầu đặt pass mới) → thay bằng file PHP tạm token random, click 1 lần vào thẳng wp-admin, file tự xóa |
| 2026-06-09 | VPS Tools > Thông báo Telegram: đã cấu hình bot token + chat ID, test gửi tin nhắn thành công — tự động cảnh báo khi CPU/RAM/disk quá ngưỡng hoặc service down |
| 2026-06-09 | `controllers/update/c_update_script.sh`: fix Update Script — bỏ logic check version qua `scripts.mcnvps.net` (domain chưa tồn tại), thay bằng download thẳng `server-manager.zip` từ GitHub |
| 2026-06-09 | `models/m_website.sh` `change_website_domain`: fix SFTP — xóa SFTP user cũ và tạo SFTP user mới cho domain mới, cập nhật `sftp_user`/`sftp_pass` vào settings.conf |
| 2026-06-09 | `controllers/backup/c_backup_site.sh`: thêm chức năng **Backup thủ công từng site** — chọn domain → backup source (tar.gz) + DB (sql.gz) vào `/backup/<domain>/<datetime>/` |
| 2026-06-09 | `controllers/backup/c_restore_site.sh`: thêm chức năng **Restore thủ công từng site** — chọn domain → liệt kê bản backup local → chọn ngày → chọn loại restore (full/source/database); tự động cập nhật `wp-config.php` (DB_NAME/DB_USER/DB_PASSWORD); nếu restore sang domain mới thì `wp search-replace` toàn bộ DB (cả http lẫn https); nếu cùng domain thì chỉ update `siteurl`/`home` |
| 2026-06-09 | `routes/r_backup.sh`: thêm menu item 3 (Backup thủ công) và 4 (Restore thủ công) vào backup_menu |
| 2026-06-09 | `controllers/website/c_deploy_website.sh`: thêm chức năng **Deploy Website (option 15)** — upload `source.tar.gz` + `database.sql.gz` vào `public_html` qua SFTP, vào menu chọn Deploy → script tự giải nén, import DB, cập nhật wp-config.php, search-replace URL nếu đổi domain, fix permissions, xóa file backup sau khi xong |
| 2026-06-08 | `c_change_domain.sh`: bỏ `press_enter_to_continue` thừa (đã có trong `_change_site_domain_success`) — tránh bấm Enter 2 lần |
| 2026-06-08 | `m_website.sh` `_change_site_domain_success`: hiển thị thông tin đầy đủ sau đổi domain (URL, DB, SFTP, PHP) |
| 2026-06-08 | `m_website.sh` `change_website_domain`: **REVERTED về code gốc hostvn** — quá nhiều edge case (user/group rename, DB rename, owner_folder conflict). Chỉ giữ fix `press_enter_to_continue` thay `exit 0`. Workflow thay thế: clone domain mới → xóa domain cũ | khi group đã bị đổi tên trước, thêm fallback `groupadd` + `usermod -g` để đảm bảo group luôn tồn tại đúng tên |
| 2026-06-08 | `m_website.sh` `change_website_domain`: fix thứ tự — rename user (`usermod -l`) phải chạy TRƯỚC `create_php_pool`, vì PHP pool cần user tồn tại để `restart_specific_php_ver` pass |
| 2026-06-09 | `helpers/php_variables.sh`: thêm biến `OPCACHE_JIT_BUFFER` và `OPCACHE_STRINGS_BUFFER` vào `memory_calculation()` — scale theo RAM (JIT: 32-256MB, strings: 8-32MB) |
| 2026-06-09 | `models/m_php.sh` `_install_php_ext`: bật OPcache JIT tự động cho PHP >= 8.1 (`opcache.jit=tracing` + `jit_buffer_size` scale theo RAM), PHP < 8.1 giữ `jit=disable`. Thay `interned_strings_buffer` cố định 8MB bằng biến `${OPCACHE_STRINGS_BUFFER}` scale theo RAM |
| 2026-06-08 | `m_website.sh` `change_website_domain`: fix `mv` owner_folder bị lọt vào bên trong khi thư mục đích đã tồn tại (same owner_folder khác domain) — kiểm tra trước, nếu đích tồn tại thì move nội dung thay vì rename |
| 2026-06-08 | `helpers/function.sh` `set_site_dir_permission`: đổi `exit 1` → `return 0` với warning khi thư mục không tồn tại, tránh crash toàn bộ flow |
| 2026-06-08 | `m_website.sh` `change_website_domain`: fix lỗi `wp search-replace` thất bại do `wp-config.php` vẫn dùng DB cũ sau khi rename DB — thêm `wp config set DB_NAME` và `wp config set DB_USER` trước khi chạy search-replace |
| 2026-06-08 | Controllers: xóa 34 `countdown 3` / `countdown_timer 3` thừa sau thao tác — giữ nguyên countdown trong rollback (`Da xay ra loi. Dang tien hanh rollback...`) |
| 2026-06-08 | Sub-menu routes: fix `0) Quay lai` bị thiếu hoặc dùng số cũ — `r_nginx_cache.sh`, `r_alias_redirect.sh`, `r_php_config.sh`, `r_wordpress_sec.sh`, `r_wp_cache_plugins.sh`, `r_wp_seo_plugins.sh` |
| 2026-06-08 | `m_website.sh` `change_website_domain`: bug cũ ghi `base_dir` sai (dùng `owner` thay vì `owner_folder`) làm hỏng settings file — fix thủ công settings trên VPS sau đó. **Lưu ý:** nếu domain đã từng đổi tên bằng code cũ, cần kiểm tra lại `base_dir` trong `.settings.conf` có khớp thư mục thực tế không |

---

## Cấu trúc thư mục

```
server-manager/
├── config/         — Biến toàn cục (đường dẫn, màu sắc, URL...)
├── routes/         — Menu giao diện (điều hướng người dùng)
├── controllers/    — Xử lý logic từng chức năng
├── models/         — Thao tác hệ thống (nginx, php, mysql, user...)
├── helpers/        — Hàm tiện ích dùng chung
├── validate/       — Kiểm tra đầu vào
└── templates/      — File mẫu nginx vhost
```

---

## ROUTES — Menu giao diện

| File | Function | Mô tả |
|------|----------|-------|
| `routes/main_menu.sh` | `main_menu` | Menu chính (gõ `mcn` để mở) |
| `routes/r_website.sh` | `website_menu` | Menu quản lý Website |
| `routes/r_mariadb.sh` | `mariadb_menu` | Menu quản lý MariaDB |
| `routes/r_php.sh` | `php_menu` | Menu quản lý PHP |
| `routes/r_nginx.sh` | `nginx_menu` | Menu quản lý Nginx |
| `routes/r_wordpress.sh` | `wordpress_menu` | Menu WordPress tools |
| `routes/r_backup.sh` | `backup_menu` | Menu Backup & Restore |
| `routes/r_firewall.sh` | `firewall_menu` | Menu Firewall (nftables) |
| `routes/r_vps_tools.sh` | `vps_tools_menu` | Menu VPS Tools |
| `routes/website/r_alias_redirect.sh` | `website_alias_redirect_menu` | Sub-menu alias & redirect domain |
| `routes/website/r_nginx_cache.sh` | `nginx_cache_menu` | Sub-menu FastCGI cache |
| `routes/website/r_php_config.sh` | `website_php_conf_menu` | Sub-menu cấu hình PHP per-site |
| `routes/wordpress/r_wordpress_sec.sh` | `wordpress_sec_menu` | Sub-menu bảo mật WordPress |
| `routes/wordpress/r_wp_cache_plugins.sh` | `wp_cache_plugin_menu` | Sub-menu cache plugins WP |
| `routes/wordpress/r_wp_seo_plugins.sh` | `wp_seo_plugin_menu` | Sub-menu SEO plugins WP |

---

## CONTROLLERS — Logic chức năng

### Website (`controllers/website/`)

| File | Function | Mô tả |
|------|----------|-------|
| `c_add.sh` | `add_website` | Tạo website mới (domain, PHP, DB, SFTP, WordPress, Laravel) |
| `c_delete.sh` | `delete_site` | Xóa website hoàn toàn |
| `c_list.sh` | `list_all_website` | Liệt kê tất cả website |
| `c_view_site_info.sh` | `view_website_details` | Xem thông tin website (DB, PHP, SFTP...) |
| `c_clone.sh` | `clone_website` | Clone website sang domain mới |
| `c_change_domain.sh` | `change_domain_website` | Đổi tên domain |
| `c_change_php_version.sh` | `php_selector` | Đổi phiên bản PHP cho website |
| `c_change_database_info.sh` | `change_db_info` | Đổi thông tin database |
| `c_sign_ssl.sh` | `sign_ssl_free` | Ký SSL Let's Encrypt |
| `c_nginx_cache.sh` | `nginx_fast_cgi_cache` / `delete_nginx_cache` | Bật/tắt FastCGI cache |
| `c_php_config.sh` | `php_display_error` / `change_php_param` | Cấu hình PHP per-site |
| `c_alias_domain.sh` | `add_alias_domain` / `delete_alias_domain` / `list_all_alias_domain` | Quản lý alias domain |
| `c_redirect_domain.sh` | `add_redirect_domain` / `delete_redirect_domain` / `list_all_redirect_domain` | Quản lý redirect domain |
| `c_orphaned_config.sh` | `find_orphaned_config` | Tìm config Nginx/PHP bị mồ côi |
| `clear_php_opcache.sh` | `clear_php_opcache` | Xóa PHP OPcache |
| `fix_website_permission.sh` | _(inline)_ | Sửa quyền thư mục website |
| `http_to_https.sh` | _(inline)_ | Bật/tắt redirect HTTP → HTTPS |

### WordPress (`controllers/wordpress/`)

| File | Function | Mô tả |
|------|----------|-------|
| `c_install_wordpress.sh` | `install_new_wordpress` | Cài WordPress mới |
| `c_change_admin_password.sh` | `change_wp_admin_password` | Đổi mật khẩu admin WP |
| `c_deactivate_plugins.sh` | `deactivate_plugins` | Vô hiệu hóa tất cả plugin |
| `c_debug_mode.sh` | `wp_debug_mode` / `wp_cron` | Bật/tắt debug mode, WP-Cron |
| `c_wordpress_lockdown.sh` | `wp_lockdown` | Khóa/mở WordPress |
| `c_wordpress_sec.sh` | `block_php_in_wp_content` / `block_user_api` / `disable_edit_plugins_theme`... | Bảo mật WordPress |
| `c_plugins_cache.sh` | `enable_wp_rocket` / `enable_w3_total_cache` | Cài plugin cache |
| `c_plugins_seo.sh` | `enable_yoast_seo` / `enable_rank_math_seo` | Cài plugin SEO |
| `c_post_revisions.sh` | _(inline)_ | Quản lý post revisions |
| `c_base_controller.sh` | `toggle_wp_config` / `toggle_wp_vhost` | Bật/tắt config WP |

### MariaDB (`controllers/mariadb/`)

| File | Function | Mô tả |
|------|----------|-------|
| `c_mariadb_action.sh` | `mariadb_restart` / `mariadb_stop` | Restart/stop MariaDB |
| | `mariadb_create_user` / `mariadb_create_db` | Tạo user/database |
| | `mariadb_delete_user` / `mariadb_delete_database` | Xóa user/database |
| | `mariadb_export_database` | Export database |
| | `mariadb_change_pass_user` | Đổi mật khẩu user |
| | `view_phpmyadmin_login_info` | Xem thông tin đăng nhập phpMyAdmin |

### PHP (`controllers/php/`)

| File | Function | Mô tả |
|------|----------|-------|
| `c_php_action.sh` | `php_reload` / `php_restart` / `php_stop` | Reload/restart/stop PHP-FPM |
| `c_add.sh` | _(inline)_ | Cài thêm phiên bản PHP mới |
| `c_uninstall.sh` | `fore_remove_php` | Gỡ cài đặt PHP |

### Nginx (`controllers/nginx/`)

| File | Function | Mô tả |
|------|----------|-------|
| `c_nginx_action.sh` | `reload_nginx` / `restart_nginx` / `stop_nginx` | Reload/restart/stop Nginx |
| | `rebuild_nginx` | Build lại Nginx từ source |
| | `rewrite_nginx_vhost` | Tạo lại vhost Nginx |

### Backup (`controllers/backup/`)

| File | Function | Mô tả |
|------|----------|-------|
| `c_backup.sh` | `backup_action` | Backup website (local/remote SFTP) |
| `c_restore_backup.sh` | `restore_backup` | Restore backup |

### Firewall (`controllers/firewall/`)

| File | Function | Mô tả |
|------|----------|-------|
| `c_fw_action.sh` | `_block_ip` / `_unblock_ip` | Chặn/bỏ chặn IP |
| | `stop_start_firewall` | Bật/tắt firewall (nftables) |

### VPS Tools (`controllers/vps/`)

| File | Function | Mô tả |
|------|----------|-------|
| `c_vps_action.sh` | `vps_find_large_file` | Tìm file lớn |
| | `vps_find_process_occupying_ram_cpu` | Tìm process ngốn RAM/CPU |
| | `vps_change_ssh_port` | Đổi port SSH |
| | `notify_service` | Cấu hình thông báo Telegram |

### Update (`controllers/update/`)

| File | Function | Mô tả |
|------|----------|-------|
| `c_update_script.sh` | `update_menu` | Cập nhật McnVPS script |

---

## MODELS — Thao tác hệ thống

| File | Các function chính | Mô tả |
|------|-------------------|-------|
| `m_linux_user.sh` | `create_system_user` / `delete_linux_user` | Tạo/xóa user hệ thống |
| | `create_sftp_user` / `delete_sftp_user` | Tạo/xóa SFTP user theo domain |
| `m_mysql.sh` | `create_database` / `create_mysql_user` / `grant_mysql_user_privileges` | Quản lý MySQL |
| | `delete_mysql_db` / `delete_mysql_user` / `change_mysql_user_password` | Xóa/đổi pass MySQL |
| | `export_database` | Export database |
| `m_nginx.sh` | `test_nginx_config` / `nginx_reload` / `nginx_restart` | Kiểm tra và điều khiển Nginx |
| `m_php.sh` | `create_php_pool` / `install_php` / `uninstall_php` | Quản lý PHP pool |
| | `clear_opcache` / `test_php_pool_conf` | OPcache và kiểm tra pool |
| `m_ssl.sh` | `ssl_issue_and_install_cert` / `ssl_process_all_pending_domains` | Ký và cài SSL |
| `m_vhost.sh` | `generate_nginx_vhost` / `enable_nginx_vhost` / `delete_vhost` | Tạo/xóa Nginx vhost |
| `m_website.sh` | `create_website_directories` / `save_website_settings` / `destroy_website` | Quản lý file website |
| | `change_website_domain` / `change_website_php_version` | Đổi domain/PHP |
| `m_application.sh` | `install_wordpress` / `install_laravel` / `install_nextcloud` | Cài ứng dụng |
| | `install_n8n` / `install_nodejs_use_nvm` | Cài n8n, Node.js |

---

## HELPERS — Hàm tiện ích

| File | Các function chính | Mô tả |
|------|-------------------|-------|
| `helpers/function.sh` | `gen_pass` | Sinh mật khẩu ngẫu nhiên |
| | `run_or_exit` | Chạy lệnh, thoát nếu lỗi |
| | `wget_with_retry` / `curl_get_with_retry` | Download với retry |
| | `generate_user_from_domain` / `generate_web_owner_folder` | Sinh tên user từ domain |
| | `set_site_dir_permission` | Set quyền thư mục website |
| | `format_nginx_config` | Format file cấu hình Nginx |
| | `press_enter_to_continue` | Dừng chờ Enter trước khi quay menu |
| | `countdown_timer` / `msg` / `clear_screen` | UI utilities |
| `helpers/file.sh` | `extract_file` / `delete_file` / `delete_dir` / `safe_copy_or_exit` | Thao tác file |
| `helpers/prompt.sh` | `prompt_domain_input` / `prompt_select_website` / `prompt_yes_no` | Nhập liệu từ người dùng |
| | `prompt_select_php_version` / `prompt_select_website_source` | Chọn PHP, loại website |
| `helpers/input.sh` | `is_valid_domain` / `is_valid_php_version` / `ask_until_valid` | Validate input |
| `helpers/php_variables.sh` | _(inline)_ | Tính toán memory/children PHP theo RAM |

---

## VALIDATE — Kiểm tra điều kiện

| File | Các function chính | Mô tả |
|------|-------------------|-------|
| `validate/rule.sh` | `is_domain_exists` / `is_valid_domain` / `is_valid_email` | Kiểm tra domain, email |
| | `check_service_before_action` / `check_http_status` | Kiểm tra service, HTTP |
| | `is_wordpress` / `is_linux_user_exists` | Kiểm tra WordPress, user |
| | `is_behind_cloudflare` / `is_domain_points_to_vps` | Kiểm tra DNS/CF |
| | `validate_ssl_domain` / `is_ssl_need_renew` | Kiểm tra SSL |

---

## TEMPLATES — Mẫu cấu hình Nginx

| File | Mô tả |
|------|-------|
| `templates/nginx/nginx-vhost.conf` | Template vhost cơ bản |
| `templates/nginx/nginx_redirect.conf` | Template redirect domain |
| `templates/nginx/fast-cgi-cache.conf` | Template FastCGI cache |
| `templates/nginx/http/https-wp-login.conf` | Bảo vệ wp-login |
| `templates/nginx/http/https-static-file-no-cache.conf` | Static file no-cache |
| `templates/nginx/wp-security.conf` | Bảo mật WordPress |
| `templates/nginx/laravel-security.conf` | Bảo mật Laravel |
| `templates/nginx/magento2.conf` | Template Magento 2 |
| `templates/nginx/nextcloud.conf` | Template Nextcloud |
| `templates/nginx/moodle.conf` | Template Moodle |
| `templates/nginx/yii2.conf` | Template Yii2 |
| `templates/nginx/w3-total-cache.conf` | Tích hợp W3 Total Cache |
| `templates/nginx/rank-math-sitemap.conf` | Sitemap Rank Math SEO |
| `templates/nginx/yoast-seo-sitemap.conf` | Sitemap Yoast SEO |

---

## Cách thêm chức năng mới

### Thêm menu item mới vào Website
1. Tạo file controller: `controllers/website/c_ten_chuc_nang.sh`
2. Viết function: `ten_chuc_nang() { ... }`
3. Thêm vào menu trong `routes/r_website.sh`: `echo "N. Ten chuc nang"` và `N) ten_chuc_nang ;;`

### Thêm sub-menu mới
1. Tạo file route: `routes/r_ten_menu.sh` với function `ten_menu()`
2. Tạo thư mục controller: `controllers/ten_menu/`
3. Đăng ký vào `routes/main_menu.sh`

### Quy tắc quan trọng
- Controller dùng `return 0` (không dùng `exit 0`) để quay lại menu sau khi xong
- Luôn gọi `press_enter_to_continue` trước `return 0` nếu có output cần đọc
- Dùng `run_or_exit "mo ta" lenh` thay vì chạy lệnh trực tiếp
- Lưu thông tin website vào `${WEB_DATA_DIR}/${domain}/.settings.conf`
- SFTP user tự động tạo khi thêm website mới
