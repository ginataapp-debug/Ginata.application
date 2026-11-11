"""Google Forms sync tests; every Google call is faked and SQLite is temporary."""
import base64
from datetime import date, timedelta

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import sessionmaker

from backend.app.api.v1 import auth, guest_forms, notifications
from backend.app.core.config import settings
from backend.app.core.database import Base, get_db
from backend.app.models.models import (
    Guest, GuestFormSubmission, GoogleFormResponse, GoogleFormSyncState, GoogleOAuthCredential,
    HostNotification, HostUser, Property, Reservation,
)
from backend.app.services import google_forms_sync_service as sync
from backend.app.services.google_forms_sync_service import GoogleFormsApiError, parse_google_form_id

FORM_ID = "1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"
FORM = {
    "formId": FORM_ID,
    "info": {"title": "Ginata pre-arrival check-in"},
    "responderUri": "https://docs.google.com/forms/d/e/responder/viewform",
    "items": [
        {"title": "Full name", "questionItem": {"question": {"questionId": "q_name"}}},
        {"title": "Email address", "questionItem": {"question": {"questionId": "q_email"}}},
        {"title": "Phone number", "questionItem": {"question": {"questionId": "q_phone"}}},
        {"title": "Booking reference", "questionItem": {"question": {"questionId": "q_ref"}}},
        {"title": "Check-in date", "questionItem": {"question": {"questionId": "q_date"}}},
        {"title": "Expected arrival time", "questionItem": {"question": {"questionId": "q_eta"}}},
        {"title": "Passport or ID number", "questionItem": {"question": {"questionId": "q_id"}}},
    ],
}


def answer(value):
    return {"textAnswers": {"answers": [{"value": value}]}}


def make_response(response_id, stamp, **values):
    keys = {"name": "q_name", "email": "q_email", "phone": "q_phone", "ref": "q_ref",
            "date": "q_date", "eta": "q_eta", "id": "q_id"}
    return {
        "responseId": response_id,
        "createTime": stamp,
        "lastSubmittedTime": stamp,
        "answers": {keys[k]: answer(v) for k, v in values.items()},
    }


class FakeGoogle:
    def __init__(self):
        self.responses = []
        self.error = None
        self.calls = []

    def __call__(self, method, url, access_token, **kwargs):
        self.calls.append((method, url, kwargs.get("params")))
        if self.error:
            raise self.error
        if url.endswith("/responses"):
            return {"responses": list(self.responses)}
        if "/watches" in url:
            return {"id": "watch-1", "expireTime": "2099-01-01T00:00:00Z"}
        return FORM


@pytest.fixture
def env(tmp_path, monkeypatch):
    engine = create_engine(
        f"sqlite:///{(tmp_path / 'forms-sync.sqlite').as_posix()}", connect_args={"check_same_thread": False}
    )

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False)
    app = FastAPI()
    for module in (auth, guest_forms, notifications):
        app.include_router(module.router, prefix="/api/v1")

    def isolated_db():
        with factory() as db:
            yield db

    app.dependency_overrides[get_db] = isolated_db
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", False)
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_ID", "test-client.apps.googleusercontent.com")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_SECRET", "test-client-secret")
    monkeypatch.setattr(settings, "GOOGLE_REDIRECT_URI", "https://ginata-backend.onrender.com/api/v1/integrations/google/callback")
    monkeypatch.setattr(settings, "GOOGLE_TOKEN_ENCRYPTION_KEY", base64.urlsafe_b64encode(b"\x22" * 32).decode("ascii"))
    monkeypatch.setattr(settings, "GOOGLE_OAUTH_STATE_SECRET", "test-state-secret-with-at-least-32-bytes")
    monkeypatch.setattr(settings, "GOOGLE_FORMS_PUSH_TOKEN", "push-secret-token")
    monkeypatch.setattr(settings, "GOOGLE_FORMS_PUBSUB_TOPIC", "")
    fake = FakeGoogle()
    monkeypatch.setattr(sync, "_google_request", fake)
    monkeypatch.setattr(sync, "get_valid_google_access_token", lambda db, host_id: "test-access-token")
    monkeypatch.setattr(guest_forms, "SessionLocal", factory)
    with TestClient(app) as client:
        yield client, factory, fake
    app.dependency_overrides.clear()
    engine.dispose()


