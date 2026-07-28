#!/bin/bash

# Cloudflare Tunnel DNS helper
# Usage: cf_tunnel.sh <add-dns|del-dns|zone-id> <domain>

CONF="/var/mcnvps/.cf_tunnel.conf"
[ -f "${CONF}" ] || exit 0
# shellcheck disable=SC1090
source "${CONF}"
[[ -z "${CF_API_TOKEN}" || -z "${CF_TUNNEL_ID}" ]] && exit 0

CF_API="https://api.cloudflare.com/client/v4"
CMD="$1"
DOMAIN="$2"
[ -z "${DOMAIN}" ] && exit 0

_zone_id() {
    local try="$1" zid=""
    while [ -n "${try}" ]; do
        zid=$(curl -s --max-time 15 "${CF_API}/zones?name=${try}" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" | jq -r '.result[0].id // empty' 2>/dev/null)
        [ -n "${zid}" ] && echo "${zid}" && return 0
        if [[ "${try}" == *.*.* ]]; then try="${try#*.}"; else break; fi
    done
    return 1
}

_upsert_cname() {
    local zone_id="$1" name="$2" target="${CF_TUNNEL_ID}.cfargotunnel.com"

    local existing
    existing=$(curl -s --max-time 15 "${CF_API}/zones/${zone_id}/dns_records?type=CNAME&name=${name}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" | jq -r '.result[0].id // empty' 2>/dev/null)

    if [ -n "${existing}" ]; then
        curl -s --max-time 15 -X PATCH "${CF_API}/zones/${zone_id}/dns_records/${existing}" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"${name}\",\"content\":\"${target}\",\"proxied\":true}" >/dev/null 2>&1
    else
        curl -s --max-time 15 -X POST "${CF_API}/zones/${zone_id}/dns_records" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"${name}\",\"content\":\"${target}\",\"proxied\":true}" >/dev/null 2>&1
    fi
}

_delete_record() {
    local zone_id="$1" name="$2"
    local rec_id
    rec_id=$(curl -s --max-time 15 "${CF_API}/zones/${zone_id}/dns_records?name=${name}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" | jq -r '.result[0].id // empty' 2>/dev/null)
    [ -n "${rec_id}" ] && curl -s --max-time 15 -X DELETE "${CF_API}/zones/${zone_id}/dns_records/${rec_id}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" >/dev/null 2>&1
}

case "${CMD}" in
    add-dns)
        zone_id=$(_zone_id "${DOMAIN}") || exit 0
        _upsert_cname "${zone_id}" "${DOMAIN}"
        _upsert_cname "${zone_id}" "www.${DOMAIN}"
        ;;
    del-dns)
        zone_id=$(_zone_id "${DOMAIN}") || exit 0
        _delete_record "${zone_id}" "${DOMAIN}"
        _delete_record "${zone_id}" "www.${DOMAIN}"
        ;;
    zone-id)
        _zone_id "${DOMAIN}"
        ;;
esac

exit 0
