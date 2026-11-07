"""Encrypt private pilot payloads; key is supplied externally, never in the DB."""
import base64
import binascii
import json
import os
import hashlib
import hmac
from datetime import date
from uuid import UUID
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from app.core.config import settings
from app.db.models.map_pilot import MapPilotContribution, MapPilotKeyState
from sqlalchemy import func, select


class PilotCipherUnavailable(Exception):
    """Missing, invalid, changed or corrupted pilot encryption state."""


def _key() -> bytes:
    try:
        raw = base64.b64decode(settings.MAP_PILOT_ENCRYPTION_KEY.get_secret_value(), validate=True)
    except (ValueError, binascii.Error):
        raise PilotCipherUnavailable() from None
    if len(raw) != 32:
        raise PilotCipherUnavailable()
    return raw


def ensure_key_available() -> None:
    _key()


async def ensure_database_key(db) -> None:
    """Forbid accidental mixed keys; caller holds the row until commit.

    Existing unmarked contributions need a separately planned migration. The
    key check is an HMAC keyed by the required random 256-bit encryption key.
    """
    tag = hmac.new(_key(), b'OpenNoiseNet pilot key continuity v1', hashlib.sha256).digest()
    state = await db.scalar(select(MapPilotKeyState).where(MapPilotKeyState.name == 'pilot').with_for_update())
    if not state:
        raise PilotCipherUnavailable()
    if state.key_check is None:
        if await db.scalar(select(func.count()).select_from(MapPilotContribution)):
            raise PilotCipherUnavailable()
        state.key_check = tag
        await db.flush()
    elif not hmac.compare_digest(state.key_check, tag):
        raise PilotCipherUnavailable()


def _aad(user_id: UUID, day: date) -> bytes:
    return f'noisenet-pilot-v1:{user_id}:{day.isoformat()}'.encode('ascii')


def encrypt_payload(user_id: UUID, day: date, cell_id: str, level_band: str) -> tuple[bytes, bytes]:
    return _encrypt_with_key(_key(), user_id, day, cell_id, level_band)


def _encrypt_with_key(key: bytes, user_id: UUID, day: date, cell_id: str, level_band: str) -> tuple[bytes, bytes]:
    payload = json.dumps({'cell_id': cell_id, 'level_band': level_band}, separators=(',', ':'), sort_keys=True).encode('utf-8')
    nonce = os.urandom(12)
    return nonce, AESGCM(key).encrypt(nonce, payload, _aad(user_id, day))


def decrypt_payload(user_id: UUID, day: date, nonce: bytes, ciphertext: bytes) -> dict:
    return _decrypt_with_key(_key(), user_id, day, nonce, ciphertext)


def _decrypt_with_key(key: bytes, user_id: UUID, day: date, nonce: bytes, ciphertext: bytes) -> dict:
    try:
        value = json.loads(AESGCM(key).decrypt(nonce, ciphertext, _aad(user_id, day)))
        if not isinstance(value, dict) or set(value) != {'cell_id', 'level_band'}:
            raise ValueError()
        return value
    except (InvalidTag, ValueError, UnicodeDecodeError, TypeError):
        raise PilotCipherUnavailable() from None


async def rotate_database_key(db, new_key: bytes) -> None:
    """Rotate within caller's transaction; operator must quiesce all workers.

    The caller supplies a random new key through a protected secret mechanism,
    commits only after success, then restarts with the new secret. No endpoint
    or scheduled job invokes this primitive. On any error caller must roll back.
    """
    if len(new_key) != 32:
        raise PilotCipherUnavailable()
    old_key = _key()
    await ensure_database_key(db)  # Locks the singleton and verifies old key.
    state = await db.scalar(select(MapPilotKeyState).where(MapPilotKeyState.name == 'pilot').with_for_update())
    rows = (await db.scalars(select(MapPilotContribution).with_for_update())).all()
    for row in rows:
        payload = _decrypt_with_key(old_key, row.user_id, row.day, row.payload_nonce, row.payload_ciphertext)
        row.payload_nonce, row.payload_ciphertext = _encrypt_with_key(
            new_key, row.user_id, row.day, payload['cell_id'], payload['level_band'])
    state.key_check = hmac.new(new_key, b'OpenNoiseNet pilot key continuity v1', hashlib.sha256).digest()
    await db.flush()