def signup(client, email):
    response = client.post("/api/v1/auth/signup", json={
        "full_name": "Test Host", "email": email, "password": "secure password 123",
    })
    assert response.status_code == 201
    return response.json()["token"]


def h(token):
    return {"Authorization": f"Bearer {token}"}


def host_setup(client, factory, email="host@example.com", connect_google=True):
    token = signup(client, email)
    with factory() as db:
        host = db.execute(select(HostUser).where(HostUser.email == email)).scalar_one()
        if connect_google:
            db.add(GoogleOAuthCredential(
                host_id=host.id, provider_account_id=f"sub-{email}", email=email,
                encrypted_refresh_token="v1.unused", scopes=[],
            ))
        prop = Property(organization_id=host.organization_id, name="Karen Garden Villa", slug=f"villa-{host.id[:6]}")
        db.add(prop)
        db.commit()
        return token, host.organization_id, prop.id


def add_reservation(factory, org_id, property_id, ref, email, check_in, first="Amina"):
    with factory() as db:
        guest = Guest(organization_id=org_id, first_name=first, last_name="Otieno", email=email)
        db.add(guest)
        db.flush()
        res = Reservation(
            organization_id=org_id, property_id=property_id, primary_guest_id=guest.id,
            booking_reference=ref, check_in_date=check_in, check_out_date=check_in + timedelta(days=3),
            nightly_rate=10000, base_amount=30000, total_amount=30000, balance_due=30000, number_of_nights=3,
        )
        db.add(res)
        db.commit()
        return res.id


def link_form(client, token):
    response = client.put("/api/v1/guest-forms/google/config", headers=h(token), json={
        "form": f"https://docs.google.com/forms/d/{FORM_ID}/edit"
    })
    assert response.status_code == 200, response.text
    return response.json()


def test_form_link_parsing_accepts_edit_links_and_rejects_responder_links():
    assert parse_google_form_id(f"https://docs.google.com/forms/d/{FORM_ID}/edit") == FORM_ID
    assert parse_google_form_id(FORM_ID) == FORM_ID
    for bad in ("https://docs.google.com/forms/d/e/1FAIpQLSexample/viewform", "https://example.com/forms/d/x/edit", ""):
        with pytest.raises(Exception) as exc:
            parse_google_form_id(bad)
        assert getattr(exc.value, "status_code", None) == 422


def test_linking_requires_connected_google_account(env):
    client, factory, _ = env
    token, _, _ = host_setup(client, factory, connect_google=False)
    response = client.put("/api/v1/guest-forms/google/config", headers=h(token), json={"form": FORM_ID})
    assert response.status_code == 409
    assert client.get("/api/v1/guest-forms/google/status", headers=h(token)).json()["form_linked"] is False


def test_matched_response_updates_booking_and_notifies_without_id(env):
    client, factory, fake = env
    token, org_id, prop_id = host_setup(client, factory)
    check_in = date.today() + timedelta(days=5)
    res_id = add_reservation(factory, org_id, prop_id, "GIN-1001", "amina@example.com", check_in)
    fake.responses = [make_response(
        "resp-1", "2026-11-12T08:00:00.123456789Z", name="Amina Otieno", email="Amina@Example.com",
        ref="gin-1001", eta="14:00", id="A12345678",
    )]
    status = link_form(client, token)
    assert status["form_linked"] and status["is_connected"] and status["counts"]["pending_review"] == 1

    with factory() as db:
        record = db.execute(select(GoogleFormResponse)).scalar_one()
        assert record.reservation_id == res_id and record.match_status == "matched"
        assert record.sync_status == "pending_review"  # ID supplied, so the host reviews it
        assert "A12345678" not in str(record.answers) and "*****5678" in str(record.answers)
        submission = db.execute(select(GuestFormSubmission)).scalar_one()
        assert submission.reservation_id == res_id and submission.eta == "14:00"
        assert submission.id_number == "*****5678"
        reservation = db.get(Reservation, res_id)
        assert reservation.guest_info_status == "needs_review"
        assert reservation.check_in_date == check_in and reservation.total_amount == 30000
        note = db.execute(select(HostNotification)).scalar_one()
        assert note.title == "New guest check-in received!"
        assert "Amina Otieno" in note.body and "Karen Garden Villa" in note.body
        assert "5678" not in note.body and note.entity_id == record.id


