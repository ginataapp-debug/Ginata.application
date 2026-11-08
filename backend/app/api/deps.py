from typing import Generator
from fastapi import Header, HTTPException, status, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.core.config import settings
from backend.app.models.models import Organization

def get_current_org_id(
    x_organization_id: str = Header(default=settings.DEFAULT_ORG_ID, alias="X-Organization-ID"),
    db: Session = Depends(get_db)
) -> str:
    """
    Enforces tenant isolation across all endpoints.
    Verifies that the requested organization exists.
    """
    org = db.execute(
        select(Organization).where(Organization.id == x_organization_id)
    ).scalar_one_or_none()
    if not org:
        # Check if default org exists; if not, create on the fly
        if x_organization_id == settings.DEFAULT_ORG_ID:
            org = Organization(
                id=settings.DEFAULT_ORG_ID,
                name="Ginata Luxury Estates & Suites",
                currency="KES",
                tax_id="P051234567Z",
                phone="+254 700 892 100",
                email="concierge@ginata.co.ke",
                address="Muthaiga Forest Ridge, Suite 10",
                city="Nairobi",
                country="Kenya",
                logo_url="/static/logo.png"
            )
            db.add(org)
            db.commit()
            return org.id
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Unauthorized or invalid organization context"
        )
    return org.id
