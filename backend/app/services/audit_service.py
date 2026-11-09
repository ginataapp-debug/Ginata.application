from typing import Optional, Any, Dict
from sqlalchemy.orm import Session
from backend.app.models.models import AuditLog

def log_audit_event(
    db: Session,
    organization_id: str,
    entity_type: str,
    entity_id: str,
    action: str,
    actor_name: str = "Host",
    details: Optional[Dict[str, Any]] = None
) -> AuditLog:
    entry = AuditLog(
        organization_id=organization_id,
        entity_type=entity_type,
        entity_id=entity_id,
        action=action,
        actor_name=actor_name,
        details=details or {}
    )
    db.add(entry)
    db.flush()
    return entry
