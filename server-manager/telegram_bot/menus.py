"""Menu layouts cho McnVPS Telegram bot."""
from __future__ import annotations
from typing import Optional
from telegram import InlineKeyboardButton as Btn, InlineKeyboardMarkup, ReplyKeyboardMarkup
import config as C
from permissions import can_see

MAIN_MENU = [
    (C.F_DOMAIN, f"{C.E['domain']} Domain"),
    (C.F_DB, f"{C.E['db']} Database"),
    (C.F_WP, f"{C.E['wp']} WordPress"),
    (C.F_SSL, f"{C.E['ssl']} SSL"),
    (C.F_CACHE, f"{C.E['cache']} Cache"),
    (C.F_BACKUP, f"{C.E['backup']} Backup"),
    (C.F_FW, f"{C.E['fw']} Firewall"),
    (C.F_SVC, f"{C.E['svc']} Services"),
    (C.F_VPS, f"{C.E['vps']} VPS Info"),
    (C.F_TOOL, f"{C.E['tool']} Tools"),
]


def build_keyboard(features: Optional[set[str]]) -> ReplyKeyboardMarkup:
    buttons = []
    row = []
    for key, label in MAIN_MENU:
        if can_see(key, features):
            row.append(label)
            if len(row) == 2:
                buttons.append(row)
                row = []
    if row:
        buttons.append(row)
    buttons.append([C.LBL_CANCEL])
    return ReplyKeyboardMarkup(buttons, resize_keyboard=True)


LABEL_TO_FEATURE = {label: key for key, label in MAIN_MENU}


def rows_menu(items: list[tuple[str, str]], cols: int = 2) -> InlineKeyboardMarkup:
    buttons = [Btn(text=label, callback_data=cb) for cb, label in items]
    rows = [buttons[i:i + cols] for i in range(0, len(buttons), cols)]
    rows.append([Btn(text=C.LBL_HOME, callback_data=C.CB_HOME)])
    return InlineKeyboardMarkup(rows)


def back_only(cb: str = C.CB_HOME) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([[Btn(text=C.LBL_BACK, callback_data=cb)]])


def confirm_menu(yes_cb: str, no_cb: str = C.CB_HOME) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [Btn(text=f"{C.E['confirm']} Xác nhận", callback_data=yes_cb),
         Btn(text=C.LBL_CANCEL, callback_data=no_cb)],
    ])


def domain_menu() -> list[tuple[str, str]]:
    return [
        ("m|domain|list", "📋 Danh sách"),
        ("m|domain|info", "ℹ️ Thông tin site"),
    ]


def services_menu(statuses: dict[str, str]) -> list[tuple[str, str]]:
    items = []
    for name, status in statuses.items():
        icon = C.E["on"] if status == "active" else C.E["off"]
        items.append((f"svc|{name}", f"{icon} {name}"))
    items.append(("svc|restart_all", f"{C.E['reboot']} Restart All"))
    return items


def vps_menu() -> list[tuple[str, str]]:
    return [
        ("m|vps|info", f"{C.E['info']} Thông tin VPS"),
        ("m|vps|disk", "💾 Disk usage"),
    ]
