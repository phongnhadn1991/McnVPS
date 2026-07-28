"""Diem khoi chay McnVPS Telegram bot (python-telegram-bot v20+, async).

Doc token/quyen tu /var/mcnvps/.telegram_bot.conf.
Chay: python bot.py (systemd unit mcnvps-telegram-bot goi qua venv/bin/python)
"""
from __future__ import annotations

import asyncio
import logging
import os
import urllib.error
import urllib.request

from telegram import MenuButtonCommands, Update
from telegram.error import InvalidToken
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    MessageHandler,
    filters,
)

import config as C
import handlers as H
import menus
from permissions import get_user_features

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)s | %(levelname)s | %(message)s",
)
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
log = logging.getLogger("mcnvps-bot")


async def _broadcast(app: Application, text: str, kb=None) -> None:
    for cid in C.ALLOWED_CHAT_IDS:
        try:
            await app.bot.send_message(cid, text, parse_mode="HTML", reply_markup=kb)
        except Exception as e:
            log.warning("broadcast %s: %s", cid, e)


async def _monitor(app: Application) -> None:
    down: set[str] = set()
    disk_warned = False
    while True:
        try:
            php_ver = H._read_conf_val(C.FILE_INFO, "php1_version") or "8.2"
            names = ["nginx", "mariadb", f"php{php_ver}-fpm"]
            stat = await asyncio.to_thread(H._services_status, names)
            for n in names:
                if stat.get(n) != "active":
                    if n not in down:
                        await _broadcast(app, f"⚠️ Dịch vụ <b>{n}</b> KHÔNG chạy.")
                        down.add(n)
                else:
                    down.discard(n)
            raw = await asyncio.to_thread(H._sh, "df / | awk 'NR==2{print $5}' | tr -d '%'", 10)
            usage = int(raw) if raw.isdigit() else 0
            if usage >= 90 and not disk_warned:
                await _broadcast(app, f"⚠️ Ổ đĩa đã dùng {usage}%.")
                disk_warned = True
            elif usage < 90:
                disk_warned = False
        except Exception as e:
            log.warning("monitor: %s", e)
        await asyncio.sleep(300)


async def post_init(app: Application) -> None:
    try:
        await app.bot.set_my_commands([
            ("menu", "Mở menu McnVPS"),
            ("start", "Bắt đầu"),
            ("cancel", "Hủy"),
        ])
        await app.bot.set_chat_menu_button(menu_button=MenuButtonCommands())
    except Exception as e:
        log.warning("set menu button: %s", e)

    for cid in C.ALLOWED_CHAT_IDS:
        try:
            kb = menus.build_keyboard(get_user_features(cid))
            await app.bot.send_message(
                cid,
                f"🤖 <b>McnVPS Bot</b> sẵn sàng (chế độ: {C.BOT_MODE}).\n"
                f"Bấm <b>menu bên dưới</b> hoặc gõ /menu.",
                parse_mode="HTML", reply_markup=kb,
            )
        except Exception as e:
            log.warning("boot notify %s: %s", cid, e)

    app.create_task(_monitor(app))


async def on_error(update: object, context) -> None:
    log.exception("handler error: %s", getattr(context, "error", None))


BAD_TOKEN_MSG = ("BOT_TOKEN bi Telegram tu choi. Kiem tra lai token trong "
                 "/var/mcnvps/.telegram_bot.conf")


def _token_rejected() -> bool:
    try:
        with urllib.request.urlopen(
            f"https://api.telegram.org/bot{C.BOT_TOKEN}/getMe", timeout=15
        ):
            return False
    except urllib.error.HTTPError as e:
        return e.code == 401
    except Exception:
        return False


def main() -> None:
    if not C.BOT_TOKEN:
        raise SystemExit("Thieu BOT_TOKEN trong /var/mcnvps/.telegram_bot.conf")
    if _token_rejected():
        raise SystemExit(BAD_TOKEN_MSG)
    os.makedirs(C.STATE_DIR, exist_ok=True)

    app = Application.builder().token(C.BOT_TOKEN).post_init(post_init).build()
    app.add_handler(CommandHandler("start", H.start))
    app.add_handler(CommandHandler("menu", H.show_menu))
    app.add_handler(CommandHandler("cancel", H.cancel))
    app.add_handler(CallbackQueryHandler(H.on_callback))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, H.on_menu_text))
    app.add_error_handler(on_error)

    log.info("McnVPS bot dang chay (long polling)...")
    try:
        app.run_polling(allowed_updates=Update.ALL_TYPES, drop_pending_updates=True)
    except InvalidToken:
        raise SystemExit(BAD_TOKEN_MSG) from None


if __name__ == "__main__":
    main()
