"""
Password hashing helpers for Velare.

All new passwords entering the database go through `hash_password()`. All
verification calls go through `verify_password()`, which transparently
upgrades legacy plain-text rows the first time a user successfully logs in
or changes their password — so we don't have to break existing users when
rolling out hashing.
"""

from typing import Optional

import bcrypt


# Bcrypt always emits 60-char hashes that begin with "$2b$" (or "$2a$"/"$2y$").
# We use this prefix check to detect already-hashed values so we don't double
# hash and to identify legacy plain-text rows that still need upgrading.
_BCRYPT_PREFIXES = ("$2a$", "$2b$", "$2y$")

# 12 rounds gives ~250 ms per hash on a typical Railway worker — strong enough
# without making login feel sluggish. Bump only if your hardware is much faster.
_BCRYPT_ROUNDS = 12


def is_hashed(value: Optional[str]) -> bool:
    """Return True if `value` already looks like a bcrypt hash."""
    if not value or not isinstance(value, str):
        return False
    return value.startswith(_BCRYPT_PREFIXES) and len(value) == 60


def hash_password(plain_password: str) -> str:
    """Hash a plain password with bcrypt.

    If `plain_password` is already a bcrypt hash, return it untouched. This
    makes the helper idempotent so callers don't have to track whether a
    value has been hashed yet.
    """
    if not plain_password:
        raise ValueError("Cannot hash an empty password")

    if is_hashed(plain_password):
        return plain_password

    salt = bcrypt.gensalt(rounds=_BCRYPT_ROUNDS)
    return bcrypt.hashpw(plain_password.encode("utf-8"), salt).decode("utf-8")


def verify_password(plain_password: str, stored_value: Optional[str]) -> bool:
    """Verify a candidate plain password against a stored value.

    Supports two formats for `stored_value`:
      1. A bcrypt hash (current format) — verified with `bcrypt.checkpw`.
      2. A plain-text legacy value — verified with a constant-time string
         compare so legacy users can still log in until their row is upgraded.

    Callers that want to upgrade legacy rows on successful login should check
    `needs_upgrade(stored_value)` after a `True` result and re-hash the
    password into the database.
    """
    if not plain_password or not stored_value:
        return False

    # New-format bcrypt path
    if is_hashed(stored_value):
        try:
            return bcrypt.checkpw(
                plain_password.encode("utf-8"),
                stored_value.encode("utf-8"),
            )
        except (ValueError, TypeError):
            return False

    # Legacy plain-text path — use a constant-time comparison so a timing
    # attacker cannot probe the stored password byte by byte.
    return _constant_time_equals(plain_password, stored_value)


def needs_upgrade(stored_value: Optional[str]) -> bool:
    """Return True if a successful login should trigger a re-hash."""
    return bool(stored_value) and not is_hashed(stored_value)


def _constant_time_equals(a: str, b: str) -> bool:
    """Constant-time string comparison to avoid timing attacks on legacy rows."""
    if a is None or b is None:
        return False
    if len(a) != len(b):
        return False
    result = 0
    for x, y in zip(a, b):
        result |= ord(x) ^ ord(y)
    return result == 0
