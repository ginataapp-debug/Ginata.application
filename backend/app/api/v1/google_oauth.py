from datetime import datetime, timezone
from html import escape
import logging
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy import delete, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from backend.app.api.deps import get_current_host
from backend.app.core.config import settings
from backend.app.core.database import get_db
from backend.app.models.models import GoogleOAuthCredential, GoogleOAuthState, HostUser
from backend.app.services.audit_service import log_audit_event
from backend.app.services.google_oauth_service import (
    GOOGLE_API_SCOPES,
    GOOGLE_AUTHORIZATION_URL,
    GOOGLE_SCOPES,
    GoogleOAuthError,
    create_google_oauth_state,
    decrypt_google_refresh_token,
    encrypt_google_refresh_token,
    exchange_google_authorization_code,
    fetch_google_identity,
    google_oauth_nonce_hash,
    revoke_google_refresh_token,
    validate_google_oauth_config,
    verify_google_oauth_state,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/integrations/google", tags=["Google Integration"])


class OAuthCallbackError(Exception):
    pass


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _result_page(title: str, message: str, success: bool, status_code: int) -> HTMLResponse:
    color = "#173e35" if success else "#8a3f35"
    content = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{escape(title)} · Ginata</title></head>
<body style="margin:0;background:#fbf9f4;color:#253b33;font-family:system-ui,sans-serif;display:grid;place-items:center;min-height:100vh">
<main style="box-sizing:border-box;max-width:560px;margin:24px;padding:40px;background:#fffefa;border:1px solid #dfe3d8;border-radius:24px;text-align:center">
<div style="width:48px;height:48px;margin:auto;border-radius:50%;background:{color};color:white;display:grid;place-items:center;font-size:26px">{'✓' if success else '!'}</div>
<h1 style="color:{color};font-size:30px;line-height:1.2">{escape(title)}</h1>
<p style="font-size:17px;line-height:1.6">{escape(message)}</p>
<p style="font-size:14px;color:#6e756c">You can close this window and return to Ginata.</p>
</main></body></html>"""
    return HTMLResponse(content, status_code=status_code, headers={
        "Cache-Control": "no-store",
        "Referrer-Policy": "no-referrer",
        "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    })


def _consume_state(db: Session, state: str) -> HostUser:
    try:
        payload = verify_google_oauth_state(state)
    except GoogleOAuthError as exc:
        raise OAuthCallbackError(str(exc)) from exc
    host = db.get(HostUser, payload["host_id"])
    if host is None or not host.is_active or (settings.REQUIRE_EMAIL_VERIFICATION and not host.is_verified):
        raise OAuthCallbackError("The Ginata host session is no longer eligible to connect Google. Sign in and try again.")
    now = _now()
    result = db.execute(update(GoogleOAuthState).where(
        GoogleOAuthState.nonce_hash == google_oauth_nonce_hash(payload["nonce"]),
        GoogleOAuthState.host_id == host.id,
        GoogleOAuthState.consumed_at.is_(None),
        GoogleOAuthState.expires_at > now,
    ).values(consumed_at=now))
    if result.rowcount != 1:
        db.rollback()
        raise OAuthCallbackError("Google connection state is invalid, expired, or already used. Start again from Ginata.")
    db.commit()
    return host


@router.get("/authorize")
def authorize_google(
    host: HostUser = Depends(get_current_host),
    db: Session = Depends(get_db),
):
    try:
        validate_google_oauth_config()
        state, nonce_hash, expires_at = create_google_oauth_state(host.id)
    except GoogleOAuthError as exc:
        raise HTTPException(503, str(exc)) from exc
    now = _now()
    db.execute(delete(GoogleOAuthState).where(
        GoogleOAuthState.host_id == host.id,
        or_(GoogleOAuthState.consumed_at.is_not(None), GoogleOAuthState.expires_at <= now),
    ))
    db.add(GoogleOAuthState(host_id=host.id, nonce_hash=nonce_hash, expires_at=expires_at))
    db.commit()
    authorization_url = GOOGLE_AUTHORIZATION_URL + "?" + urlencode({
        "client_id": settings.GOOGLE_CLIENT_ID,
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
        "response_type": "code",
        "scope": " ".join(GOOGLE_SCOPES),
        "access_type": "offline",
        "prompt": "consent",
        "include_granted_scopes": "true",
        "state": state,
    })
    return {"authorization_url": authorization_url, "expires_in": settings.GOOGLE_OAUTH_STATE_TTL_MINUTES * 60}


@router.get("/callback", response_class=HTMLResponse)
def google_callback(
    code: str | None = None,
    state: str | None = None,
    error: str | None = None,
    db: Session = Depends(get_db),
):
    try:
        validate_google_oauth_config()
        if not state:
            raise OAuthCallbackError("Google connection state is missing. Start again from Ginata.")
        host = _consume_state(db, state)
        if error:
            raise OAuthCallbackError("Google connection was cancelled or denied. No Google account was connected.")
        if not code:
            raise OAuthCallbackError("Google did not return an authorization code. Start again from Ginata.")
        tokens = exchange_google_authorization_code(code)
        identity = fetch_google_identity(tokens["access_token"])
        granted_scopes = set(tokens.get("scope", "").split()) if tokens.get("scope") else set(GOOGLE_SCOPES)
        if not GOOGLE_API_SCOPES.issubset(granted_scopes):
            raise OAuthCallbackError("All requested Forms, Sheets, and Drive permissions are required. Reconnect and approve them.")

        credential = db.execute(select(GoogleOAuthCredential).where(
            GoogleOAuthCredential.host_id == host.id
        )).scalar_one_or_none()
        other_owner = db.execute(select(GoogleOAuthCredential).where(
            GoogleOAuthCredential.provider_account_id == identity["sub"]
        )).scalar_one_or_none()
        if other_owner is not None and other_owner.host_id != host.id:
            raise OAuthCallbackError("This Google account is already connected to another Ginata host.")

        new_refresh_token = tokens.get("refresh_token")
        if isinstance(new_refresh_token, str) and new_refresh_token:
            encrypted_refresh_token = encrypt_google_refresh_token(new_refresh_token, host.id)
        elif credential is not None and credential.provider_account_id == identity["sub"]:
            encrypted_refresh_token = credential.encrypted_refresh_token
        else:
            raise OAuthCallbackError("Google did not provide offline access. Reconnect and approve all requested permissions.")

        if credential is None:
            credential = GoogleOAuthCredential(host_id=host.id, provider_account_id=identity["sub"])
            db.add(credential)
        credential.provider_account_id = identity["sub"]
        credential.email = identity["email"].strip().lower()
        credential.scopes = sorted(granted_scopes)
        credential.encrypted_refresh_token = encrypted_refresh_token
        log_audit_event(
            db=db,
            organization_id=host.organization_id,
            entity_type="google_oauth_credential",
            entity_id=host.id,
            action="google_account_connected",
            actor_name=host.full_name,
            details={"google_email": credential.email},
        )
        db.commit()
        return _result_page("Google connected", "Your Google account is securely connected to your Ginata host account.", True, 200)
    except (OAuthCallbackError, GoogleOAuthError) as exc:
        db.rollback()
        return _result_page("Google not connected", str(exc), False, 400)
    except IntegrityError:
        db.rollback()
        return _result_page(
            "Google not connected", "This Google account could not be linked. Check whether it belongs to another host and try again.", False, 409
        )
    except Exception as exc:
        db.rollback()
        logger.error("Google OAuth callback failed: %s", type(exc).__name__)
        return _result_page("Google not connected", "An unexpected server error occurred. Please try again.", False, 500)


@router.get("/status")
def google_status(
    host: HostUser = Depends(get_current_host),
    db: Session = Depends(get_db),
):
    credential = db.execute(select(GoogleOAuthCredential).where(
        GoogleOAuthCredential.host_id == host.id
    )).scalar_one_or_none()
    if credential is None:
        return {"connected": False, "email": None, "scopes": [], "connected_at": None}
    return {
        "connected": True,
        "email": credential.email,
        "scopes": credential.scopes,
        "connected_at": credential.created_at,
    }


@router.delete("/connection")
def disconnect_google(
    host: HostUser = Depends(get_current_host),
    db: Session = Depends(get_db),
):
    credential = db.execute(select(GoogleOAuthCredential).where(
        GoogleOAuthCredential.host_id == host.id
    )).scalar_one_or_none()
    if credential is None:
        return {"success": True, "message": "No Google account is connected."}
    try:
        validate_google_oauth_config()
        refresh_token = decrypt_google_refresh_token(credential.encrypted_refresh_token, host.id)
        revoke_google_refresh_token(refresh_token)
    except GoogleOAuthError as exc:
        db.rollback()
        raise HTTPException(502, str(exc)) from exc
    connected_email = credential.email
    db.delete(credential)
    db.execute(delete(GoogleOAuthState).where(
        GoogleOAuthState.host_id == host.id, GoogleOAuthState.consumed_at.is_(None)
    ))
    log_audit_event(
        db=db,
        organization_id=host.organization_id,
        entity_type="google_oauth_credential",
        entity_id=host.id,
        action="google_account_disconnected",
        actor_name=host.full_name,
        details={"google_email": connected_email},
    )
    db.commit()
    return {"success": True, "message": "Google account disconnected and access revoked."}
