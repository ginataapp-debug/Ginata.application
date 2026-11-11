import hmac
from typing import List, Optional
from datetime import timezone, datetime
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Response
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.config import settings
from backend.app.core.database import SessionLocal, get_db
from backend.app.api.deps import get_current_host, get_current_org_id
from backend.app.models.models import (
    GuestFormSubmission, GoogleFormResponse, GoogleFormSyncState, GoogleOAuthCredential, HostUser
)
from backend.app.schemas.schemas import (
    GuestFormSubmissionResponse, PublicGuestFormView, PublicGuestFormSubmitRequest,
    SubmissionReviewRequest, GoogleFormsConfigRequest, GoogleFormResponseOut, GoogleFormAssignRequest
)
from backend.app.services.guest_form_service import (
    get_public_form_view, submit_public_guest_form, review_guest_form_submission,
    revoke_form_token
)
from backend.app.services.google_forms_sync_service import (
    assign_response, configure_google_form, disconnect_google_form, get_google_guest_form,
    mark_forms_due, response_counts, run_due_syncs, sync_guest_form
)

router = APIRouter(tags=["Guest Forms"])

# 1. Protected Host Endpoints
@router.get("/guest-forms/submissions", response_model=List[GuestFormSubmissionResponse])
def list_submissions(
    status_filter: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    query = select(GuestFormSubmission).where(GuestFormSubmission.organization_id == org_id)
    if status_filter:
        query = query.where(GuestFormSubmission.form_status == status_filter)
    query = query.order_by(GuestFormSubmission.created_at.desc())
    return db.execute(query).scalars().all()

@router.post("/guest-form-submissions/{submission_id}/review", response_model=GuestFormSubmissionResponse)
def review_submission(
    submission_id: str,
    review_in: SubmissionReviewRequest,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return review_guest_form_submission(
        db=db,
        organization_id=org_id,
        submission_id=submission_id,
        review_in=review_in,
        actor_name="Host"
    )

@router.post("/guest-forms/tokens/{token}/revoke", response_model=GuestFormSubmissionResponse)
def revoke_token(
    token: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return revoke_form_token(
        db=db,
        organization_id=org_id,
        token=token,
        actor_name="Host"
    )

# Google Forms integration (real Forms API sync; Google tokens never leave the backend)
def _google_status_payload(db: Session, host: HostUser) -> dict:
    credential = db.execute(select(GoogleOAuthCredential).where(
        GoogleOAuthCredential.host_id == host.id
    )).scalar_one_or_none()
    gform = get_google_guest_form(db, host.organization_id)
    sync_state = None
    if gform is not None:
        sync_state = db.execute(select(GoogleFormSyncState).where(
            GoogleFormSyncState.guest_form_id == gform.id
        )).scalar_one_or_none()
    linked = gform is not None and gform.is_active and sync_state is not None
    sync_status = gform.google_sync_status if linked else "disconnected"
    if linked and credential is None and sync_state.host_id == host.id:
        sync_status = "reconnect_required"
    watch_active = bool(
        linked and sync_state.watch_id and sync_state.watch_expires_at
        and sync_state.watch_expires_at > datetime.now(timezone.utc).replace(tzinfo=None)
    )
    return {
        "google_connected": credential is not None,
        "google_email": credential.email if credential else None,
        "form_linked": linked,
        "is_connected": linked and sync_status not in ("reconnect_required", "disconnected"),
        "form_title": gform.title if linked else None,
        "google_form_id": gform.google_form_id if linked else None,
        "edit_url": f"https://docs.google.com/forms/d/{gform.google_form_id}/edit" if linked else None,
        "responder_url": sync_state.responder_uri if linked else None,
        "property_id": gform.property_id if linked else None,
        "sync_status": sync_status,
        "last_sync_at": gform.google_last_sync_at if linked else None,
        "last_error": gform.google_last_error if linked else None,
        "realtime": "push" if watch_active else "polling",
        "poll_seconds": settings.GOOGLE_FORMS_POLL_SECONDS,
        "counts": response_counts(db, host.organization_id),
    }


@router.get("/guest-forms/google/status")
def get_google_forms_status(
    db: Session = Depends(get_db),
    host: HostUser = Depends(get_current_host),
):
    return _google_status_payload(db, host)


@router.put("/guest-forms/google/config")
def configure_google_forms(
    config_in: GoogleFormsConfigRequest,
    db: Session = Depends(get_db),
    host: HostUser = Depends(get_current_host),
):
    gform = configure_google_form(db, host, config_in.form, config_in.property_id)
    sync_guest_form(db, gform)
    return _google_status_payload(db, host)


@router.delete("/guest-forms/google/config")
def unlink_google_forms(
    db: Session = Depends(get_db),
    host: HostUser = Depends(get_current_host),
):
    disconnect_google_form(db, host)
    return _google_status_payload(db, host)


@router.post("/guest-forms/google/sync")
def sync_google_forms(
    db: Session = Depends(get_db),
    host: HostUser = Depends(get_current_host),
):
    gform = get_google_guest_form(db, host.organization_id)
    if gform is None or not gform.is_active:
        raise HTTPException(status_code=409, detail="Link a Google Form first.")
    result = sync_guest_form(db, gform)
    if result.get("error") and result["status"] in ("failed", "reconnect_required") and result["received"] == 0:
        message = result["error"]
    elif result["received"]:
        message = f"{result['received']} new guest response(s) received."
    else:
        message = "Up to date. No new guest responses."
    return {**result, "message": message, "synced_at": gform.google_last_sync_at}


@router.get("/guest-forms/google/responses", response_model=List[GoogleFormResponseOut])
def list_google_responses(
    sync_status: Optional[str] = None,
    match_status: Optional[str] = None,
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id),
):
    query = select(GoogleFormResponse).where(GoogleFormResponse.organization_id == org_id)
    if sync_status:
        query = query.where(GoogleFormResponse.sync_status == sync_status)
    if match_status:
        query = query.where(GoogleFormResponse.match_status == match_status)
    return db.execute(query.order_by(GoogleFormResponse.created_at.desc()).limit(limit)).scalars().all()


@router.get("/guest-forms/google/responses/{response_id}", response_model=GoogleFormResponseOut)
def get_google_response(
    response_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id),
):
    record = db.execute(select(GoogleFormResponse).where(
        GoogleFormResponse.id == response_id, GoogleFormResponse.organization_id == org_id
    )).scalar_one_or_none()
    if record is None:
        raise HTTPException(status_code=404, detail="Guest response not found.")
    return record


@router.post("/guest-forms/google/responses/{response_id}/assign", response_model=GoogleFormResponseOut)
def assign_google_response(
    response_id: str,
    assign_in: GoogleFormAssignRequest,
    db: Session = Depends(get_db),
    host: HostUser = Depends(get_current_host),
):
    return assign_response(db, host, response_id, assign_in.reservation_id)


@router.post("/integrations/google/forms/push", status_code=204)
def google_forms_push(
    payload: dict,
    background_tasks: BackgroundTasks,
    token: str = "",
    db: Session = Depends(get_db),
):
    expected = settings.GOOGLE_FORMS_PUSH_TOKEN
    if not expected or not hmac.compare_digest(token.encode("utf-8"), expected.encode("utf-8")):
        raise HTTPException(status_code=403, detail="Forbidden")
    attributes = ((payload or {}).get("message") or {}).get("attributes") or {}
    form_id = attributes.get("formId")
    if isinstance(form_id, str) and form_id:
        due = mark_forms_due(db, form_id, attributes.get("watchId"))
        if due:
            background_tasks.add_task(run_due_syncs, SessionLocal, due)
    return Response(status_code=204)


# 2. Public Endpoints for Guest Check-in Link
@router.get("/public/forms/{token}", response_model=PublicGuestFormView)
def public_get_form(
    token: str,
    db: Session = Depends(get_db)
):
    return get_public_form_view(db, token)

@router.post("/public/forms/{token}/submit", response_model=GuestFormSubmissionResponse)
def public_submit_form(
    token: str,
    submit_in: PublicGuestFormSubmitRequest,
    db: Session = Depends(get_db)
):
    return submit_public_guest_form(db, token, submit_in)
