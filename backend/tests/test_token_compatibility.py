"""Regression checks for existing sessions and invalid JWTs after library changes."""

import base64
import hashlib
import hmac
import json
import secrets
from datetime import timedelta

from app.core.config import settings
from app.core.security import create_access_token, decode_token


def test_legacy_hs256_token_remains_valid(monkeypatch):
    # Reproduce python-jose's compact HS256 format independently of the new
    # JWT library. Generate a fresh key so no reusable credential is checked in.
    key = secrets.token_urlsafe(32)
    monkeypatch.setattr(settings, "JWT_SECRET_KEY", key)
    monkeypatch.setattr(settings, "JWT_ALGORITHM", "HS256")

    def segment(value):
        raw = json.dumps(value, separators=(",", ":")).encode()
        return base64.urlsafe_b64encode(raw).rstrip(b"=")

    message = b".".join([
        segment({"alg": "HS256", "typ": "JWT"}),
        segment({"sub": "existing-session", "exp": 4102444800, "type": "access"}),
    ])
    signature = hmac.new(key.encode(), message, hashlib.sha256).digest()
    token = (message + b"." + base64.urlsafe_b64encode(signature).rstrip(b"=")).decode()
    assert decode_token(token)["sub"] == "existing-session"


def test_expired_and_tampered_tokens_are_rejected():
    expired = create_access_token("user", expires_delta=timedelta(seconds=-1))
    valid = create_access_token("user")
    header, payload, signature = valid.split(".")
    tampered = f"{header}.{payload}.{'A' if signature[0] != 'A' else 'B'}{signature[1:]}"

    assert decode_token(expired) is None
    assert decode_token(tampered) is None
