"""In-memory rate limiter for login attempts."""

import time

from fastapi import HTTPException, Request, status


class LoginRateLimiter:
    """Simple in-memory rate limiter tracking attempts per IP."""

    def __init__(self, max_attempts: int = 5, window_seconds: int = 60):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self._attempts: dict[str, list[float]] = {}

    def reset(self) -> None:
        """Clear all tracked attempts (for test isolation)."""
        self._attempts.clear()

    async def __call__(self, request: Request) -> None:
        client_ip = request.headers.get("x-forwarded-for")
        if not client_ip and request.client:
            client_ip = request.client.host
        if not client_ip:
            client_ip = "unknown"

        now = time.time()
        cutoff = now - self.window_seconds

        if client_ip not in self._attempts:
            self._attempts[client_ip] = []

        # Clean up old entries
        self._attempts[client_ip] = [
            t for t in self._attempts[client_ip] if t > cutoff
        ]
        self._attempts[client_ip].append(now)

        if len(self._attempts[client_ip]) > self.max_attempts:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many login attempts. Try again later.",
            )


login_rate_limiter = LoginRateLimiter(max_attempts=5, window_seconds=60)
