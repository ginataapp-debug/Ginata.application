from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
import secrets
import smtplib
import ssl

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError

from backend.app.core.database import get_db
from backend.app.core.config import settings
from backend.app.core.security import (
    hash_password, verify_password, generate_auth_token, hash_auth_token, password_needs_upgrade,
)
from backend.app.api.deps import get_current_host, bearer_scheme
from backend.app.models.models import (
    Organization, HostUser, HostSession, HostEmailVerification, DocumentTemplate, generate_uuid,
)
from backend.app.schemas.schemas import (
    HostSignUpRequest, HostLoginRequest, HostAuthResponse, HostUserResponse, HostProfileUpdateRequest,
    HostVerificationSendRequest, HostVerificationRequest,
)
from backend.app.services.audit_service import log_audit_event
from backend.app.services.subscription_service import start_trial
from backend.app.core.rate_limit import limit_auth_requests

router = APIRouter(prefix="/auth", tags=["Host Authentication"], dependencies=[Depends(limit_auth_requests)])


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _issue_session(db: Session, host: HostUser) -> str:
    token = generate_auth_token()
    db.add(HostSession(
        host_id=host.id, token_hash=hash_auth_token(token),
        expires_at=_now() + timedelta(hours=settings.AUTH_SESSION_TTL_HOURS),
    ))
    host.session_token = None
    host.last_login_at = _now()
    return token


def _require_smtp() -> None:
    if not settings.SMTP_HOST or not settings.SMTP_FROM_EMAIL:
        raise HTTPException(503, "Email delivery is not configured. Set SMTP_HOST and SMTP_FROM_EMAIL.")
    if not settings.SMTP_USE_SSL and not settings.SMTP_STARTTLS:
        raise HTTPException(503, "Email verification service requires SMTP SSL or STARTTLS.")


def _send_verification_email(email: str, code: str, purpose: str = "verification") -> None:
    _require_smtp()
    message = EmailMessage()
    message["Subject"] = "Reset your Ginata password" if purpose == "reset" else "Confirm your Ginata email address"
    message["From"] = settings.SMTP_FROM_EMAIL
    message["To"] = email
    message.set_content(
        f"Your Ginata confirmation code is {code}.\n"
        f"It expires in {30 if purpose == 'reset' else settings.EMAIL_OTP_TTL_MINUTES} minutes and can be used once.\n"
        "If you did not request this code, ignore this email."
    )
    context = ssl.create_default_context()
    try:
        if settings.SMTP_USE_SSL:
            connection = smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15, context=context)
        else:
            connection = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15)
        with connection as smtp:
            if not settings.SMTP_USE_SSL:
                smtp.starttls(context=context)
            if settings.SMTP_USERNAME:
                smtp.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            if smtp.send_message(message):
                raise smtplib.SMTPException("Recipient refused")
    except (OSError, smtplib.SMTPException) as exc:
        raise HTTPException(503, "Unable to deliver the confirmation email. Please try again later.") from exc


def _create_verification(db: Session, host: HostUser) -> None:
    _require_smtp()
    now = _now()
    latest = db.execute(
        select(HostEmailVerification).where(HostEmailVerification.host_id == host.id)
        .order_by(HostEmailVerification.created_at.desc()).limit(1)
    ).scalar_one_or_none()
    if latest and (now - latest.created_at).total_seconds() < settings.EMAIL_OTP_RESEND_SECONDS:
        raise HTTPException(429, "Please wait before requesting another confirmation code.")
    db.execute(update(HostEmailVerification).where(
        HostEmailVerification.host_id == host.id, HostEmailVerification.consumed_at.is_(None),
    ).values(consumed_at=now))
    verification_id = generate_uuid()
    code = f"{secrets.randbelow(1_000_000):06d}"
    # Slow, per-challenge salted hashes protect low-entropy codes at rest.
    code_hash, _ = hash_password(code, salt=verification_id)
    db.add(HostEmailVerification(
        id=verification_id, host_id=host.id, email=host.email, code_hash=code_hash,
        expires_at=now + timedelta(minutes=settings.EMAIL_OTP_TTL_MINUTES), created_at=now,
    ))
    db.flush()
    _send_verification_email(host.email, code)


def _authenticate(db: Session, email: str, password: str) -> HostUser:
    host = db.execute(select(HostUser).where(HostUser.email == email.strip().lower())).scalar_one_or_none()
    if not host or not verify_password(password, host.salt, host.password_hash):
        raise HTTPException(401, "Invalid email or password. Please check your credentials.")
    if not host.is_active:
        raise HTTPException(403, "This host account has been suspended or deactivated.")
    if password_needs_upgrade(host.password_hash):
        host.password_hash, host.salt = hash_password(password)
    return host


