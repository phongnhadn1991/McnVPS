"""Handler chinh cho McnVPS Telegram bot.

Routing callback queries va text messages. Mode notify chi xem,
mode menu cho phep dieu khien server qua inline buttons.
KHONG co shell mode — khong cho phep chay lenh tuy y.
"""
from __future__ import annotations

import asyncio
import logging
import os
import subprocess

from telegram import Update
from telegram.ext import ContextTypes

import config as C
import menus
import texts
from permissions import is_allowed, is_actor_allowed, can_write, get_user_features, has_feature
import progress

log = logging.getLogger("mcnvps-bot")


def _sh(cmd: str, timeout: int = 30) -> str:
    try:
        r = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout,
            env={**os.environ, "PATH": C.PATH_ENV},
        )
        return (r.stdout + r.stderr).strip()
    except subprocess.TimeoutExpired:
        return "(timeout)"
    except Exception as e:
        return str(e)


async def _async_sh(cmd: str, timeout: int = 30) -> str:
    return await asyncio.to_thread(_sh, cmd, timeout)


def _services_status(names: list[str]) -> dict[str, str]:
    result = {}
    for name in names:
        out = _sh(f"systemctl is-active {name} 2>/dev/null", 5)
        result[name] = out.strip()
    return result


def _list_domains() -> list[str]:
    domains = []
    web_dir = C.WEB_DATA_DIR
    if os.path.isdir(web_dir):
        for d in sorted(os.listdir(web_dir)):
            conf = os.path.join(web_dir, d, ".settings.conf")
            if os.path.isfile(conf):
                domains.append(d)
    return domains


def _read_conf_val(path: str, key: str) -> str:
    if not os.path.isfile(path):
        return ""
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith(f"{key}="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def _detect_php_version() -> str:
    ver = _read_conf_val(C.FILE_INFO, "php1_version")
    if ver:
        return ver
    import glob
    socks = sorted(glob.glob("/run/php/php*-fpm.sock"), reverse=True)
    if socks:
        base = os.path.basename(socks[0])
        return base.replace("php", "").replace("-fpm.sock", "")
    return "8.4"


# ──────────────────────────── Command handlers ────────────────────────────

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_chat.id):
        return
    hostname = await _async_sh("hostname -f", 5)
    kb = menus.build_keyboard(get_user_features(update.effective_chat.id))
    await update.message.reply_text(
        texts.greeting(update.effective_user.first_name, hostname, C.BOT_MODE),
        parse_mode="HTML", reply_markup=kb,
    )


async def show_menu(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_chat.id):
        return
    kb = menus.build_keyboard(get_user_features(update.effective_chat.id))
    await update.message.reply_text(
        f"{C.E['menu']} <b>Menu McnVPS</b>", parse_mode="HTML", reply_markup=kb,
    )


async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    context.user_data.clear()
    await update.message.reply_text(
        f"{C.E['cancel']} Đã hủy.",
        reply_markup=menus.build_keyboard(get_user_features(update.effective_chat.id)),
    )


# ──────────────────────────── Text message handler ────────────────────────

async def on_menu_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    cid = update.effective_chat.id
    if not is_allowed(cid):
        return
    text = update.message.text.strip()

    if text == C.LBL_CANCEL:
        await cancel(update, context)
        return

    feature = menus.LABEL_TO_FEATURE.get(text)
    if feature is None:
        return

    if not has_feature(cid, feature):
        await update.message.reply_text(texts.DENY, parse_mode="HTML")
        return

    if feature == C.F_DOMAIN:
        items = menus.domain_menu()
        await update.message.reply_text(
            texts.title(C.E["domain"], "Domain"),
            parse_mode="HTML", reply_markup=menus.rows_menu(items),
        )
    elif feature == C.F_SVC:
        names = ["nginx", "mariadb"]
        php_ver = _detect_php_version()
        names.append(f"php{php_ver}-fpm")
        statuses = await asyncio.to_thread(_services_status, names)
        items = menus.services_menu(statuses)
        await update.message.reply_text(
            texts.title(C.E["svc"], "Services"),
            parse_mode="HTML", reply_markup=menus.rows_menu(items),
        )
    elif feature == C.F_VPS:
        items = menus.vps_menu()
        await update.message.reply_text(
            texts.title(C.E["vps"], "VPS"),
            parse_mode="HTML", reply_markup=menus.rows_menu(items),
        )
    else:
        await update.message.reply_text(
            texts.title(C.E.get(feature, "📋"), feature.upper(),
                        "<i>Chức năng này đang được phát triển.</i>"),
            parse_mode="HTML", reply_markup=menus.back_only(),
        )


