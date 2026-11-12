import logging
import re
import secrets
from datetime import date, datetime, timedelta, timezone
from typing import Callable, Optional
from urllib.parse import urlparse

import httpx
from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from backend.app.core.config import settings
from backend.app.models.models import (
    Guest, GuestForm, GuestFormSubmission, GoogleFormResponse, GoogleFormSyncState,
    GoogleOAuthCredential, HostNotification, HostUser, Property, Reservation,
)
from backend.app.services.audit_service import log_audit_event
from backend.app.services.google_oauth_service import (
    GoogleOAuthError, GoogleOAuthUnavailable, get_valid_google_access_token, validate_google_oauth_config,
)

logger = logging.getLogger(__name__)

FORMS_API = "https://forms.googleapis.com/v1/forms"
FORM_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{20,200}$")
MAX_BACKOFF_SECONDS = 1800
WATCH_RENEW_BEFORE = timedelta(days=1)

STATUS_CONNECTED = "connected"
STATUS_SYNCING = "syncing"
STATUS_FAILED = "failed"
STATUS_RECONNECT = "reconnect_required"
STATUS_DISCONNECTED = "disconnected"

# Ordered: the first keyword group found in a question title decides the field.
FIELD_KEYWORDS: list[tuple[str, tuple[str, ...]]] = [
    ("booking_reference", ("booking ref", "booking reference", "reference", "booking code", "booking number",
                           "booking id", "reservation number", "reservation code", "confirmation")),
    ("email", ("email", "e-mail")),
    ("phone", ("phone", "mobile", "whatsapp", "telephone", "cell")),
    ("id_type", ("id type", "type of id", "identification type", "document type")),
    ("id_number", ("id number", "id no", "passport", "national id", "identification number", "document number")),
    ("eta", ("arrival time", "time of arrival", "eta", "check-in time", "check in time", "expected time")),
    ("check_in_date", ("check-in date", "check in date", "checkin date", "arrival date", "date of arrival", "check-in", "check in", "arrival")),
    ("flight_number", ("flight",)),
    ("transport_mode", ("transport", "how will you arrive", "travel by")),
    ("dietary_requirements", ("dietary", "allerg", "diet")),
    ("nationality", ("nationality", "citizenship")),
    ("special_requests", ("special request", "request", "anything else", "notes", "comments")),
    ("guest_name", ("full name", "guest name", "your name", "name")),
]
SENSITIVE_FIELDS = {"id_number"}
DATE_FORMATS = ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y", "%d %B %Y", "%d %b %Y", "%B %d, %Y", "%b %d, %Y")


class GoogleFormsApiError(Exception):
    def __init__(self, message: str, reconnect: bool = False, transient: bool = False):
        super().__init__(message)
        self.reconnect = reconnect
        self.transient = transient


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def parse_google_form_id(value: str) -> str:
    raw = (value or "").strip()
    if not raw:
        raise HTTPException(422, "Paste your Google Form edit link or form ID.")
    if FORM_ID_PATTERN.match(raw):
        return raw
    parsed = urlparse(raw if "://" in raw else f"https://{raw}")
    if parsed.hostname not in {"docs.google.com", "forms.google.com"}:
        raise HTTPException(422, "That is not a Google Forms link.")
    parts = [p for p in parsed.path.split("/") if p]
    if "d" in parts:
        idx = parts.index("d")
        if idx + 1 < len(parts) and parts[idx + 1] == "e":
            raise HTTPException(
                422,
                "This is the guest sharing link. Open the form in Google Forms and paste the link from your browser's address bar while editing it (it contains /edit).",
            )
        if idx + 1 < len(parts) and FORM_ID_PATTERN.match(parts[idx + 1]):
            return parts[idx + 1]
    raise HTTPException(422, "The Google Form ID could not be found in that link.")


