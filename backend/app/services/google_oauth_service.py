import base64
import binascii
import hashlib
import hmac
import json
import secrets
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse

import httpx
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.app.core.config import settings
from backend.app.models.models import GoogleOAuthCredential

GOOGLE_AUTHORIZATION_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"
GOOGLE_REVOCATION_URL = "https://oauth2.googleapis.com/revoke"
GOOGLE_SCOPES = (
    "openid",
    "email",
    "https://www.googleapis.com/auth/forms.body",
    "https://www.googleapis.com/auth/forms.responses.readonly",
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive.file",
)
GOOGLE_API_SCOPES = frozenset(GOOGLE_SCOPES[2:])


class GoogleOAuthError(Exception):
    pass


class GoogleOAuthUnavailable(GoogleOAuthError):
    """Transient failure reaching Google; the stored credential may still be valid."""


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _b64encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _b64decode(value: str) -> bytes:
    padded = value + "=" * (-len(value) % 4)
    return base64.b64decode(padded, altchars=b"-_", validate=True)


def _encryption_key() -> bytes:
    configured = settings.GOOGLE_TOKEN_ENCRYPTION_KEY.strip()
    try:
        key = base64.b64decode(configured, altchars=b"-_", validate=True)
    except (ValueError, binascii.Error) as exc:
        raise GoogleOAuthError("GOOGLE_TOKEN_ENCRYPTION_KEY must be a base64-encoded 32-byte key.") from exc
    if len(key) != 32:
        raise GoogleOAuthError("GOOGLE_TOKEN_ENCRYPTION_KEY must be a base64-encoded 32-byte key.")
    return key


def validate_google_oauth_config() -> None:
    required = {
        "GOOGLE_CLIENT_ID": settings.GOOGLE_CLIENT_ID,
        "GOOGLE_CLIENT_SECRET": settings.GOOGLE_CLIENT_SECRET,
        "GOOGLE_REDIRECT_URI": settings.GOOGLE_REDIRECT_URI,
        "GOOGLE_TOKEN_ENCRYPTION_KEY": settings.GOOGLE_TOKEN_ENCRYPTION_KEY,
        "GOOGLE_OAUTH_STATE_SECRET": settings.GOOGLE_OAUTH_STATE_SECRET,
    }
    missing = [name for name, value in required.items() if not value.strip()]
    if missing:
        raise GoogleOAuthError("Google OAuth is not configured. Set " + ", ".join(missing) + ".")
    if len(settings.GOOGLE_OAUTH_STATE_SECRET.encode("utf-8")) < 32:
        raise GoogleOAuthError("GOOGLE_OAUTH_STATE_SECRET must contain at least 32 bytes.")
    _encryption_key()
    redirect = urlparse(settings.GOOGLE_REDIRECT_URI)
    local_http = redirect.scheme == "http" and redirect.hostname in {"localhost", "127.0.0.1"}
    expected_path = f"{settings.API_V1_STR}/integrations/google/callback"
    if (
        (redirect.scheme != "https" and not local_http)
        or not redirect.netloc
        or redirect.path != expected_path
        or redirect.query
        or redirect.fragment
    ):
        raise GoogleOAuthError(f"GOOGLE_REDIRECT_URI must use HTTPS (or loopback HTTP locally) and end with {expected_path}.")


