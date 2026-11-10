import hashlib
import hmac
import secrets
from typing import Optional, Tuple

PASSWORD_ITERATIONS = 600_000
PASSWORD_PREFIX = f"pbkdf2_sha256${PASSWORD_ITERATIONS}$"


def generate_salt(length: int = 16) -> str:
    return secrets.token_hex(length)


def hash_password(password: str, salt: Optional[str] = None) -> Tuple[str, str]:
    """Versioned PBKDF2-SHA256; passwords are never stripped or normalized."""
    if salt is None:
        salt = generate_salt()
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), PASSWORD_ITERATIONS)
    return PASSWORD_PREFIX + key.hex(), salt


def verify_password(plain_password: str, salt: str, expected_hash: str) -> bool:
    """Also accept the original unversioned 100,000-iteration hashes."""
    if not salt or not expected_hash:
        return False
    iterations = 100_000
    digest = expected_hash
    if "$" in expected_hash:
        parts = expected_hash.split("$")
        if len(parts) != 3 or parts[0] != "pbkdf2_sha256":
            return False
        try:
            iterations = int(parts[1])
        except ValueError:
            return False
        if iterations not in (100_000, PASSWORD_ITERATIONS):
            return False
        digest = parts[2]
    key = hashlib.pbkdf2_hmac("sha256", plain_password.encode("utf-8"), salt.encode("utf-8"), iterations)
    return hmac.compare_digest(key.hex(), digest)


def password_needs_upgrade(password_hash: str) -> bool:
    return not password_hash.startswith(PASSWORD_PREFIX)


def generate_auth_token() -> str:
    return secrets.token_urlsafe(48)


def hash_auth_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
