import secrets
from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field, EmailStr
from sqlalchemy import select
from sqlalchemy.orm import Session
from backend.app.api.deps import get_current_org_id
from backend.app.core.config import settings
from backend.app.core.database import get_db
from backend.app.models.models import HostUser, Organization
from backend.app.services.subscription_service import get_subscription, subscription_response

router = APIRouter(tags=["Subscriptions"])


@router.get("/subscription")
def current_subscription(org_id: str = Depends(get_current_org_id), db: Session = Depends(get_db)):
    response = subscription_response(db, org_id)
    db.commit()
    return response


class SubscriptionUpdate(BaseModel):
    email: EmailStr | None = None
    organization_id: str | None = None
    plan: Literal["free", "starter", "pro", "founding"]
    status: Literal["active", "expired", "canceled"] = "active"
    current_period_end: datetime | None = None
    note: str | None = Field(default=None, max_length=2000)


@router.put("/admin/subscriptions")
def update_subscription(req: SubscriptionUpdate, x_admin_key: str = Header(default=""), db: Session = Depends(get_db)):
    if not settings.ADMIN_API_KEY:
        raise HTTPException(404, "Not found")
    if not secrets.compare_digest(x_admin_key, settings.ADMIN_API_KEY):
        raise HTTPException(403, "Not authorized")
    if bool(req.email) == bool(req.organization_id):
        raise HTTPException(400, "Provide an email or organization ID, not both")
    org_id = req.organization_id
    if req.email:
        host = db.scalar(select(HostUser).where(HostUser.email == str(req.email).lower()))
        org_id = host.organization_id if host else None
    if not org_id or not db.get(Organization, org_id):
        raise HTTPException(404, "Organization not found")
    sub, _ = get_subscription(db, org_id)
    sub.plan, sub.status, sub.note = req.plan, req.status, req.note
    sub.current_period_end = req.current_period_end.replace(tzinfo=None) if req.current_period_end else None
    db.commit()
    return subscription_response(db, org_id)