def test_repeated_sync_is_idempotent(env):
    client, factory, fake = env
    token, org_id, prop_id = host_setup(client, factory)
    add_reservation(factory, org_id, prop_id, "GIN-2002", "guest@example.com", date.today() + timedelta(days=2))
    fake.responses = [make_response("resp-2", "2026-11-12T09:00:00Z", name="Guest", ref="GIN-2002")]
    link_form(client, token)
    for _ in range(3):
        result = client.post("/api/v1/guest-forms/google/sync", headers=h(token)).json()
        assert result["received"] == 0
    with factory() as db:
        assert len(db.execute(select(GoogleFormResponse)).scalars().all()) == 1
        assert len(db.execute(select(GuestFormSubmission)).scalars().all()) == 1
        assert len(db.execute(select(HostNotification)).scalars().all()) == 1
        cursor = db.execute(select(GoogleFormSyncState)).scalar_one().last_response_time
    assert cursor == "2026-11-12T09:00:00Z"
    assert fake.calls[-1][2]["filter"] == "timestamp >= 2026-11-12T09:00:00Z"


def test_unmatched_and_ambiguous_responses_wait_for_host(env):
    client, factory, fake = env
    token, org_id, prop_id = host_setup(client, factory)
    soon = date.today() + timedelta(days=3)
    first = add_reservation(factory, org_id, prop_id, "GIN-A", "twin@example.com", soon)
    add_reservation(factory, org_id, prop_id, "GIN-B", "twin@example.com", soon + timedelta(days=10))
    fake.responses = [
        make_response("resp-unknown", "2026-11-12T10:00:00Z", name="Stranger", ref="NOPE-1", email="nobody@example.com"),
        make_response("resp-twin", "2026-11-12T10:01:00Z", name="Twin", email="twin@example.com"),
    ]
    link_form(client, token)
    pending = client.get("/api/v1/guest-forms/google/responses?match_status=unmatched", headers=h(token)).json()
    assert {r["google_response_id"] for r in pending} == {"resp-unknown", "resp-twin"}
    assert all(r["reservation_id"] is None and r["sync_status"] == "pending_review" for r in pending)
    with factory() as db:
        assert db.execute(select(GuestFormSubmission)).first() is None
        assert db.get(Reservation, first).guest_info_status == "pending"
        titles = {n.title for n in db.execute(select(HostNotification)).scalars()}
    assert titles == {"New guest check-in needs review"}

    twin = next(r for r in pending if r["google_response_id"] == "resp-twin")
    assigned = client.post(f"/api/v1/guest-forms/google/responses/{twin['id']}/assign", headers=h(token),
                           json={"reservation_id": first})
    assert assigned.status_code == 200
    assert assigned.json()["match_status"] == "matched" and assigned.json()["reservation_id"] == first


def test_booking_created_after_submission_is_matched_on_next_sync(env):
    client, factory, fake = env
    token, org_id, prop_id = host_setup(client, factory)
    fake.responses = [make_response("resp-early", "2026-11-12T11:00:00Z", name="Early Bird", ref="GIN-LATE")]
    link_form(client, token)
    res_id = add_reservation(factory, org_id, prop_id, "GIN-LATE", None, date.today() + timedelta(days=9))
    client.post("/api/v1/guest-forms/google/sync", headers=h(token))
    with factory() as db:
        record = db.execute(select(GoogleFormResponse)).scalar_one()
        assert record.reservation_id == res_id and record.sync_status == "synced"


