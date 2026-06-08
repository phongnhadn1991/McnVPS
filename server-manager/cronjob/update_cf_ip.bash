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
source "${MENU_DIR}/helpers/function.sh"

CF_IPV4_URL="https://www.cloudflare.com/ips-v4"
CF_IPV6_URL="https://www.cloudflare.com/ips-v6"
CF_IPV4_FILE="/tmp/cloudflare_ipv4.txt"
CF_IPV6_FILE="/tmp/cloudflare_ipv6.txt"

wget_with_retry --url "${CF_IPV4_URL}" --output "${CF_IPV4_FILE}" || exit 1
wget_with_retry --url "${CF_IPV6_URL}" --output "${CF_IPV6_FILE}" || exit 1

CF_CONFIG_FILE="/etc/nginx/nginx-cloudflare.conf"
GEO_CONFIG_FILE='/etc/nginx/nginx-geo.conf'

if [[ -e "${CF_IPV4_FILE}" && -e "${CF_IPV6_FILE}" ]]; then
    if [[ -s "${CF_IPV4_FILE}" && -s "${CF_IPV6_FILE}"  ]]; then
        {
            echo "real_ip_header CF-Connecting-IP;"
            while read -r ip; do
                [[ -n "$ip" ]] && echo "set_real_ip_from $ip;"
            done < "$CF_IPV4_FILE"

            while read -r ip; do
                [[ -n "$ip" ]] && echo "set_real_ip_from $ip;"
            done < "$CF_IPV6_FILE"
        } > "$CF_CONFIG_FILE"

        cat >"${GEO_CONFIG_FILE}" <<END
geoip2 /etc/nginx/geo/country_asn.mmdb {
    auto_reload 7d;
    \$geoip2_data_continent continent;
    \$geoip2_data_country_name country;
    \$geoip2_asn asn;
    \$geoip2_organization as_name;
}

END

        {
            while read -r ip; do
                [[ -n "$ip" ]] && echo "geoip2_proxy $ip;"
            done < "$CF_IPV4_FILE"

            while read -r ip; do
                [[ -n "$ip" ]] && echo "geoip2_proxy $ip;"
            done < "$CF_IPV6_FILE"

            echo "geoip2_proxy_recursive on;"
        } >> "$GEO_CONFIG_FILE"

        systemctl reload nginx
    fi

    rm -f "${CF_IPV4_FILE}"
    rm -f "${CF_IPV6_FILE}"
fi
