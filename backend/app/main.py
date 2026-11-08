from datetime import timezone, datetime, date, timedelta
from decimal import Decimal
import secrets
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from backend.app.core.config import settings
from backend.app.core.database import engine, Base, SessionLocal
from backend.app.models.models import (
    Organization, Property, PropertyUnit, Guest, Reservation,
    GuestForm, GuestFormSubmission, Invoice, InvoiceLineItem,
    Payment, Receipt, DocumentTemplate
)
from backend.app.api.v1 import (
    properties, reservations, guest_forms, invoices, payments,
    documents, templates, audit, organization, finances, messages, uploads
)

# Initialize FastAPI App
app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="Ginata Property Management Backend - Source of Truth for Confirmed Bookings, Invoices, and Guest Information"
)

# Enable CORS for Flutter Web, Desktop, and Local dev
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static and Uploads mounts
app.mount("/static", StaticFiles(directory=str(settings.STATIC_DIR)), name="static")
app.mount("/uploads", StaticFiles(directory=str(settings.UPLOADS_DIR)), name="uploads")

# Include Routers under API v1
api_v1_prefix = settings.API_V1_STR
app.include_router(organization.router, prefix=api_v1_prefix)
app.include_router(properties.router, prefix=api_v1_prefix)
app.include_router(reservations.router, prefix=api_v1_prefix)
app.include_router(guest_forms.router, prefix=api_v1_prefix)
app.include_router(invoices.router, prefix=api_v1_prefix)
app.include_router(payments.router, prefix=api_v1_prefix)
app.include_router(documents.router, prefix=api_v1_prefix)
app.include_router(templates.router, prefix=api_v1_prefix)
app.include_router(audit.router, prefix=api_v1_prefix)
app.include_router(finances.router, prefix=api_v1_prefix)
app.include_router(messages.router, prefix=api_v1_prefix)
app.include_router(uploads.router, prefix=api_v1_prefix)


def seed_database():
    """Initializes tables and sets up standard organization and document templates."""
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        org = db.query(Organization).filter(Organization.id == settings.DEFAULT_ORG_ID).first()
        if not org:
            org = Organization(
                id=settings.DEFAULT_ORG_ID,
                name="Ginata Host",
                currency="KES",
                tax_id=None,
                phone="",
                email="",
                address="",
                city="Nairobi",
                country="Kenya",
                logo_url="/static/logo.png"
            )
            db.add(org)
            db.commit()

        # Seed default document template if none exists
        tpl = db.query(DocumentTemplate).filter(DocumentTemplate.organization_id == org.id).first()
        if not tpl:
            tpl = DocumentTemplate(
                organization_id=org.id,
                name="Standard Minimalist Luxury",
                layout_style="minimalist_luxury",
                primary_color="#003329",
                secondary_color="#B38E5D",
                font_family="Plus Jakarta Sans",
                logo_url="/static/logo.png",
                header_text="Ginata Luxury Accommodations",
                footer_text="Thank you for staying with us.",
                payment_instructions="Contact host for payment details",
                tax_notes="0.00% VAT - Direct Rates",
                is_default=True
            )
            db.add(tpl)
            db.commit()
    finally:
        db.close()


@app.on_event("startup")
def on_startup():
    seed_database()


@app.get("/")
def root_index():
    return {
        "platform": "Ginata Property Management",
        "currency": "KES",
        "status": "operational",
        "api_v1": "/api/v1",
        "docs": "/docs",
        "design_system": "Forest Green & Warm Cream"
    }