def _google_request(method: str, url: str, access_token: str, **kwargs) -> dict:
    try:
        response = httpx.request(
            method, url, headers={"Authorization": f"Bearer {access_token}"}, timeout=20, **kwargs
        )
    except httpx.HTTPError as exc:
        raise GoogleFormsApiError("Google Forms could not be reached.", transient=True) from exc
    if response.status_code in (401, 403):
        raise GoogleFormsApiError(
            "Google denied access to this form. Reconnect Google with the account that owns the form.", reconnect=True
        )
    if response.status_code == 404:
        raise GoogleFormsApiError("The Google Form was not found. Check the link and that your connected Google account owns it.")
    if response.status_code == 429 or response.status_code >= 500:
        raise GoogleFormsApiError("Google Forms is busy right now. Ginata will retry automatically.", transient=True)
    if response.status_code >= 400:
        raise GoogleFormsApiError(f"Google Forms rejected the request (HTTP {response.status_code}).")
    try:
        payload = response.json()
    except ValueError as exc:
        raise GoogleFormsApiError("Google Forms returned an invalid response.", transient=True) from exc
    return payload if isinstance(payload, dict) else {}


def _access_token(db: Session, host_id: str) -> str:
    try:
        validate_google_oauth_config()
    except GoogleOAuthError as exc:
        raise GoogleFormsApiError(str(exc), transient=True) from exc
    try:
        return get_valid_google_access_token(db, host_id)
    except GoogleOAuthUnavailable as exc:
        raise GoogleFormsApiError(str(exc), transient=True) from exc
    except GoogleOAuthError as exc:
        raise GoogleFormsApiError(
            "Google access has expired or was revoked. Reconnect your Google account.", reconnect=True
        ) from exc


def classify_question(title: str) -> Optional[str]:
    text = re.sub(r"\s+", " ", (title or "").lower()).strip()
    for field, keywords in FIELD_KEYWORDS:
        if any(k in text for k in keywords):
            return field
    return None


def build_question_map(form: dict) -> dict:
    mapping: dict[str, dict] = {}

    def add(question: dict, title: str):
        qid = question.get("questionId")
        if qid:
            mapping[qid] = {"title": title, "field": classify_question(title)}

    for item in form.get("items") or []:
        title = item.get("title") or ""
        if "questionItem" in item:
            add(item["questionItem"].get("question") or {}, title)
        for row in (item.get("questionGroupItem") or {}).get("questions") or []:
            row_title = f"{title} {((row.get('rowQuestion') or {}).get('title') or '')}".strip()
            add(row, row_title)
    return mapping


def _mask(value: str) -> str:
    clean = value.strip()
    return f"{'*' * max(0, len(clean) - 4)}{clean[-4:]}" if len(clean) > 4 else "*" * len(clean)


