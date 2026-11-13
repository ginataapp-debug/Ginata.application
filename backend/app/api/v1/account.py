import logging
import secrets
from datetime import timedelta
from urllib.parse import urlencode
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from backend.app.api.deps import get_current_host, bearer_scheme
from backend.app.api.v1.auth import _now, _issue_session, _response, _create_default_template, _require_smtp, _send_verification_email
from backend.app.core.config import _normalize_redirect_url, settings
from backend.app.core.database import Base, get_db
from backend.app.core.rate_limit import limit_auth_requests
from backend.app.core.security import hash_password, verify_password, hash_auth_token
from backend.app.models.models import HostUser, Organization, HostSession
from backend.app.schemas.schemas import HostAuthResponse, HostUserResponse
from backend.app.services.storage_service import MAX_IMAGE_BYTES, store_image
from backend.app.services.subscription_service import start_trial

router = APIRouter(prefix="/auth", tags=["Accounts"], dependencies=[Depends(limit_auth_requests)])
logger = logging.getLogger("uvicorn.error")


class GoogleAuthorize(BaseModel):
    redirect_to: str = Field(max_length=2048)
    code_challenge: str = Field(pattern=r"^[A-Za-z0-9_-]{43}$")


class GoogleExchange(BaseModel):
    code: str = Field(min_length=1, max_length=2048)
    code_verifier: str = Field(pattern=r"^[A-Za-z0-9._~-]{43,128}$")


