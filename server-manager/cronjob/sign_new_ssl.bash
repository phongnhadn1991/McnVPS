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

source /var/mcnvps/server-manager/config/variables.sh
source "${MENU_DIR}/models/m_ssl.sh"

# shellcheck disable=SC2034
SSL_NEED_RELOAD_NGINX='false'

ssl_process_all_pending_domains --dir "$SSL_PENDING_DIR" --scan-type 'f'