def _response(host: HostUser, token: str | None, message: str, verification_required: bool = False) -> HostAuthResponse:
    return HostAuthResponse(
        success=True, token=token, host=HostUserResponse.model_validate(host),
        organization_id=host.organization_id, message=message, verification_required=verification_required,
    )


def _create_default_template(db: Session, org: Organization) -> None:
    tpl = DocumentTemplate(
        organization_id=org.id,
        name="Standard Minimalist Luxury",
        layout_style="minimalist_luxury",
        primary_color="#003329",
        secondary_color="#466557",
        font_family="Plus Jakarta Sans",
        header_text=org.name,
        footer_text="Thank you for staying with us.",
        payment_instructions="Contact host for payment details",
        tax_notes="Tax amounts are itemized where applicable.",
        is_default=True,
    )
    db.add(tpl)

@router.post("/signup", response_model=HostAuthResponse, status_code=status.HTTP_201_CREATED)
def host_signup(
    req: HostSignUpRequest,
    db: Session = Depends(get_db)
):
    """Create a private organization; only an email OTP can mark a host verified."""
    if settings.REQUIRE_EMAIL_VERIFICATION:
        _require_smtp()
    clean_email = str(req.email).strip().lower()
    clean_name = req.full_name.strip()

    existing = db.execute(select(HostUser).where(HostUser.email == clean_email)).scalar_one_or_none()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A host account with this email address already exists. Please sign in."
        )

    org = Organization(
        name=(req.organization_name or f"{clean_name}'s Estates").strip(),
        currency="KES",
        email=clean_email,
        phone=req.phone.strip() if req.phone else None,
        city="Nairobi",
        country="Kenya",
    )
    db.add(org)
    db.flush()
    _create_default_template(db, org)
    start_trial(db, org.id)

    pwd_hash, salt = hash_password(req.password)
    host_user = HostUser(
        organization_id=org.id,
        email=clean_email,
        password_hash=pwd_hash,
        salt=salt,
        full_name=clean_name,
        phone=req.phone.strip() if req.phone else None,
        is_active=True,
        is_verified=False,
        session_token=None,
    )
    db.add(host_user)
    token = None
    try:
        db.flush()
        if settings.REQUIRE_EMAIL_VERIFICATION:
            _create_verification(db, host_user)
            message = "Account created. A confirmation code was emailed to you. Confirm your email to sign in."
        else:
            token = _issue_session(db, host_user)
            message = "Account created. Your email has not been verified."
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(400, "An account with this email already exists.") from exc
    except HTTPException:
        db.rollback()
        raise
    db.refresh(host_user)

    log_audit_event(
        db=db,
        organization_id=org.id,
        entity_type="host_user",
        entity_id=host_user.id,
        action="host_signed_up",
        actor_name=host_user.full_name,
        details={"email": host_user.email}
    )
    db.commit()

    return HostAuthResponse(
        success=True,
        token=token,
        host=HostUserResponse.model_validate(host_user),
        organization_id=org.id,
        message=message,
        verification_required=settings.REQUIRE_EMAIL_VERIFICATION,
    )


@router.post("/login", response_model=HostAuthResponse)
def host_login(
    req: HostLoginRequest,
    db: Session = Depends(get_db)
):
    """
    Authenticates a host securely using password hash verification.
    """
    host_user = _authenticate(db, str(req.email), req.password)
    host_user.session_token = None
    if settings.REQUIRE_EMAIL_VERIFICATION and not host_user.is_verified:
        db.commit()
        raise HTTPException(403, detail={
            "message": "Confirm your email before signing in.", "verification_required": True,
        })
    token = _issue_session(db, host_user)
    db.commit()
    db.refresh(host_user)

    log_audit_event(
        db=db,
        organization_id=host_user.organization_id,
        entity_type="host_user",
        entity_id=host_user.id,
        action="host_logged_in",
        actor_name=host_user.full_name,
        details={"email": host_user.email}
    )
    db.commit()

    return HostAuthResponse(
        success=True,
        token=token,
        host=HostUserResponse.model_validate(host_user),
        organization_id=host_user.organization_id,
        message="Welcome back, " + host_user.full_name
    )