def google_user(req):
    if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
        raise HTTPException(503, "Google sign-in is not configured yet")
    try:
        response = httpx.post(f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=pkce", json={"auth_code": req.code, "code_verifier": req.code_verifier}, headers={"apikey": settings.SUPABASE_ANON_KEY}, timeout=30)
        if response.status_code >= 400:
            raise HTTPException(400, "Google sign-in expired or was rejected. Please try again.")
        user = response.json()["user"]
        UUID(user["id"])
        if not user.get("email_confirmed_at") or not user.get("email") or not any(i.get("provider") == "google" for i in user.get("identities", [])):
            raise HTTPException(400, "A verified Google email is required")
        return user
    except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
        raise HTTPException(503, "Google sign-in is unavailable. Please try again.") from exc


def conflict(code, message):
    raise HTTPException(409, {"code": code, "message": message})


@router.get("/config")
def auth_config():
    return {"google_sign_in_enabled": bool(settings.SUPABASE_URL and settings.SUPABASE_ANON_KEY)}


@router.post("/google/authorize-url")
def authorize_google(req: GoogleAuthorize):
    if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
        raise HTTPException(503, "Google sign-in is not configured yet")
    redirect_to = _normalize_redirect_url(req.redirect_to)
    if redirect_to not in settings.AUTH_REDIRECT_URLS:
        raise HTTPException(400, "This sign-in redirect is not allowed")
    return {"url": f"{settings.SUPABASE_URL}/auth/v1/authorize?" + urlencode({"provider": "google", "redirect_to": redirect_to, "code_challenge": req.code_challenge, "code_challenge_method": "s256"})}


@router.post("/google", response_model=HostAuthResponse)
def sign_in_google(req: GoogleExchange, db: Session = Depends(get_db)):
    user = google_user(req)
    email = user["email"].strip().lower()
    host = db.scalar(select(HostUser).where(HostUser.supabase_user_id == user["id"]).with_for_update())
    created = False
    if host is None:
        host = db.scalar(select(HostUser).where(HostUser.email == email).with_for_update())
        if host and host.supabase_user_id and host.supabase_user_id != user["id"]:
            conflict("google_account_conflict", "This Ginata account is linked to another Google identity.")
        if host and not host.is_verified:
            conflict("link_required", "Sign in with your password first, then link Google from Account settings.")
        if host is None:
            name = str((user.get("user_metadata") or {}).get("full_name") or email.split("@")[0])[:200]
            org = Organization(name=f"{name}'s Estates", email=email, country="Kenya", currency="KES")
            db.add(org)
            db.flush()
            _create_default_template(db, org)
            start_trial(db, org.id)
            host = HostUser(organization_id=org.id, email=email, full_name=name, password_hash="", salt="", is_active=True, is_verified=True)
            db.add(host)
            created = True
        host.supabase_user_id = user["id"]
    if not host.is_active:
        raise HTTPException(403, "This account has been deactivated")
    host.google_email = email
    db.flush()
    token = _issue_session(db, host)
    db.commit()
    response = _response(host, token, "Signed in securely with Google")
    response.account_created = created
    return response


@router.post("/google/link")
def link_google(req: GoogleExchange, host: HostUser = Depends(get_current_host), db: Session = Depends(get_db)):
    user = google_user(req)
    other = db.scalar(select(HostUser).where(HostUser.supabase_user_id == user["id"], HostUser.id != host.id))
    if other or (host.supabase_user_id and host.supabase_user_id != user["id"]):
        conflict("google_account_conflict", "This Google identity is already linked to another account")
    host.supabase_user_id, host.google_email = user["id"], user["email"].lower()
    db.commit()
    return {"success": True, "google_email": host.google_email}


@router.delete("/google/link")
def unlink_google(host: HostUser = Depends(get_current_host), db: Session = Depends(get_db)):
    if not host.has_password:
        raise HTTPException(400, "Set a password before unlinking Google")
    host.supabase_user_id, host.google_email = None, None
    db.execute(delete(HostSession).where(HostSession.host_id == host.id))
    db.commit()
    return {"success": True, "message": "Google unlinked. Sign in again with your password."}


class ForgotPassword(BaseModel):
    email: EmailStr


class ResetPassword(ForgotPassword):
    code: str = Field(pattern=r"^[0-9]{6}$")
    new_password: str = Field(min_length=10, max_length=1024)


class ChangePassword(BaseModel):
    current_password: str | None = Field(default=None, max_length=1024)
    new_password: str = Field(min_length=10, max_length=1024)


@router.post("/password/forgot")
def forgot_password(req: ForgotPassword, db: Session = Depends(get_db)):
    _require_smtp()
    host = db.scalar(select(HostUser).where(HostUser.email == str(req.email).lower(), HostUser.is_active.is_(True)).with_for_update())
    if host:
        code = f"{secrets.randbelow(1_000_000):06d}"
        host.reset_code_hash, host.reset_code_salt = hash_password(code)
        host.reset_expires_at, host.reset_attempts = _now() + timedelta(minutes=30), 0
        try:
            _send_verification_email(host.email, code, purpose="reset")
            db.commit()
        except HTTPException:
            db.rollback()
            logger.warning("Password recovery email could not be delivered")
    return {"success": True, "message": "If an account exists for that email, a reset code has been sent."}


@router.post("/password/reset")
def reset_password(req: ResetPassword, db: Session = Depends(get_db)):
    host = db.scalar(select(HostUser).where(HostUser.email == str(req.email).lower()).with_for_update())
    invalid = "Reset code is invalid or expired. Request a new code."
    if not host or not host.is_active or not host.reset_expires_at or host.reset_expires_at <= _now() or host.reset_attempts >= 5:
        raise HTTPException(400, invalid)
    if not verify_password(req.code, host.reset_code_salt, host.reset_code_hash):
        host.reset_attempts += 1
        db.commit()
        raise HTTPException(400, invalid)
    host.password_hash, host.salt = hash_password(req.new_password)
    host.reset_code_hash, host.reset_code_salt, host.reset_expires_at = None, None, None
    db.execute(delete(HostSession).where(HostSession.host_id == host.id))
    db.commit()
    return {"success": True, "message": "Password updated. Sign in with your new password."}


def require_password(host, password):
    if host.has_password and (not password or not verify_password(password, host.salt, host.password_hash)):
        raise HTTPException(400, "Your current password is incorrect")


@router.post("/password/change")
def change_password(req: ChangePassword, host: HostUser = Depends(get_current_host), credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme), db: Session = Depends(get_db)):
    require_password(host, req.current_password)
    host.password_hash, host.salt = hash_password(req.new_password)
    host.reset_code_hash, host.reset_code_salt, host.reset_expires_at = None, None, None
    db.execute(delete(HostSession).where(HostSession.host_id == host.id, HostSession.token_hash != hash_auth_token(credentials.credentials)))
    db.commit()
    return {"success": True, "message": "Password updated. Other device sessions have been revoked."}


