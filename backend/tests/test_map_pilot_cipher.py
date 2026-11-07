"""Encryption, binding and failure safety for synthetic pilot data."""
import base64
import uuid
from datetime import date
import pytest
from pydantic import SecretStr
from app.core.config import settings
from app.services.map_pilot_cipher import PilotCipherUnavailable, decrypt_payload, encrypt_payload, ensure_key_available


@pytest.fixture
def key(monkeypatch):
    monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b'k'*32).decode()))


def test_cipher_round_trip_random_nonces_and_binding(key, monkeypatch):
    user, day = uuid.uuid4(), date(2026, 11, 7)
    first = encrypt_payload(user, day, 'private-area', 'high')
    second = encrypt_payload(user, day, 'private-area', 'high')
    assert first != second and len(first[0]) == 12
    assert b'private-area' not in first[1] and b'high' not in first[1]
    assert decrypt_payload(user, day, *first) == {'cell_id':'private-area', 'level_band':'high'}
    for other_user, other_day in [(uuid.uuid4(), day), (user, date(2026,11,6))]:
        with pytest.raises(PilotCipherUnavailable): decrypt_payload(other_user, other_day, *first)
    with pytest.raises(PilotCipherUnavailable): decrypt_payload(user, day, first[0], first[1][:-1] + bytes([first[1][-1]^1]))
    monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b'x'*32).decode()))
    with pytest.raises(PilotCipherUnavailable): decrypt_payload(user, day, *first)


def test_invalid_or_absent_keys_fail_closed(monkeypatch):
    for value in ('', 'bad!', base64.b64encode(b'x'*31).decode()):
        monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(value))
        with pytest.raises(PilotCipherUnavailable): ensure_key_available()