@router.post("/verification/send")
def send_verification(req: HostVerificationSendRequest, db: Session = Depends(get_db)):
    host = _authenticate(db, str(req.email), req.password)
    if host.is_verified:
        raise HTTPException(400, "This email is already verified. Please sign in.")
    db.execute(select(HostUser).where(HostUser.id == host.id).with_for_update()).scalar_one()
    try:
        _create_verification(db, host)
        db.commit()
    except HTTPException:
        db.rollback()
        raise
    return {"success": True, "message": "A confirmation code was emailed to you."}


@router.post("/verification/verify", response_model=HostAuthResponse)
def verify_email(req: HostVerificationRequest, db: Session = Depends(get_db)):
    now = _now()
    host = db.execute(
        select(HostUser).where(HostUser.email == str(req.email).lower()).with_for_update()
    ).scalar_one_or_none()
    invalid = "Confirmation code is invalid, expired, or already used. Request a new code."
    if not host or not host.is_active or host.is_verified:
        raise HTTPException(400, invalid)
    verification = db.execute(select(HostEmailVerification).where(
        HostEmailVerification.host_id == host.id, HostEmailVerification.email == host.email,
        HostEmailVerification.consumed_at.is_(None), HostEmailVerification.expires_at > now,
        HostEmailVerification.attempts < settings.EMAIL_OTP_MAX_ATTEMPTS,
    ).order_by(HostEmailVerification.created_at.desc()).limit(1).with_for_update()).scalar_one_or_none()
    if not verification:
        raise HTTPException(400, invalid)
    matches = verify_password(req.code, verification.id, verification.code_hash)
    conditions = (
        HostEmailVerification.id == verification.id, HostEmailVerification.consumed_at.is_(None),
        HostEmailVerification.expires_at > _now(), HostEmailVerification.attempts < settings.EMAIL_OTP_MAX_ATTEMPTS,
    )
    if not matches:
        db.execute(update(HostEmailVerification).where(*conditions).values(attempts=HostEmailVerification.attempts + 1))
        db.commit()
        raise HTTPException(400, invalid)
    result = db.execute(update(HostEmailVerification).where(*conditions).values(consumed_at=_now()))
    if result.rowcount != 1:
        db.rollback()
        raise HTTPException(400, invalid)
    host.is_verified = True
    token = _issue_session(db, host)
    log_audit_event(
        db=db, organization_id=host.organization_id, entity_type="host_user", entity_id=host.id,
        action="host_email_verified", actor_name=host.full_name, details={"email": host.email},
    )
    db.commit()
    db.refresh(host)
    return _response(host, token, "Email confirmed. You are signed in securely.")


@router.post("/logout")
def host_logout(
    host: HostUser = Depends(get_current_host),
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
):
    """Revoke only the presented device session."""
    log_audit_event(
        db=db,
        organization_id=host.organization_id,
        entity_type="host_user",
        entity_id=host.id,
        action="host_logged_out",
        actor_name=host.full_name,
        details={"email": host.email}
    )
    db.execute(delete(HostSession).where(
        HostSession.host_id == host.id, HostSession.token_hash == hash_auth_token(credentials.credentials),
    ))
    db.commit()
    return {"success": True, "message": "Signed out securely. This device's session has been revoked."}


@router.get("/me", response_model=HostUserResponse)
def get_current_host_profile(
    host: HostUser = Depends(get_current_host),
):
    """Returns the authenticated host's profile. Requires a valid session token."""
    return host


@router.patch("/profile", response_model=HostUserResponse)
def update_host_profile(
    req: HostProfileUpdateRequest,
    host: HostUser = Depends(get_current_host),
    db: Session = Depends(get_db),
):
    """Updates the authenticated host's profile details."""
    if req.full_name is not None:
        host.full_name = req.full_name.strip()
    if req.phone is not None:
        host.phone = req.phone.strip()
    if req.email is not None:
        clean_email = req.email.strip().lower()
        if clean_email != host.email:
            if not host.has_password or not req.current_password or not verify_password(req.current_password, host.salt, host.password_hash):
                raise HTTPException(400, "Your current password is required to change your email.")
            existing = db.execute(select(HostUser).where(HostUser.email == clean_email)).scalar_one_or_none()
            if existing:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is already in use.")
            host.email = clean_email
            host.is_verified = False
            db.execute(update(HostEmailVerification).where(
                HostEmailVerification.host_id == host.id, HostEmailVerification.consumed_at.is_(None),
            ).values(consumed_at=_now()))
            if settings.REQUIRE_EMAIL_VERIFICATION:
                db.execute(delete(HostSession).where(HostSession.host_id == host.id))

    host.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(host)
    return host