def create_google_oauth_state(host_id: str) -> tuple[str, str, datetime]:
    nonce = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.GOOGLE_OAUTH_STATE_TTL_MINUTES)
    payload = {
        "host_id": host_id,
        "nonce": nonce,
        "exp": int(expires_at.timestamp()),
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
    }
    encoded = _b64encode(json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8"))
    signature = hmac.new(
        settings.GOOGLE_OAUTH_STATE_SECRET.encode("utf-8"), encoded.encode("ascii"), hashlib.sha256
    ).digest()
    expires_naive = expires_at.replace(tzinfo=None)
    return f"{encoded}.{_b64encode(signature)}", hashlib.sha256(nonce.encode("utf-8")).hexdigest(), expires_naive


def verify_google_oauth_state(state: str) -> dict:
    if not state or len(state) > 4096 or state.count(".") != 1:
        raise GoogleOAuthError("Google connection state is invalid. Start the connection again.")
    encoded, supplied_signature = state.split(".")
    try:
        expected_signature = hmac.new(
            settings.GOOGLE_OAUTH_STATE_SECRET.encode("utf-8"), encoded.encode("ascii"), hashlib.sha256
        ).digest()
        if not hmac.compare_digest(_b64decode(supplied_signature), expected_signature):
            raise GoogleOAuthError("Google connection state is invalid. Start the connection again.")
        payload = json.loads(_b64decode(encoded))
    except (ValueError, UnicodeDecodeError, UnicodeEncodeError, json.JSONDecodeError, binascii.Error) as exc:
        raise GoogleOAuthError("Google connection state is invalid. Start the connection again.") from exc
    if not isinstance(payload, dict) or set(payload) != {"host_id", "nonce", "exp", "redirect_uri"}:
        raise GoogleOAuthError("Google connection state is invalid. Start the connection again.")
    if (
        not isinstance(payload["host_id"], str)
        or not payload["host_id"]
        or not isinstance(payload["nonce"], str)
        or not payload["nonce"]
        or not isinstance(payload["exp"], int)
        or isinstance(payload["exp"], bool)
        or payload["exp"] <= int(datetime.now(timezone.utc).timestamp())
        or payload["redirect_uri"] != settings.GOOGLE_REDIRECT_URI
    ):
        raise GoogleOAuthError("Google connection state is invalid or expired. Start the connection again.")
    return payload


def google_oauth_nonce_hash(nonce: str) -> str:
    return hashlib.sha256(nonce.encode("utf-8")).hexdigest()


def encrypt_google_refresh_token(refresh_token: str, host_id: str) -> str:
    if not refresh_token:
        raise GoogleOAuthError("Google did not provide a refresh token.")
    nonce = secrets.token_bytes(12)
    associated_data = f"ginata-google-oauth:{host_id}".encode("utf-8")
    encrypted = AESGCM(_encryption_key()).encrypt(nonce, refresh_token.encode("utf-8"), associated_data)
    return "v1." + _b64encode(nonce + encrypted)


def decrypt_google_refresh_token(encrypted_token: str, host_id: str) -> str:
    try:
        version, encoded = encrypted_token.split(".", 1)
        if version != "v1":
            raise ValueError("Unsupported version")
        raw = _b64decode(encoded)
        if len(raw) < 29:
            raise ValueError("Invalid ciphertext")
        associated_data = f"ginata-google-oauth:{host_id}".encode("utf-8")
        plaintext = AESGCM(_encryption_key()).decrypt(raw[:12], raw[12:], associated_data)
        return plaintext.decode("utf-8")
    except (ValueError, UnicodeDecodeError, InvalidTag, binascii.Error) as exc:
        raise GoogleOAuthError("The stored Google credential could not be decrypted. Reconnect the Google account.") from exc


def _post_google_form(url: str, data: dict) -> dict:
    try:
        response = httpx.post(url, data=data, timeout=15)
    except httpx.HTTPError as exc:
        raise GoogleOAuthUnavailable("Google could not be reached. Please try again.") from exc
    if response.status_code == 429 or response.status_code >= 500:
        raise GoogleOAuthUnavailable("Google is temporarily unavailable. Please try again.")
    if response.status_code != 200:
        raise GoogleOAuthError("Google rejected the OAuth request. Start the connection again.")
    try:
        payload = response.json()
    except ValueError as exc:
        raise GoogleOAuthError("Google returned an invalid OAuth response.") from exc
    if not isinstance(payload, dict):
        raise GoogleOAuthError("Google returned an invalid OAuth response.")
    return payload


def exchange_google_authorization_code(code: str) -> dict:
    payload = _post_google_form(GOOGLE_TOKEN_URL, {
        "code": code,
        "client_id": settings.GOOGLE_CLIENT_ID,
        "client_secret": settings.GOOGLE_CLIENT_SECRET,
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
        "grant_type": "authorization_code",
    })
    if not isinstance(payload.get("access_token"), str) or not payload["access_token"]:
        raise GoogleOAuthError("Google did not provide an access token.")
    return payload


def fetch_google_identity(access_token: str) -> dict:
    try:
        response = httpx.get(
            GOOGLE_USERINFO_URL, headers={"Authorization": f"Bearer {access_token}"}, timeout=15
        )
    except httpx.HTTPError as exc:
        raise GoogleOAuthError("Google account details could not be retrieved.") from exc
    if response.status_code != 200:
        raise GoogleOAuthError("Google account details could not be verified.")
    try:
        identity = response.json()
    except ValueError as exc:
        raise GoogleOAuthError("Google returned invalid account details.") from exc
    if (
        not isinstance(identity, dict)
        or not isinstance(identity.get("sub"), str)
        or not identity["sub"]
        or not isinstance(identity.get("email"), str)
        or not identity["email"]
        or identity.get("email_verified") is not True
    ):
        raise GoogleOAuthError("A verified Google account email is required.")
    return identity


def get_valid_google_access_token(db: Session, host_id: str) -> str:
    validate_google_oauth_config()
    credential = db.execute(
        select(GoogleOAuthCredential).where(GoogleOAuthCredential.host_id == host_id)
    ).scalar_one_or_none()
    if credential is None:
        raise GoogleOAuthError("No Google account is connected for this host.")
    refresh_token = decrypt_google_refresh_token(credential.encrypted_refresh_token, host_id)
    payload = _post_google_form(GOOGLE_TOKEN_URL, {
        "client_id": settings.GOOGLE_CLIENT_ID,
        "client_secret": settings.GOOGLE_CLIENT_SECRET,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token",
    })
    access_token = payload.get("access_token")
    if not isinstance(access_token, str) or not access_token:
        raise GoogleOAuthError("Google did not provide a refreshed access token. Reconnect the Google account.")
    if isinstance(payload.get("refresh_token"), str) and payload["refresh_token"]:
        credential.encrypted_refresh_token = encrypt_google_refresh_token(payload["refresh_token"], host_id)
    credential.last_refreshed_at = _now()
    db.commit()
    return access_token


def revoke_google_refresh_token(refresh_token: str) -> None:
    try:
        response = httpx.post(GOOGLE_REVOCATION_URL, data={"token": refresh_token}, timeout=15)
    except httpx.HTTPError as exc:
        raise GoogleOAuthError("Google could not be reached. The account remains connected; try again.") from exc
    if response.status_code not in {200, 400}:
        raise GoogleOAuthError("Google access could not be revoked. The account remains connected; try again.")
