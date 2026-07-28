"""Permission model cho McnVPS Telegram bot.

Actor-level check: trong group chat, chi nguoi duoc phep moi bam duoc button.
"""
from __future__ import annotations
from typing import Optional
import config as C


def is_allowed(chat_id: int) -> bool:
    return chat_id in C.ALLOWED_CHAT_IDS


def is_actor_allowed(user_id: Optional[int]) -> bool:
    if user_id is None:
        return False
    return user_id in C.ALLOWED_CHAT_IDS or user_id in C.ADMIN_IDS


def is_admin(chat_id: int) -> bool:
    return chat_id in C.ADMIN_IDS


def can_write(chat_id: int) -> bool:
    return C.BOT_MODE != "notify" and is_admin(chat_id)


def get_user_features(chat_id: int) -> Optional[set[str]]:
    if not is_allowed(chat_id):
        return set()
    if C.BOT_MODE == "notify":
        return set(C.VIEW_FEATURES)
    if is_admin(chat_id):
        return None
    return set(C.USER_FEATURES.get(chat_id, C.VIEW_FEATURES))


def can_see(feature_key: Optional[str], features: Optional[set[str]]) -> bool:
    return features is None or feature_key in features


def has_feature(chat_id: int, feature_key: str) -> bool:
    features = get_user_features(chat_id)
    return features is None or feature_key in features
