from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import Organization
from backend.app.schemas.schemas import OrganizationResponse, OrganizationUpdate
from backend.app.services.audit_service import log_audit_event

router = APIRouter(prefix="/organization", tags=["Organization"])

@router.get("", response_model=OrganizationResponse)
def get_current_organization(
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    org = db.execute(select(Organization).where(Organization.id == org_id)).scalar_one_or_none()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")
    return org

@router.patch("", response_model=OrganizationResponse)
def update_current_organization(
    update_in: OrganizationUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    org = db.execute(select(Organization).where(Organization.id == org_id)).scalar_one_or_none()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    if update_in.name is not None:
        org.name = update_in.name
    if update_in.currency is not None:
        org.currency = update_in.currency
    if update_in.phone is not None:
        org.phone = update_in.phone
    if update_in.email is not None:
        org.email = update_in.email
    if update_in.address is not None:
        org.address = update_in.address
    if update_in.city is not None:
        org.city = update_in.city
    if update_in.country is not None:
        org.country = update_in.country
    if update_in.logo_url is not None:
        org.logo_url = update_in.logo_url

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="organization",
        entity_id=org.id,
        action="updated_organization_profile",
        actor_name="Host",
        details={"name": org.name, "email": org.email, "city": org.city}
    )

    db.commit()
    db.refresh(org)
    return org