def test_revoked_google_access_requires_reconnection(env):
    client, factory, fake = env
    token, _, _ = host_setup(client, factory)
    link_form(client, token)
    fake.error = GoogleFormsApiError("Google denied access", reconnect=True)
    result = client.post("/api/v1/guest-forms/google/sync", headers=h(token)).json()
    assert result["status"] == "reconnect_required"
    status = client.get("/api/v1/guest-forms/google/status", headers=h(token)).json()
    assert status["sync_status"] == "reconnect_required" and status["is_connected"] is False
    with factory() as db:
        assert db.execute(select(HostNotification).where(HostNotification.kind == "google_reconnect")).scalar_one()
        assert db.execute(select(GoogleFormSyncState)).scalar_one().next_attempt_at is not None


def test_transient_failure_keeps_cursor_for_retry(env):
    client, factory, fake = env
    token, _, _ = host_setup(client, factory)
    fake.responses = [make_response("resp-3", "2026-11-12T12:00:00Z", name="Guest Three")]
    link_form(client, token)
    fake.responses.append(make_response("resp-4", "2026-11-12T13:00:00Z", name="Guest Four"))
    fake.error = GoogleFormsApiError("busy", transient=True)
    assert client.post("/api/v1/guest-forms/google/sync", headers=h(token)).json()["status"] == "failed"
    fake.error = None
    assert client.post("/api/v1/guest-forms/google/sync", headers=h(token)).json()["received"] == 1
    with factory() as db:
        assert len(db.execute(select(GoogleFormResponse)).scalars().all()) == 2


def test_hosts_cannot_see_or_assign_other_hosts_responses(env):
    client, factory, fake = env
    owner, org_id, prop_id = host_setup(client, factory, "owner@example.com")
    other, other_org, other_prop = host_setup(client, factory, "other@example.com")
    other_res = add_reservation(factory, other_org, other_prop, "OTHER-1", "x@example.com", date.today())
    fake.responses = [make_response("resp-5", "2026-11-12T14:00:00Z", name="Private", ref="OTHER-1")]
    link_form(client, owner)
    with factory() as db:
        record = db.execute(select(GoogleFormResponse)).scalar_one()
        assert record.reservation_id is None  # never matched across organizations
    assert client.get("/api/v1/guest-forms/google/responses", headers=h(other)).json() == []
    assert client.get(f"/api/v1/guest-forms/google/responses/{record.id}", headers=h(other)).status_code == 404
    denied = client.post(f"/api/v1/guest-forms/google/responses/{record.id}/assign", headers=h(owner),
                         json={"reservation_id": other_res})
    assert denied.status_code == 404
    assert client.get("/api/v1/notifications", headers=h(other)).json() == []


def test_push_notification_requires_secret_and_triggers_sync(env):
    client, factory, fake = env
    token, _, _ = host_setup(client, factory)
    link_form(client, token)
    body = {"message": {"attributes": {"formId": FORM_ID, "eventType": "RESPONSES"}}}
    assert client.post("/api/v1/integrations/google/forms/push?token=wrong", json=body).status_code == 403
    fake.responses = [make_response("resp-6", "2026-11-12T15:00:00Z", name="Pushed Guest")]
    assert client.post("/api/v1/integrations/google/forms/push?token=push-secret-token", json=body).status_code == 204
    with factory() as db:
        assert db.execute(select(GoogleFormResponse)).scalar_one().google_response_id == "resp-6"


def test_notification_summary_and_read_flow(env):
    client, factory, fake = env
    token, _, _ = host_setup(client, factory)
    fake.responses = [make_response("resp-7", "2026-11-12T16:00:00Z", name="Reader")]
    link_form(client, token)
    summary = client.get("/api/v1/notifications/summary", headers=h(token)).json()
    assert summary["unread_count"] == 1 and summary["latest_id"]
    read = client.post(f"/api/v1/notifications/{summary['latest_id']}/read", headers=h(token))
    assert read.status_code == 200 and read.json()["read_at"]
    assert client.get("/api/v1/notifications/summary", headers=h(token)).json()["unread_count"] == 0
    assert client.get("/api/v1/notifications/summary").status_code == 401
