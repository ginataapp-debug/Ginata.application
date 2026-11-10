from datetime import datetime, timezone
from typing import Optional
from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.core.config import settings
from backend.app.core.security import hash_auth_token
from backend.app.models.models import HostUser, HostSession

bearer_scheme = HTTPBearer(auto_error=False)


def get_current_host(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> HostUser:
    """
    Validates the host session token issued at sign-in.
    Every org-scoped endpoint resolves its tenant from the authenticated host,
    never from a client-supplied organization header.
    """
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sign in required. Please log in to your host account.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    host = db.execute(
        select(HostUser).join(HostSession, HostSession.host_id == HostUser.id).where(
            HostSession.token_hash == hash_auth_token(credentials.credentials),
            HostSession.expires_at > datetime.now(timezone.utc).replace(tzinfo=None),
            HostUser.is_active.is_(True),
        )
    ).scalar_one_or_none()
    if host is None or (settings.REQUIRE_EMAIL_VERIFICATION and not host.is_verified):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Your session has expired or is invalid. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return host


def get_current_org_id(
    host: HostUser = Depends(get_current_host),
) -> str:
    """Enforces tenant isolation: the organization always comes from the signed-in host."""
    return host.organization_id