from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import select, func
from backend.app.core.config import settings
from backend.app.models.models import Organization, Property, Subscription

PLANS = {
    "free": {"max_properties": 1, "google_forms": False, "ical_sync": False, "finance_export": False},
    "starter": {"max_properties": 3, "google_forms": True, "ical_sync": True, "finance_export": True},
    "pro": {"max_properties": None, "google_forms": True, "ical_sync": True, "finance_export": True},
}
PLANS["trial"] = dict(PLANS["pro"])
PLANS["founding"] = dict(PLANS["pro"])


def start_trial(db, org_id):
    sub = Subscription(organization_id=org_id, plan="trial", status="trialing", trial_ends_at=datetime.utcnow() + timedelta(days=settings.TRIAL_DAYS))
    db.add(sub)
    return sub


def get_subscription(db, org_id):
    sub = db.get(Subscription, org_id)
    now = datetime.utcnow()
    if sub is None:
        org = db.get(Organization, org_id)
        cutoff = datetime.fromisoformat(settings.SUBSCRIPTION_GRANDFATHER_BEFORE)
        if org.created_at < cutoff:
            sub = Subscription(organization_id=org_id, plan="founding", status="active")
            db.add(sub)
        else:
            sub = start_trial(db, org_id)
        db.flush()
    plan = sub.plan
    expired = sub.current_period_end is not None and sub.current_period_end <= now
    if sub.status in ("canceled", "expired") or expired or (plan == "trial" and sub.trial_ends_at and sub.trial_ends_at <= now):
        plan = "free"
    return sub, plan


def require_feature(db, org_id, feature):
    _, plan = get_subscription(db, org_id)
    if not PLANS[plan].get(feature, False):
        raise HTTPException(403, {"code": "plan_required", "feature": feature, "message": "This feature requires an active Starter or Pro plan. Contact Ginata to upgrade."})


def check_property_limit(db, org_id):
    _, plan = get_subscription(db, org_id)
    limit = PLANS[plan]["max_properties"]
    count = db.scalar(select(func.count()).select_from(Property).where(Property.organization_id == org_id))
    if limit is not None and count >= limit:
        raise HTTPException(403, {"code": "plan_required", "feature": "properties", "message": f"Your plan allows {limit} property. Contact Ginata to upgrade."})


def subscription_response(db, org_id):
    sub, plan = get_subscription(db, org_id)
    days = max(0, (sub.trial_ends_at - datetime.utcnow()).days + 1) if sub.trial_ends_at else None
    return {
        "plan": plan, "plan_name": plan.title(), "status": "expired" if plan != sub.plan else sub.status,
        "trial_ends_at": sub.trial_ends_at, "current_period_end": sub.current_period_end,
        "days_left_in_trial": days, "entitlements": PLANS[plan],
        "usage": {"properties": db.scalar(select(func.count()).select_from(Property).where(Property.organization_id == org_id))},
        "plans": [{"id": p, "name": p.title(), "price_kes_monthly": None, "entitlements": e} for p, e in PLANS.items() if p in ("free", "starter", "pro")],
        "upgrade_message": "To upgrade, contact ginata.app@gmail.com",
    }
