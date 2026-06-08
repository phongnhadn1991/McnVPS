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

# shellcheck disable=SC2034

source /etc/os-release

# Color
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
#BLUE=$(tput setaf 4)
BLUE=$(tput setaf 2)
ORANGE=$(tput setaf 3)

NC=$(tput sgr0)

if locale | grep -qi 'utf-8'; then
    ICON_EXIT="❌"
    ICON_ERROR="⛔"
    ICON_BACK="🔙"
    ICON_TOOL="🔧"
    ICON_ARROW="↳"
    ICON_CHECK="✅"
    ICON_SUCCESS="✅"
    ICON_CLEAN="🧹"
    ICON_BLOCK="🚫"
    ICON_GLOBE="🌐"
    ICON_WARNING="⚠️"
    ICON_SEARCH="🔍"
    ICON_HAND="👉"
else
    ICON_EXIT="[X]"
    ICON_ERROR=""
    ICON_BACK="<-"
    ICON_TOOL=''
    ICON_ARROW="->"
    ICON_CHECK=''
    ICON_SUCCESS=''
    ICON_CLEAN=''
    ICON_BLOCK=''
    ICON_GLOBE=''
    ICON_WARNING=''
    ICON_SEARCH=''
    ICON_HAND=''
fi

OS="$ID"
OS_VERSION="$VERSION_ID"

BUILD_DIR="/tmp/build"

MENU_NAME="mcnvps"
AUTHOR="MCNVPS.NET"
AUTHOR_WEB="MCNVPS.NET"
HOMEPAGE_LINK="https://scripts.mcnvps.net"

OS_LINK="${HOMEPAGE_LINK}/ubuntu"

UPDATE_LINK="${OS_LINK}/update"
GET_VERSION_LINK="${UPDATE_LINK}/version"
MODULE_LINK="${OS_LINK}/modules"

HOSTVN_DIR="/var/mcnvps"
FILE_INFO="${HOSTVN_DIR}/.mcnvps.conf"
MENU_DIR="${HOSTVN_DIR}/server-manager"
HVN_BIN_DIR="${MENU_DIR}/bin"
SCRIPTS_DATA_DIR="${HOSTVN_DIR}/data"
WEB_DATA_DIR="${SCRIPTS_DATA_DIR}/websites"
TEMPLATES_DIR="${MENU_DIR}/templates"
WP_CRON_DIR="${SCRIPTS_DATA_DIR}/wp-cron"
SSL_PENDING_DIR="${SCRIPTS_DATA_DIR}/ssl-pending"

SSL_LOG_PATH='/var/log/sign-ssl'
SSL_ERROR_LOG_PATH="${SSL_LOG_PATH}/errors"
SSL_LETSENCRYPT_HISTORY_PATH="${SSL_LOG_PATH}/history"
SSL_LETSENCRYPT_HISTORY_LOG="${SSL_LETSENCRYPT_HISTORY_PATH}/history.log"
SSL_ERROR_LOG_FILE="${SSL_ERROR_LOG_PATH}/acme_error.log"
LOCK_SIGN_SSL_PROGRESS='/tmp/sign_ssl_lock_progress.pid'
SSL_CERT_FILE_NAME='cert.pem'
SSL_PRI_KEY_FILE_NAME='key.pem'

PHP_BASE_DIR='/etc/php'

NGINX_CONF_DIR="/etc/nginx"
NGINX_EXTRA_CONF_DIR="${NGINX_CONF_DIR}/conf.d"
SSL_CERT_DIR="${NGINX_CONF_DIR}/ssl"
MYSQL_DIR="/var/lib/mysql"
SITE_ENABLED_DIR="${NGINX_CONF_DIR}/sites-enabled"
SITE_AVAILABLE_DIR="${NGINX_CONF_DIR}/sites-available"
SITE_ALIAS_CONF_DIR="${NGINX_CONF_DIR}/alias-domains"
SITE_REDIRECT_CONF_DIR="${NGINX_CONF_DIR}/redirect-domains"
BACKUP_CONF_DIR="${NGINX_CONF_DIR}/backup"

DEFAULT_DIR_WEB="/vaw/www/html"
DEFAULT_DIR_TOOL="/vaw/www/private"

LOCAL_BACKUP_DIR='/backup'

CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null)
RAM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
SWAP_TOTAL=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
PHP_MEM=${RAM_TOTAL}+${SWAP_TOTAL}
RAM_MB=$(echo "scale=0;${RAM_TOTAL}/1024" | bc)

IP_ADDRESS=$(ip -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)

CF_IPV4_LIST="${SCRIPTS_DATA_DIR}/cloudflare_ipv4.txt"
CF_IPV6_LIST="${SCRIPTS_DATA_DIR}/cloudflare_ipv6.txt"

PHP_CLI_MAJOR_VERSION=$(php -r 'echo PHP_MAJOR_VERSION;')
PHP_CLI_MINOR_VERSION=$(php -r 'echo PHP_MINOR_VERSION;')
PHP_CLI_VERSION="${PHP_CLI_MAJOR_VERSION}.${PHP_CLI_MINOR_VERSION}"