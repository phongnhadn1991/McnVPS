"""Cau hinh McnVPS Telegram bot.

Doc /var/mcnvps/.telegram_bot.conf (dinh dang bash KEY="value"):
    BOT_TOKEN="..."
    ALLOWED_CHAT_IDS="352725269,-1004333782002"
    BOT_MODE="menu"            # notify | menu
    ADMIN_IDS="352725269"
    USER_FEATURES="123:domain,db;456:svc"
"""
from __future__ import annotations

import os
import re
from pathlib import Path

CONF_PATH = os.environ.get("MCNVPS_TGBOT_CONF", "/var/mcnvps/.telegram_bot.conf")

BASH_DIR = "/var/mcnvps"
FILE_INFO = f"{BASH_DIR}/.mcnvps.conf"
WEB_DATA_DIR = f"{BASH_DIR}/data/websites"
MENU_DIR = f"{BASH_DIR}/server-manager"
STATE_DIR = f"{BASH_DIR}/.tgbot_py"
VHOST_DIR = "/etc/nginx/sites-available"
MYSQL_SOCK = "/run/mysqld/mysqld.sock"
PATH_ENV = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

F_DOMAIN = "domain"
F_DB = "db"
F_WP = "wp"
F_SSL = "ssl"
F_CACHE = "cache"
F_BACKUP = "backup"
F_FW = "fw"
F_SVC = "svc"
F_VPS = "vps"
F_TOOL = "tool"

VIEW_FEATURES = {F_DOMAIN, F_DB, F_WP, F_SSL, F_FW, F_SVC, F_VPS, F_TOOL}

E = {
    "home": "🏠", "menu": "📋",
    "domain": "🌐", "db": "🗄️", "wp": "📝", "ssl": "🔒", "cache": "⚡",
    "backup": "💾", "fw": "🛡️", "svc": "🔧", "vps": "⚙️", "tool": "🛠️",
    "cancel": "❌", "back": "⬅️", "confirm": "✅", "warn": "⚠️", "deny": "🚫",
    "info": "ℹ️", "on": "🟢", "off": "🔴", "start": "▶️", "stop": "⏹",
    "reboot": "♻️",
}

LBL_CANCEL = f"{E['cancel']} Hủy"
LBL_BACK = f"{E['back']} Quay lại"
LBL_HOME = f"{E['home']} Menu chính"
CB_HOME = "nav|home"

_KV = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$')


def _strip_quotes(v: str) -> str:
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v


def _read_conf(path: str = CONF_PATH) -> dict[str, str]:
    data: dict[str, str] = {}
    p = Path(path)
    if not p.exists():
        return data
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.lstrip().startswith("#"):
            continue
        m = _KV.match(line)
        if m:
            data[m.group(1)] = _strip_quotes(m.group(2))
    return data


_conf = _read_conf()

BOT_TOKEN: str = _conf.get("BOT_TOKEN", "")
BOT_MODE: str = _conf.get("BOT_MODE", "menu").strip() or "menu"


def _parse_ids(raw: str) -> set[int]:
    out: set[int] = set()
    for tok in raw.replace(" ", "").split(","):
        if tok.lstrip("-").isdigit():
            out.add(int(tok))
    return out


ALLOWED_CHAT_IDS: set[int] = _parse_ids(_conf.get("ALLOWED_CHAT_IDS", ""))
ADMIN_IDS: set[int] = _parse_ids(_conf.get("ADMIN_IDS", "")) or set(ALLOWED_CHAT_IDS)


def _parse_user_features(raw: str) -> dict[int, set[str]]:
    out: dict[int, set[str]] = {}
    for chunk in raw.split(";"):
        chunk = chunk.strip()
        if not chunk or ":" not in chunk:
            continue
        uid, feats = chunk.split(":", 1)
        uid = uid.strip()
        if uid.lstrip("-").isdigit():
            out[int(uid)] = {f.strip() for f in feats.split(",") if f.strip()}
    return out


USER_FEATURES: dict[int, set[str]] = _parse_user_features(_conf.get("USER_FEATURES", ""))