# ──────────────────────────── Callback query handler ──────────────────────

async def on_callback(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    query = update.callback_query
    await query.answer()
    cid = query.message.chat_id
    uid = query.from_user.id if query.from_user else None

    if not is_allowed(cid) or not is_actor_allowed(uid):
        await query.edit_message_text(texts.DENY, parse_mode="HTML")
        return

    data = query.data or ""
    parts = data.split("|")

    async def edit(text: str) -> None:
        await query.edit_message_text(text, parse_mode="HTML")

    if data == C.CB_HOME:
        await edit(f"{C.E['home']} <b>Menu chính</b>\nChọn từ bàn phím bên dưới.")
        return

    prefix = parts[0] if parts else ""

    if prefix == "m" and len(parts) >= 3:
        group, action = parts[1], parts[2]
        await _handle_menu_action(edit, cid, group, action, query)

    elif prefix == "svc" and len(parts) >= 2:
        service = parts[1]
        await _handle_service(edit, cid, service)

    elif prefix == "yes" and len(parts) >= 2:
        await _handle_confirm(edit, cid, "|".join(parts[1:]))

    else:
        await edit(f"{C.E['info']} Chức năng đang phát triển.")


async def _handle_menu_action(edit, cid, group, action, query) -> None:
    if group == "domain":
        if action == "list":
            domains = await asyncio.to_thread(_list_domains)
            if domains:
                text = texts.title(C.E["domain"], "Danh sách domain")
                text += "\n" + "\n".join(f"• <code>{texts.esc(d)}</code>" for d in domains)
            else:
                text = f"{C.E['warn']} Chưa có website nào."
            await edit(text)
        elif action == "info":
            domains = await asyncio.to_thread(_list_domains)
            if not domains:
                await edit(f"{C.E['warn']} Chưa có website nào.")
                return
            items = [(f"m|domain|detail|{d}", d) for d in domains[:20]]
            await query.edit_message_text(
                texts.title(C.E["domain"], "Chọn domain"),
                parse_mode="HTML", reply_markup=menus.rows_menu(items, cols=1),
            )
        elif action == "detail" and len(query.data.split("|")) >= 4:
            domain = query.data.split("|")[3]
            conf_path = os.path.join(C.WEB_DATA_DIR, domain, ".settings.conf")
            info_lines = [texts.title(C.E["domain"], domain)]
            for key in ["php_version", "website_source", "db_name", "sftp_user"]:
                val = await asyncio.to_thread(_read_conf_val, conf_path, key)
                if val:
                    info_lines.append(f"<b>{texts.esc(key)}</b>: <code>{texts.esc(val)}</code>")
            await edit("\n".join(info_lines))

    elif group == "vps":
        if action == "info":
            info = await _async_sh(
                "echo \"Hostname: $(hostname)\n"
                "IP: $(curl -s4 ifconfig.me)\n"
                "OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY | cut -d= -f2)\n"
                "Uptime: $(uptime -p)\n"
                "CPU: $(nproc) cores\n"
                "RAM: $(free -h | awk '/Mem/{print $3\\\"/\\\"$2}')\"", 15)
            await edit(texts.title(C.E["vps"], "VPS Info") + "\n" + texts.pre(info))
        elif action == "disk":
            info = await _async_sh("df -h / | tail -1 | awk '{print \"Used: \"$3\" / \"$2\" (\"$5\")\"}'", 10)
            await edit(texts.title("💾", "Disk Usage") + "\n" + texts.pre(info))


async def _handle_service(edit, cid, service) -> None:
    if not can_write(cid):
        await edit(texts.NOTIFY_ONLY)
        return

    if service == "restart_all":
        await edit(
            texts.title(C.E["reboot"], "Restart tất cả services?"),
        )
        return

    await progress.run(
        edit,
        f"{C.E['reboot']} Đang restart <b>{texts.esc(service)}</b>...",
        _async_sh(f"systemctl restart {service}", 30),
        est=5.0,
    )
    await progress.done(edit, f"{C.E['confirm']} Đã restart <b>{texts.esc(service)}</b>")


async def _handle_confirm(edit, cid, action) -> None:
    if not can_write(cid):
        await edit(texts.NOTIFY_ONLY)
        return
    await edit(f"{C.E['info']} Đang xử lý...")
