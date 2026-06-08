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

create_system_user() {
    local user="$1"
    local user_home="$2"
    local create_home="${3:-true}"
    local create_home_options

    if [ "$create_home" == 'true' ]; then
        create_home_options="--home /home/${user_home}"
    else
        create_home_options="--no-create-home"
    fi

    # shellcheck disable=SC2086
    run_or_exit "Tao user he thong" adduser --system \
        $create_home_options \
        --shell /bin/false \
        --disabled-login \
        --disabled-password \
        --gecos "'${user} user'" \
        --group "${user}"
}

create_sftp_user() {
    local sftp_user="$1"
    local sftp_pass="$2"
    local domain="$3"
    local owner_folder="$4"
    local base_dir="/home/${owner_folder}/${domain}"

    # Tao user co the login qua SFTP
    if ! id "$sftp_user" &>/dev/null; then
        useradd -m -s /bin/bash -d "/home/${sftp_user}" "$sftp_user"
    fi

    echo "${sftp_user}:${sftp_pass}" | chpasswd

    # Tao group sftpusers neu chua co
    if ! getent group sftpusers &>/dev/null; then
        groupadd sftpusers
    fi

    # Them sftp user vao group cua web owner de co quyen truy cap thu muc web
    local web_owner
    web_owner=$(stat -c '%G' "$base_dir" 2>/dev/null)
    if [[ -n "$web_owner" ]]; then
        usermod -aG "$web_owner" "$sftp_user"
    fi
    usermod -aG sftpusers "$sftp_user"

    # Chroot: /home/owner_folder phai thuoc root:root, chmod 755
    chown root:root "/home/${owner_folder}"
    chmod 755 "/home/${owner_folder}"

    # Thu muc domain va ben trong: owner:group voi quyen 750 de group doc duoc
    chmod 750 "$base_dir"
    find "$base_dir" -type d -exec chmod 750 {} \;

    # Cau hinh chroot SFTP trong sshd_config neu chua co
    if ! grep -q "^Match Group sftpusers" /etc/ssh/sshd_config 2>/dev/null; then
        cat >> /etc/ssh/sshd_config <<EOF

Match Group sftpusers
    ChrootDirectory /home/${owner_folder}
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF
    fi

    systemctl reload sshd 2>/dev/null || systemctl restart sshd 2>/dev/null
}

delete_sftp_user() {
    local sftp_user="$1"

    if id "$sftp_user" &>/dev/null; then
        pkill -9 -u "$sftp_user" 2>/dev/null
        deluser --remove-home "$sftp_user" 2>/dev/null
    fi
}

delete_linux_user() {
    local user="$1"
    local delete_home="${2:-false}"

    if [ -z "$user" ]; then
        return 1
    fi

    local delete_home_opt=''
    if [ "${delete_home}" == 'true' ]; then
        delete_home_opt='--remove-home'
    fi

    if id "$user" &>/dev/null; then
        #pkill -u "$user" 2>/dev/null
        pkill -9 -u "$user" 2>/dev/null
        local retry=0

        while pgrep -u "$user" &>/dev/null && [ $retry -lt 5 ]; do
            sleep 1
            retry=$((retry+1))
        done

        if pgrep -u "$user" &>/dev/null; then
            pkill -9 -u "$user" 2>/dev/null
        fi

        run_or_exit "🧹 Xoa user $user" deluser $delete_home_opt "$user" 2>/dev/null
        return 0
    fi

    return 0
}
