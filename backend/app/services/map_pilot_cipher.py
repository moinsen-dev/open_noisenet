"""Encrypt private pilot payloads; key is supplied externally, never in the DB."""
import base64
import binascii
import json
import os
from datetime import date
from uuid import UUID
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from app.core.config import settings


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


def _aad(user_id: UUID, day: date) -> bytes:
    return f'noisenet-pilot-v1:{user_id}:{day.isoformat()}'.encode('ascii')


def encrypt_payload(user_id: UUID, day: date, cell_id: str, level_band: str) -> tuple[bytes, bytes]:
    payload = json.dumps({'cell_id': cell_id, 'level_band': level_band}, separators=(',', ':'), sort_keys=True).encode('utf-8')
    nonce = os.urandom(12)
    return nonce, AESGCM(_key()).encrypt(nonce, payload, _aad(user_id, day))


def decrypt_payload(user_id: UUID, day: date, nonce: bytes, ciphertext: bytes) -> dict:
    try:
        value = json.loads(AESGCM(_key()).decrypt(nonce, ciphertext, _aad(user_id, day)))
        if not isinstance(value, dict) or set(value) != {'cell_id', 'level_band'}:
            raise ValueError()
        return value
    except (InvalidTag, ValueError, UnicodeDecodeError, TypeError):
        raise PilotCipherUnavailable() from None
