from typing import List, Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import AuditLog
from backend.app.schemas.schemas import AuditLogResponse

router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])

@router.get("", response_model=List[AuditLogResponse])
def list_audit_logs(
    entity_type: Optional[str] = None,
    entity_id: Optional[str] = None,
    limit: int = 50,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    query = select(AuditLog).where(AuditLog.organization_id == org_id)
    if entity_type:
        query = query.where(AuditLog.entity_type == entity_type)
    if entity_id:
        query = query.where(AuditLog.entity_id == entity_id)

    query = query.order_by(AuditLog.created_at.desc()).limit(limit)
    return db.execute(query).scalars().all()
