from datetime import datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from backend.app.api.deps import get_current_org_id
from backend.app.core.database import get_db
from backend.app.models.models import HostNotification
from backend.app.schemas.schemas import HostNotificationOut

router = APIRouter(prefix="/notifications", tags=["Notifications"])


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


@router.get("", response_model=List[HostNotificationOut])
def list_notifications(
    unread_only: bool = False,
    limit: int = Query(30, ge=1, le=100),
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id),
):
    query = select(HostNotification).where(HostNotification.organization_id == org_id)
    if unread_only:
        query = query.where(HostNotification.read_at.is_(None))
    return db.execute(query.order_by(HostNotification.created_at.desc()).limit(limit)).scalars().all()


@router.get("/summary")
def notification_summary(
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id),
):
    unread = db.execute(select(func.count()).select_from(HostNotification).where(
        HostNotification.organization_id == org_id, HostNotification.read_at.is_(None)
    )).scalar_one()
    latest = db.execute(select(HostNotification).where(
        HostNotification.organization_id == org_id
    ).order_by(HostNotification.created_at.desc()).limit(1)).scalar_one_or_none()
    return {
        "unread_count": unread,
        "latest_id": latest.id if latest else None,
        "latest_created_at": latest.created_at if latest else None,
    }


@router.post("/{notification_id}/read", response_model=HostNotificationOut)
def mark_read(
    notification_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id),
):
    item = db.execute(select(HostNotification).where(
        HostNotification.id == notification_id, HostNotification.organization_id == org_id
    )).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Notification not found.")
    if item.read_at is None:
        item.read_at = _now()
        db.commit()
        db.refresh(item)
    return item


@router.post("/read-all")
def mark_all_read(
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id),
):
    result = db.execute(update(HostNotification).where(
        HostNotification.organization_id == org_id, HostNotification.read_at.is_(None)
    ).values(read_at=_now()))
    db.commit()
    return {"updated": result.rowcount}