def _parse_google_time(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    trimmed = re.sub(r"(\.\d{6})\d+", r"\1", value.replace("Z", "+00:00"))
    try:
        parsed = datetime.fromisoformat(trimmed)
    except ValueError:
        return None
    return parsed.astimezone(timezone.utc).replace(tzinfo=None) if parsed.tzinfo else parsed


def _parse_date(value: Optional[str]) -> Optional[date]:
    text = (value or "").strip()
    for fmt in DATE_FORMATS:
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            continue
    return None


def extract_response(response: dict, question_map: dict) -> dict:
    """Converts a Forms API response into named fields plus a privacy-safe answer list."""
    fields: dict[str, str] = {}
    answers: list[dict] = []
    for qid, answer in (response.get("answers") or {}).items():
        meta = question_map.get(qid) or {"title": "Question", "field": None}
        values = [a.get("value", "") for a in (answer.get("textAnswers") or {}).get("answers") or [] if a.get("value")]
        if answer.get("fileUploadAnswers"):
            values.append(f"{len(answer['fileUploadAnswers'].get('answers') or [])} file(s) uploaded in Google Forms")
        value = ", ".join(values).strip()
        if not value:
            continue
        field = meta.get("field")
        if field and field not in fields:
            fields[field] = value
        shown = _mask(value) if field in SENSITIVE_FIELDS else value
        answers.append({"question": meta.get("title") or "Question", "answer": shown[:2000]})
    if response.get("respondentEmail") and "email" not in fields:
        fields["email"] = response["respondentEmail"]
    return {"fields": fields, "answers": answers}


def _active_reservations(organization_id: str, property_id: Optional[str]):
    query = select(Reservation).where(
        Reservation.organization_id == organization_id,
        Reservation.reservation_status.notin_(["cancelled", "draft"]),
    )
    if property_id:
        query = query.where(Reservation.property_id == property_id)
    return query


def match_reservation(
    db: Session, organization_id: str, property_id: Optional[str], fields: dict
) -> tuple[Optional[Reservation], str]:
    """Only returns a reservation when exactly one candidate matches; ambiguity is left for the host."""
    reference = (fields.get("booking_reference") or "").strip()
    if reference:
        found = db.execute(_active_reservations(organization_id, property_id).where(
            func.lower(Reservation.booking_reference) == reference.lower()
        )).scalars().all()
        if len(found) == 1:
            return found[0], "Matched by booking reference"
        if len(found) > 1:
            return None, "More than one booking uses this reference"

    email = (fields.get("email") or "").strip().lower()
    if not email:
        return None, "No booking reference or email to match"
    by_email = _active_reservations(organization_id, property_id).join(
        Guest, Guest.id == Reservation.primary_guest_id
    ).where(func.lower(Guest.email) == email)

    check_in = _parse_date(fields.get("check_in_date"))
    if check_in:
        found = db.execute(by_email.where(Reservation.check_in_date == check_in)).scalars().all()
        if len(found) == 1:
            return found[0], "Matched by guest email and check-in date"
        if len(found) > 1:
            return None, "Several bookings share this email and check-in date"

    upcoming = db.execute(by_email.where(Reservation.check_out_date >= _now().date())).scalars().all()
    if len(upcoming) == 1 and (check_in is None or upcoming[0].check_in_date == check_in):
        return upcoming[0], "Matched by guest email (only upcoming booking)"
    if len(upcoming) > 1:
        return None, "Several upcoming bookings use this email"
    return None, "No matching booking found"


def _notify(db: Session, organization_id: str, kind: str, title: str, body: str,
            entity_type: Optional[str], entity_id: Optional[str], dedupe_key: Optional[str]) -> None:
    if dedupe_key and db.execute(
        select(HostNotification.id).where(HostNotification.dedupe_key == dedupe_key)
    ).first():
        return
    db.add(HostNotification(
        organization_id=organization_id, kind=kind, title=title, body=body,
        entity_type=entity_type, entity_id=entity_id, dedupe_key=dedupe_key,
    ))


def notify_guest_check_in(db: Session, organization_id: str, guest_name: str, property_name: Optional[str],
                          check_in: Optional[date], submitted_at: Optional[datetime], entity_type: str,
                          entity_id: str, dedupe_key: str, needs_match: bool = False) -> None:
    parts = [guest_name or "A guest"]
    parts.append(property_name or "Booking not matched yet")
    if check_in:
        parts.append(f"Check-in {check_in.strftime('%d %b %Y')}")
    if submitted_at:
        parts.append(f"Submitted {submitted_at.strftime('%d %b %Y, %H:%M')} UTC")
    title = "New guest check-in needs review" if needs_match else "New guest check-in received!"
    _notify(db, organization_id, "guest_check_in", title, " · ".join(parts), entity_type, entity_id, dedupe_key)


def _apply_to_reservation(db: Session, record: GoogleFormResponse, reservation: Reservation, fields: dict) -> None:
    submission = db.get(GuestFormSubmission, record.submission_id) if record.submission_id else None
    if submission is None:
        submission = db.execute(select(GuestFormSubmission).where(
            GuestFormSubmission.reservation_id == reservation.id,
            GuestFormSubmission.token_revoked.is_(False),
        ).order_by(GuestFormSubmission.created_at.desc())).scalars().first()
    if submission is None:
        submission = GuestFormSubmission(
            organization_id=reservation.organization_id,
            reservation_id=reservation.id,
            token=secrets.token_urlsafe(32),
            token_expires_at=_now() + timedelta(days=30),
        )
        db.add(submission)

    id_number = fields.get("id_number")
    submission.submitted_at = record.submitted_at or _now()
    submission.guest_name = (record.guest_name or submission.guest_name or "")[:200]
    submission.guest_email = record.guest_email or submission.guest_email
    submission.guest_phone = record.guest_phone or submission.guest_phone
    for attr in ("eta", "flight_number", "transport_mode"):
        if fields.get(attr):
            setattr(submission, attr, fields[attr][:50])
    if fields.get("dietary_requirements"):
        submission.dietary_requirements = fields["dietary_requirements"]
    if fields.get("special_requests"):
        submission.special_requests = fields["special_requests"]
    if fields.get("id_type"):
        submission.id_type = fields["id_type"][:50]
    if id_number:
        submission.id_number = _mask(id_number)[:100]
    submission.raw_data = {
        "source": "google_forms",
        "google_response_id": record.google_response_id,
        "answers": record.answers,
    }
    needs_review = bool(id_number or fields.get("special_requests"))
    submission.form_status = "needs_review" if needs_review else "completed"
    reservation.guest_info_status = submission.form_status

    guest = reservation.primary_guest
    if guest:
        if record.guest_email and not guest.email:
            guest.email = record.guest_email
        if record.guest_phone and not guest.phone:
            guest.phone = record.guest_phone[:50]
        if fields.get("id_type") and not guest.id_type:
            guest.id_type = fields["id_type"][:50]
        if id_number and not guest.id_number_masked:
            guest.id_number_masked = _mask(id_number)[:100]
        if fields.get("nationality") and not guest.nationality:
            guest.nationality = fields["nationality"][:100]
    db.flush()

    record.reservation_id = reservation.id
    record.submission_id = submission.id
    record.match_status = "matched"
    record.sync_status = "pending_review" if needs_review else "synced"


def _process_response(db: Session, guest_form: GuestForm, sync_state: GoogleFormSyncState, response: dict) -> bool:
    """Returns True when this response was newly received (used for notifications/counts)."""
    response_id = response.get("responseId")
    if not response_id:
        return False
    submitted_raw = response.get("lastSubmittedTime") or response.get("createTime")
    submitted_at = _parse_google_time(submitted_raw)
    record = db.execute(select(GoogleFormResponse).where(
        GoogleFormResponse.google_form_id == sync_state.google_form_id,
        GoogleFormResponse.google_response_id == response_id,
    )).scalar_one_or_none()
    if record and record.sync_status != "failed" and record.submitted_at == submitted_at:
        return False

    is_new = record is None
    extracted = extract_response(response, sync_state.question_map or {})
    fields = extracted["fields"]
    if record is None:
        record = GoogleFormResponse(
            organization_id=guest_form.organization_id,
            host_id=sync_state.host_id,
            guest_form_id=guest_form.id,
            google_form_id=sync_state.google_form_id,
            google_response_id=response_id,
        )
        db.add(record)
    record.attempts = (record.attempts or 0) + 1
    record.guest_name = (fields.get("guest_name") or "")[:200] or None
    record.guest_email = (fields.get("email") or "").strip().lower()[:255] or None
    record.guest_phone = (fields.get("phone") or "").strip()[:50] or None
    record.booking_reference = (fields.get("booking_reference") or "").strip()[:100] or None
    record.check_in_date = _parse_date(fields.get("check_in_date"))
    record.answers = extracted["answers"]
    record.submitted_at = submitted_at
    record.last_error = None
    db.flush()

    reservation = db.get(Reservation, record.reservation_id) if record.reservation_id else None
    if reservation is None or reservation.organization_id != guest_form.organization_id:
        reservation, reason = match_reservation(db, guest_form.organization_id, guest_form.property_id, fields)
        record.match_reason = reason
    if reservation is not None:
        _apply_to_reservation(db, record, reservation, fields)
    else:
        record.reservation_id = None
        record.match_status = "unmatched"
        record.sync_status = "pending_review"

    if is_new:
        prop = reservation.property if reservation else (
            db.get(Property, guest_form.property_id) if guest_form.property_id else None
        )
        notify_guest_check_in(
            db, guest_form.organization_id, record.guest_name or "A guest",
            prop.name if prop and reservation else None,
            reservation.check_in_date if reservation else record.check_in_date,
            submitted_at, "google_form_response", record.id,
            f"gform-response:{record.id}", needs_match=reservation is None,
        )
        log_audit_event(
            db=db, organization_id=guest_form.organization_id, entity_type="google_form_response",
            entity_id=record.id, action="google_form_response_received", actor_name="Google Forms",
            details={"match_status": record.match_status, "reservation_id": record.reservation_id},
        )
    return is_new


def _record_failure(db: Session, guest_form: GuestForm, sync_state: GoogleFormSyncState, error: GoogleFormsApiError) -> None:
    sync_state.consecutive_failures = (sync_state.consecutive_failures or 0) + 1
    delay = min(60 * (2 ** min(sync_state.consecutive_failures - 1, 6)), MAX_BACKOFF_SECONDS)
    sync_state.next_attempt_at = _now() + timedelta(seconds=MAX_BACKOFF_SECONDS if error.reconnect else delay)
    guest_form.google_sync_status = STATUS_RECONNECT if error.reconnect else STATUS_FAILED
    guest_form.google_last_error = str(error)
    if error.reconnect:
        _notify(
            db, guest_form.organization_id, "google_reconnect", "Reconnect Google to keep receiving check-ins",
            str(error), "guest_form", guest_form.id, f"google-reconnect:{guest_form.id}:{_now().date().isoformat()}",
        )


def _ensure_watch(db: Session, sync_state: GoogleFormSyncState, access_token: str) -> None:
    topic = settings.GOOGLE_FORMS_PUBSUB_TOPIC.strip()
    if not topic:
        return
    if sync_state.watch_id and sync_state.watch_expires_at and sync_state.watch_expires_at - _now() > WATCH_RENEW_BEFORE:
        return
    base = f"{FORMS_API}/{sync_state.google_form_id}/watches"
    try:
        payload = None
        if sync_state.watch_id:
            try:
                payload = _google_request("POST", f"{base}/{sync_state.watch_id}:renew", access_token, json={})
            except GoogleFormsApiError:
                payload = None
        if payload is None:
            payload = _google_request("POST", base, access_token, json={
                "watch": {"target": {"topic": {"topicName": topic}}, "eventType": "RESPONSES"}
            })
        sync_state.watch_id = payload.get("id") or sync_state.watch_id
        sync_state.watch_expires_at = _parse_google_time(payload.get("expireTime"))
    except GoogleFormsApiError as exc:
        # Polling still delivers responses when push notifications cannot be registered.
        logger.warning("Google Forms watch registration failed for %s: %s", sync_state.google_form_id, exc)


def sync_guest_form(db: Session, guest_form: GuestForm) -> dict:
    sync_state = db.execute(select(GoogleFormSyncState).where(
        GoogleFormSyncState.guest_form_id == guest_form.id
    )).scalar_one_or_none()
    if sync_state is None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Connect a Google Form first.")

    from backend.app.services.subscription_service import require_feature
    require_feature(db, guest_form.organization_id, "google_forms")
    summary = {"received": 0, "matched": 0, "pending_review": 0, "failed": 0}
    guest_form.google_sync_status = STATUS_SYNCING
    db.commit()
    try:
        token = _access_token(db, sync_state.host_id)
        form = _google_request("GET", f"{FORMS_API}/{sync_state.google_form_id}", token)
        sync_state.question_map = build_question_map(form)
        sync_state.responder_uri = form.get("responderUri") or sync_state.responder_uri
        guest_form.title = ((form.get("info") or {}).get("title") or guest_form.title)[:255]
        _ensure_watch(db, sync_state, token)

        params: dict = {"pageSize": 200}
        if sync_state.last_response_time:
            params["filter"] = f"timestamp >= {sync_state.last_response_time}"
        newest = sync_state.last_response_time
        newest_dt = _parse_google_time(newest)
        while True:
            page = _google_request("GET", f"{FORMS_API}/{sync_state.google_form_id}/responses", token, params=params)
            for response in page.get("responses") or []:
                stamp = response.get("lastSubmittedTime") or response.get("createTime")
                try:
                    with db.begin_nested():
                        is_new = _process_response(db, guest_form, sync_state, response)
                except IntegrityError:
                    # Another worker stored this response concurrently; it will be reconciled there.
                    continue
                except Exception as exc:
                    logger.exception("Google Forms response %s failed", response.get("responseId"))
                    summary["failed"] += 1
                    _mark_response_failed(db, guest_form, sync_state, response, exc)
                    continue
                if is_new:
                    summary["received"] += 1
                stamp_dt = _parse_google_time(stamp)
                if stamp_dt and (newest_dt is None or stamp_dt > newest_dt):
                    newest_dt = stamp_dt
            if not page.get("nextPageToken"):
                break
            params["pageToken"] = page["nextPageToken"]

        _rematch_unmatched(db, guest_form)
        if summary["failed"] == 0 and newest_dt is not None:
            # Whole seconds keep the Forms filter valid; ">=" plus idempotency avoids skipping equal timestamps.
            sync_state.last_response_time = newest_dt.replace(microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ")
        sync_state.consecutive_failures = 0 if summary["failed"] == 0 else sync_state.consecutive_failures + 1
        sync_state.next_attempt_at = None if summary["failed"] == 0 else _now() + timedelta(seconds=120)
        guest_form.google_sync_status = STATUS_CONNECTED if summary["failed"] == 0 else STATUS_FAILED
        guest_form.google_last_error = None if summary["failed"] == 0 else f"{summary['failed']} response(s) failed and will be retried."
        guest_form.google_last_sync_at = _now()
        db.commit()
    except GoogleFormsApiError as exc:
        db.rollback()
        _record_failure(db, guest_form, sync_state, exc)
        db.commit()
        return {**summary, "status": guest_form.google_sync_status, "error": str(exc)}

    counts = response_counts(db, guest_form.organization_id)
    summary.update({"matched": counts["synced"], "pending_review": counts["pending_review"]})
    return {**summary, "status": guest_form.google_sync_status, "error": guest_form.google_last_error}


def _mark_response_failed(db: Session, guest_form: GuestForm, sync_state: GoogleFormSyncState,
                          response: dict, exc: Exception) -> None:
    response_id = response.get("responseId")
    if not response_id:
        return
    try:
        with db.begin_nested():
            record = db.execute(select(GoogleFormResponse).where(
                GoogleFormResponse.google_form_id == sync_state.google_form_id,
                GoogleFormResponse.google_response_id == response_id,
            )).scalar_one_or_none()
            if record is None:
                record = GoogleFormResponse(
                    organization_id=guest_form.organization_id, host_id=sync_state.host_id,
                    guest_form_id=guest_form.id, google_form_id=sync_state.google_form_id,
                    google_response_id=response_id, match_status="unmatched",
                )
                db.add(record)
            record.sync_status = "failed"
            record.attempts = (record.attempts or 0) + 1
            record.last_error = f"Processing failed ({type(exc).__name__}); Ginata will retry."
    except Exception:
        logger.exception("Could not record failed Google Forms response %s", response_id)


def response_counts(db: Session, organization_id: str) -> dict:
    rows = db.execute(select(GoogleFormResponse.sync_status, func.count()).where(
        GoogleFormResponse.organization_id == organization_id
    ).group_by(GoogleFormResponse.sync_status)).all()
    counts = {"synced": 0, "pending_review": 0, "failed": 0, "processing": 0}
    counts.update({row[0]: row[1] for row in rows})
    return counts


def get_google_guest_form(db: Session, organization_id: str) -> Optional[GuestForm]:
    return db.execute(select(GuestForm).where(
        GuestForm.organization_id == organization_id, GuestForm.mode == "google_forms"
    ).order_by(GuestForm.created_at.desc())).scalars().first()


def configure_google_form(db: Session, host: HostUser, form_value: str, property_id: Optional[str]) -> GuestForm:
    form_id = parse_google_form_id(form_value)
    try:
        validate_google_oauth_config()
    except GoogleOAuthError as exc:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, str(exc)) from exc
    credential = db.execute(select(GoogleOAuthCredential).where(
        GoogleOAuthCredential.host_id == host.id
    )).scalar_one_or_none()
    if credential is None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Connect your Google account before linking a form.")
    if property_id and not db.execute(select(Property.id).where(
        Property.id == property_id, Property.organization_id == host.organization_id
    )).first():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Property not found.")
    try:
        token = _access_token(db, host.id)
        form = _google_request("GET", f"{FORMS_API}/{form_id}", token)
    except GoogleFormsApiError as exc:
        code = status.HTTP_503_SERVICE_UNAVAILABLE if exc.transient else status.HTTP_400_BAD_REQUEST
        raise HTTPException(code, str(exc)) from exc

    guest_form = get_google_guest_form(db, host.organization_id)
    if guest_form is None:
        guest_form = GuestForm(organization_id=host.organization_id, mode="google_forms", title="Google Form")
        db.add(guest_form)
        db.flush()
    sync_state = db.execute(select(GoogleFormSyncState).where(
        GoogleFormSyncState.guest_form_id == guest_form.id
    )).scalar_one_or_none()
    if sync_state is None:
        sync_state = GoogleFormSyncState(
            guest_form_id=guest_form.id, organization_id=host.organization_id, host_id=host.id, google_form_id=form_id,
        )
        db.add(sync_state)
    if sync_state.google_form_id != form_id or sync_state.host_id != host.id:
        sync_state.google_form_id = form_id
        sync_state.host_id = host.id
        sync_state.last_response_time = None
        sync_state.watch_id = None
        sync_state.watch_expires_at = None
    sync_state.question_map = build_question_map(form)
    sync_state.responder_uri = form.get("responderUri")
    sync_state.consecutive_failures = 0
    sync_state.next_attempt_at = None

    guest_form.title = ((form.get("info") or {}).get("title") or "Google Form")[:255]
    guest_form.property_id = property_id
    guest_form.is_active = True
    guest_form.google_form_id = form_id
    guest_form.google_connected_email = credential.email
    guest_form.google_sync_status = STATUS_CONNECTED
    guest_form.google_last_error = None
    log_audit_event(
        db=db, organization_id=host.organization_id, entity_type="guest_form", entity_id=guest_form.id,
        action="google_form_linked", actor_name=host.full_name, details={"google_form_id": form_id},
    )
    db.commit()
    db.refresh(guest_form)
    return guest_form


def disconnect_google_form(db: Session, host: HostUser) -> None:
    guest_form = get_google_guest_form(db, host.organization_id)
    if guest_form is None:
        return
    sync_state = db.execute(select(GoogleFormSyncState).where(
        GoogleFormSyncState.guest_form_id == guest_form.id
    )).scalar_one_or_none()
    if sync_state is not None:
        db.delete(sync_state)
    guest_form.is_active = False
    guest_form.google_sync_status = STATUS_DISCONNECTED
    log_audit_event(
        db=db, organization_id=host.organization_id, entity_type="guest_form", entity_id=guest_form.id,
        action="google_form_unlinked", actor_name=host.full_name, details={},
    )
    db.commit()


def assign_response(db: Session, host: HostUser, response_id: str, reservation_id: str) -> GoogleFormResponse:
    record = db.execute(select(GoogleFormResponse).where(
        GoogleFormResponse.id == response_id, GoogleFormResponse.organization_id == host.organization_id
    )).scalar_one_or_none()
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Guest response not found.")
    reservation = db.execute(select(Reservation).where(
        Reservation.id == reservation_id, Reservation.organization_id == host.organization_id
    )).scalar_one_or_none()
    if reservation is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Reservation not found.")
    if record.reservation_id and record.reservation_id != reservation.id:
        record.submission_id = None
    _apply_to_reservation(db, record, reservation, _fields_from_record(record))
    record.match_reason = f"Assigned by {host.full_name}"
    log_audit_event(
        db=db, organization_id=host.organization_id, entity_type="google_form_response", entity_id=record.id,
        action="google_form_response_assigned", actor_name=host.full_name, details={"reservation_id": reservation.id},
    )
    db.commit()
    db.refresh(record)
    return record


def _fields_from_record(record: GoogleFormResponse) -> dict:
    # Stored answers already have ID numbers masked, so they are never copied back as raw IDs.
    fields: dict[str, str] = {}
    for answer in record.answers or []:
        field = classify_question(answer.get("question", ""))
        if field and field != "id_number" and field not in fields:
            fields[field] = answer.get("answer", "")
    if record.guest_email:
        fields["email"] = record.guest_email
    if record.booking_reference:
        fields["booking_reference"] = record.booking_reference
    if record.check_in_date:
        fields["check_in_date"] = record.check_in_date.isoformat()
    return fields


def _rematch_unmatched(db: Session, guest_form: GuestForm) -> int:
    """Bookings are often created after the guest fills the form; retry matching recent unmatched responses."""
    matched = 0
    records = db.execute(select(GoogleFormResponse).where(
        GoogleFormResponse.guest_form_id == guest_form.id,
        GoogleFormResponse.match_status == "unmatched",
        GoogleFormResponse.sync_status == "pending_review",
        GoogleFormResponse.created_at >= _now() - timedelta(days=60),
    ).limit(100)).scalars().all()
    for record in records:
        fields = _fields_from_record(record)
        reservation, reason = match_reservation(db, guest_form.organization_id, guest_form.property_id, fields)
        if reservation is None:
            continue
        with db.begin_nested():
            _apply_to_reservation(db, record, reservation, fields)
            record.match_reason = reason
            _notify(
                db, guest_form.organization_id, "guest_check_in", "Guest check-in matched to a booking",
                f"{record.guest_name or 'A guest'} · {reservation.property.name if reservation.property else 'Booking'}"
                f" · Check-in {reservation.check_in_date.strftime('%d %b %Y')}",
                "google_form_response", record.id, f"gform-matched:{record.id}",
            )
        matched += 1
    return matched


def mark_forms_due(db: Session, google_form_id: str, watch_id: Optional[str]) -> list[str]:
    query = select(GoogleFormSyncState).where(GoogleFormSyncState.google_form_id == google_form_id)
    states = db.execute(query).scalars().all()
    if watch_id:
        states = [s for s in states if not s.watch_id or s.watch_id == watch_id]
    for sync_state in states:
        sync_state.next_attempt_at = None
    db.commit()
    return [s.guest_form_id for s in states]


def run_due_syncs(session_factory: Callable[[], Session], only_guest_form_ids: Optional[list[str]] = None) -> int:
    processed = 0
    with session_factory() as db:
        query = select(GuestForm).join(GoogleFormSyncState, GoogleFormSyncState.guest_form_id == GuestForm.id).where(
            GuestForm.mode == "google_forms", GuestForm.is_active.is_(True),
        )
        if only_guest_form_ids is not None:
            query = query.where(GuestForm.id.in_(only_guest_form_ids))
        else:
            now = _now()
            query = query.where(
                (GoogleFormSyncState.next_attempt_at.is_(None)) | (GoogleFormSyncState.next_attempt_at <= now)
            )
        for guest_form in db.execute(query).scalars().all():
            from backend.app.services.subscription_service import get_subscription, PLANS
            _, plan = get_subscription(db, guest_form.organization_id)
            if not PLANS[plan]["google_forms"]:
                continue
            try:
                sync_guest_form(db, guest_form)
                processed += 1
            except Exception:
                db.rollback()
                logger.exception("Scheduled Google Forms sync failed for %s", guest_form.id)
    return processed