@router.post("/logout-all")
def logout_all(host: HostUser = Depends(get_current_host), db: Session = Depends(get_db)):
    db.execute(delete(HostSession).where(HostSession.host_id == host.id))
    db.commit()
    return {"success": True}


@router.post("/avatar", response_model=HostUserResponse)
def upload_avatar(file: UploadFile = File(...), host: HostUser = Depends(get_current_host), db: Session = Depends(get_db)):
    try:
        _, host.avatar_url = store_image(file.file.read(MAX_IMAGE_BYTES + 1))
        db.commit()
        return host
    finally:
        file.file.close()


@router.delete("/avatar", response_model=HostUserResponse)
def remove_avatar(host: HostUser = Depends(get_current_host), db: Session = Depends(get_db)):
    host.avatar_url = None
    db.commit()
    return host


class DeleteAccount(BaseModel):
    confirm: str
    password: str | None = Field(default=None, max_length=1024)


@router.post("/account/delete")
def delete_account(req: DeleteAccount, host: HostUser = Depends(get_current_host), credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme), db: Session = Depends(get_db)):
    if req.confirm != "DELETE":
        raise HTTPException(400, "Type DELETE to confirm permanent account deletion")
    require_password(host, req.password)
    session = db.scalar(select(HostSession).where(HostSession.token_hash == hash_auth_token(credentials.credentials)))
    if not host.has_password and session.created_at < _now() - timedelta(minutes=10):
        raise HTTPException(400, "Sign out and sign in with Google again before deleting your account")
    db.scalar(select(Organization).where(Organization.id == host.organization_id).with_for_update())
    last_host = db.scalar(select(HostUser.id).where(HostUser.organization_id == host.organization_id, HostUser.id != host.id)) is None
    scopes = {}
    for table in Base.metadata.sorted_tables:
        if table.name == "organizations":
            scopes[table.name] = table.c.id == host.organization_id if last_host else None
        elif "organization_id" in table.c:
            scopes[table.name] = table.c.organization_id == host.organization_id if last_host else (table.c.id == host.id if table.name == "host_users" else None)
        else:
            conditions = []
            for fk in table.foreign_keys:
                parent = fk.column.table
                condition = scopes.get(parent.name)
                if condition is not None:
                    conditions.append(fk.parent.in_(select(fk.column).where(condition)))
            if conditions:
                from sqlalchemy import or_
                scopes[table.name] = or_(*conditions)
    if host.supabase_user_id:
        if not settings.SUPABASE_SERVICE_ROLE_KEY:
            raise HTTPException(503, "Account deletion requires server-side Supabase configuration")
        try:
            response = httpx.delete(f"{settings.SUPABASE_URL}/auth/v1/admin/users/{host.supabase_user_id}", headers={"Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}", "apikey": settings.SUPABASE_SERVICE_ROLE_KEY}, timeout=30)
            if response.status_code not in (200, 204, 404):
                raise HTTPException(503, "Account deletion could not be completed. Please try again.")
        except httpx.HTTPError as exc:
            raise HTTPException(503, "Account deletion is unavailable") from exc
    for table in reversed(Base.metadata.sorted_tables):
        condition = scopes.get(table.name)
        if condition is not None:
            db.execute(delete(table).where(condition))
    db.commit()
    return {"success": True, "deleted_organization": last_host}
