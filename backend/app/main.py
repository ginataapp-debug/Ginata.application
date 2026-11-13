import asyncio
import logging
from contextlib import suppress
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
    auth, properties, reservations, guest_forms, invoices, payments,
    documents, templates, audit, organization, finances, messages, uploads, google_oauth, notifications, account, subscription, operations
)
from backend.app.services.google_forms_sync_service import run_due_syncs

logger = logging.getLogger("uvicorn.error")

# Initialize FastAPI App
app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="Ginata Property Management Backend - Source of Truth for Confirmed Bookings, Invoices, and Guest Information"
)

# Enable CORS for the production Flutter Web app and local development.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ALLOWED_ORIGINS,
    allow_origin_regex=settings.CORS_ALLOWED_ORIGIN_REGEX or None,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Accept", "Authorization", "Content-Type"],
)

# Static and Uploads mounts
app.mount("/static", StaticFiles(directory=str(settings.STATIC_DIR)), name="static")
app.mount("/uploads", StaticFiles(directory=str(settings.UPLOADS_DIR)), name="uploads")

# Include Routers under API v1
api_v1_prefix = settings.API_V1_STR
app.include_router(auth.router, prefix=api_v1_prefix)
app.include_router(account.router, prefix=api_v1_prefix)
app.include_router(subscription.router, prefix=api_v1_prefix)
app.include_router(operations.router, prefix=api_v1_prefix)
app.include_router(organization.router, prefix=api_v1_prefix)
app.include_router(properties.router, prefix=api_v1_prefix)
app.include_router(reservations.router, prefix=api_v1_prefix)
app.include_router(google_oauth.router, prefix=api_v1_prefix)
app.include_router(guest_forms.router, prefix=api_v1_prefix)
app.include_router(invoices.router, prefix=api_v1_prefix)
app.include_router(payments.router, prefix=api_v1_prefix)
app.include_router(documents.router, prefix=api_v1_prefix)
app.include_router(templates.router, prefix=api_v1_prefix)
app.include_router(audit.router, prefix=api_v1_prefix)
app.include_router(finances.router, prefix=api_v1_prefix)
app.include_router(messages.router, prefix=api_v1_prefix)
app.include_router(uploads.router, prefix=api_v1_prefix)
app.include_router(notifications.router, prefix=api_v1_prefix)


def seed_database():
    """Initializes tables and sets up standard organization and document templates."""
    Base.metadata.create_all(bind=engine)
    from backend.app.core.migrations import run_migrations
    run_migrations(engine)
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
                secondary_color="#466557",
                font_family="Plus Jakarta Sans",
                logo_url="/static/logo.png",
                header_text="Ginata Luxury Accommodations",
                footer_text="Thank you for staying with us.",
                payment_instructions="Contact host for payment details",
                tax_notes="Tax amounts are itemized where applicable.",
                is_default=True
            )
            db.add(tpl)
            db.commit()

        # Published demo credentials are opt-in for local testing only.
        from backend.app.models.models import HostUser
        from backend.app.core.security import hash_password
        host = db.query(HostUser).first() if settings.SEED_DEMO_HOST else None
        if settings.SEED_DEMO_HOST and not host:
            pwd_hash, salt = hash_password("host123456")
            host = HostUser(
                organization_id=org.id,
                email="host@ginata.ke",
                password_hash=pwd_hash,
                salt=salt,
                full_name="Host",
                phone="+254 700 000 000",
                is_active=True,
                is_verified=True
            )
            db.add(host)
            db.commit()
    finally:
        db.close()


_poller_status = {"running": False, "cycles": 0, "last_cycle_at": None, "last_cycle_ok": None}


async def _google_forms_poller():
    interval = settings.GOOGLE_FORMS_POLL_SECONDS
    _poller_status["running"] = True
    logger.info("Google Forms sync worker started (polling every %ss)", interval)
    try:
        while True:
            await asyncio.sleep(interval)
            try:
                processed = await asyncio.to_thread(run_due_syncs, SessionLocal)
                if _poller_status["cycles"] % 15 == 0:
                    from backend.app.services.ical_service import run_due_calendar_syncs
                    await asyncio.to_thread(run_due_calendar_syncs, SessionLocal)
                _poller_status["last_cycle_ok"] = True
                if processed:
                    logger.info("Google Forms sync cycle processed %s form(s)", processed)
            except Exception:
                _poller_status["last_cycle_ok"] = False
                logger.exception("Google Forms polling cycle failed")
            _poller_status["cycles"] += 1
            _poller_status["last_cycle_at"] = datetime.now(timezone.utc).isoformat()
    finally:
        _poller_status["running"] = False


@app.on_event("startup")
async def on_startup():
    seed_database()
    if settings.GOOGLE_FORMS_POLL_SECONDS > 0:
        app.state.google_forms_poller = asyncio.create_task(_google_forms_poller())


@app.on_event("shutdown")
async def on_shutdown():
    task = getattr(app.state, "google_forms_poller", None)
    if task is not None:
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task


@app.get("/")
def root_index():
    return {
        "platform": "Ginata Property Management",
        "currency": "KES",
        "status": "operational",
        "api_v1": "/api/v1",
        "docs": "/docs",
        "design_system": "Forest Green & Warm Cream",
        "google_forms_sync": {
            "polling_seconds": settings.GOOGLE_FORMS_POLL_SECONDS,
            "push_enabled": bool(settings.GOOGLE_FORMS_PUBSUB_TOPIC),
            **_poller_status,
        },
    }
