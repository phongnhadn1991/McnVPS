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

extract_file() {
    local file=$1

    if [ ! -e "$file" ]; then
        printf "${RED}%s does not exists${NC}\n" "$file"
        exit 1
    fi

    case "$file" in
        *.7z)
            if [ -z "$(which 7z)" ]; then
                printf "${RED}$ICON_EXIT Khong ho tro dinh dang file: %s${NC}\n" "$file"
                return 1
            fi

            7z e "$file"
            ;;
        *.tar)
            tar -xvf "$file"
            ;;
        *.tar.gz|*.tgz)
            tar -xvzf "$file"
            ;;
        *.tar.bz2|*.tbz2)
            tar -xvjf "$file"
            ;;
        *.tar.xz|*.txz)
            tar -xvJf "$file"
            ;;
        *.gz)
            gunzip "$file"
            ;;
        *.bz2)
            bunzip2 "$file"
            ;;
        *.xz)
            unxz "$file"
            ;;
        *.zip)
            unzip "$file"
            ;;
        *.rar)
            if [ -z "$(which unrar)" ]; then
                printf "${RED}$ICON_EXIT Khong ho tro dinh dang file: %s${NC}\n" "$file"
                return 1
            fi

            unrar x "$file"
            ;;
        *)
            printf "${RED}$ICON_EXIT Khong ho tro dinh dang file: %s${NC}\n" "$file"
            return 1
            ;;
    esac
}

delete_file() {
    for file in "$@"; do
        if [[ -n "$file" && -e "$file" ]]; then
            rm -f "$file"
        fi
    done
}

delete_dir() {
    for directory in "$@"; do
        if [[ -n "$directory" && -d "$directory" ]]; then
            rm -rf "$directory"
        fi
    done
}

is_file_exists() {
    local file="$1"

    if [[ -e "$file" ]]; then
        return 0
    else
        return 1
    fi
}

is_empty_file() {
    local file="$1"

    if [[ -s "$file" ]]; then
        return 1
    else
        return 0
    fi
}

safe_copy_or_exit() {
    local description="$1"
    local src="$2"
    local dest="$3"
    local ignore_missing="$4"

    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
    elif [[ "$ignore_missing" != true ]]; then
        msg "$ICON_EXIT $description that bai: File khong ton tai: $src"
        exit 1
    fi
}

create_symlink() {
    local dest="$1"
    local target="$2"
    local force="${3:-true}"
    local options='-s'

    if [[ "$force" == 'true' ]]; then
        options='-sf'
    fi

    if [ ! -e "$dest" ]; then
        # shellcheck disable=SC2034
        SYMLINK_ERR_REPLY="$dest khong ton tai"
        return 1
    fi

    if ln $options "${dest}" "${target}"; then
        return 0
    else
        return 1
    fi
}
