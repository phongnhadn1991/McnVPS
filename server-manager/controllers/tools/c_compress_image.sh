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

compress_images() {
    clear_screen
    local domain base_dir owner owner_folder php_version website_source

    msg "$ICON_GLOBE Chon Website muon nen anh"
    run_prompt_or_exit prompt_select_website domain "vps_tools_menu"

    # shellcheck disable=SC1090
    source "${WEB_DATA_DIR}/${domain}/.settings.conf" || {
        msg "$ICON_EXIT Khong the load file cau hinh: ${domain}"
        press_enter_to_continue; return 0
    }

    local target_dir=""
    if [[ "$website_source" == "wordpress" && -d "${base_dir}/public_html/wp-content/uploads" ]]; then
        target_dir="${base_dir}/public_html/wp-content/uploads"
        msg "$ICON_CHECK Phat hien WordPress, nen anh trong: wp-content/uploads" 'green'
    else
        read -rp "Nhap duong dan thu muc chua anh (tuyet doi): " target_dir
    fi

    if [[ -z "$target_dir" || ! -d "$target_dir" ]]; then
        msg "$ICON_EXIT Thu muc khong ton tai: ${target_dir}"
        press_enter_to_continue; return 0
    fi

    local png_count jpg_count
    png_count=$(find "$target_dir" -type f -name "*.png" -size +100k 2>/dev/null | wc -l)
    jpg_count=$(find "$target_dir" -type f \( -name "*.jpg" -o -name "*.jpeg" \) -size +100k 2>/dev/null | wc -l)

    if [[ $((png_count + jpg_count)) -eq 0 ]]; then
        msg "$ICON_EXIT Khong tim thay anh nao lon hon 100KB"
        press_enter_to_continue; return 0
    fi

    local before_size
    before_size=$(du -sh "$target_dir" 2>/dev/null | cut -f1)
    echo ""
    echo "${GREEN}Dung luong truoc khi nen: ${before_size}${NC}"
    echo "${GREEN}PNG > 100KB: ${png_count} file${NC}"
    echo "${GREEN}JPG > 100KB: ${jpg_count} file${NC}"
    echo ""

    if ! prompt_yes_no "Bat dau nen anh? (Qua trinh nay co the mat vai phut)"; then
        msg "$ICON_EXIT Huy thao tac"
        press_enter_to_continue; return 0
    fi

    if ! command -v pngquant &>/dev/null || ! command -v jpegoptim &>/dev/null; then
        msg "$ICON_TOOL Dang cai dat cong cu nen anh..."
        apt-get update -y >/dev/null 2>&1
        apt-get install -y pngquant jpegoptim >/dev/null 2>&1
    fi

    if [[ $png_count -gt 0 ]]; then
        msg "$ICON_TOOL Dang nen ${png_count} file PNG..."
        find "$target_dir" -type f -name "*.png" -size +100k -exec pngquant --quality=75-80 --ext=.png --force {} \; 2>/dev/null
    fi

    if [[ $jpg_count -gt 0 ]]; then
        msg "$ICON_TOOL Dang nen ${jpg_count} file JPG..."
        find "$target_dir" -type f \( -name "*.jpg" -o -name "*.jpeg" \) -size +100k -exec jpegoptim -m 75 -f --strip-all {} \; 2>/dev/null
    fi

    find "$target_dir" -type d -exec chmod 0755 {} \; 2>/dev/null
    find "$target_dir" -type f -exec chmod 0644 {} \; 2>/dev/null
    chown -R "${owner}:${owner}" "$target_dir" 2>/dev/null

    local after_size
    after_size=$(du -sh "$target_dir" 2>/dev/null | cut -f1)
    echo ""
    msg "$ICON_SUCCESS Nen anh hoan tat!" 'green'
    echo "${GREEN}-----------------------------------${NC}"
    echo "${GREEN}Truoc khi nen  : ${before_size}${NC}"
    echo "${GREEN}Sau khi nen    : ${after_size}${NC}"
    echo "${GREEN}-----------------------------------${NC}"

    press_enter_to_continue; return 0
}
