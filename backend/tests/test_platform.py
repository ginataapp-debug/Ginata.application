from datetime import timedelta
from unittest.mock import Mock

import pytest
from sqlalchemy import select, create_engine, inspect, text
from backend.tests.test_auth import auth_env, signup, headers, PASSWORD, EMAIL, otp, now
from backend.app.api.v1 import account, subscription, operations, properties, finances, guest_forms, reservations
from backend.app.core.config import settings
from backend.app.core.migrations import run_migrations
from backend.app.core.database import Base
from backend.app.models.models import HostUser, Organization, Subscription, Property, OperationalTask


@pytest.fixture
def platform_env(auth_env, monkeypatch):
    client, factory, smtp = auth_env
    for module in (account, subscription, operations, properties, finances, guest_forms, reservations):
        client.app.include_router(module.router, prefix="/api/v1")
    monkeypatch.setattr(settings, "RATE_LIMIT_ENABLED", False)
    monkeypatch.setattr(settings, "SUPABASE_URL", "https://supabase.example.test")
    monkeypatch.setattr(settings, "SUPABASE_ANON_KEY", "test-public-key")
    monkeypatch.setattr(settings, "SUPABASE_SERVICE_ROLE_KEY", "")
    return client, factory, smtp


def google_mock(monkeypatch, email=EMAIL, user_id="11111111-1111-4111-8111-111111111111"):
    response = Mock(status_code=200)
    response.json.return_value = {"user": {"id": user_id, "email": email, "email_confirmed_at": "2026-11-12", "identities": [{"provider": "google"}], "user_metadata": {"full_name": "Google Host"}}}
    monkeypatch.setattr(account.httpx, "post", Mock(return_value=response))


GOOGLE_BODY = {"code": "test-code", "code_verifier": "a" * 64}


def test_google_config_authorize_and_new_account(platform_env, monkeypatch):
    client, factory, _ = platform_env
    google_mock(monkeypatch)
    assert client.get("/api/v1/auth/config").json()["google_sign_in_enabled"]
    response = client.post("/api/v1/auth/google/authorize-url", json={"redirect_to": "com.ginata.app://login-callback", "code_challenge": "a" * 43})
    assert response.status_code == 200
    assert "code_challenge_method=s256" in response.json()["url"]
    production_redirect = "https://123159d9.ginata-application.pages.dev/app/"
    production_response = client.post(
        "/api/v1/auth/google/authorize-url",
        json={"redirect_to": production_redirect, "code_challenge": "a" * 43},
    )
    assert production_response.status_code == 200
    assert client.post("/api/v1/auth/google/authorize-url", json={"redirect_to": "https://evil.example.test", "code_challenge": "a" * 43}).status_code == 400
    created = client.post("/api/v1/auth/google", json=GOOGLE_BODY)
    assert created.status_code == 200, created.text
    assert created.json()["account_created"]
    assert created.json()["host"]["google_linked"]
    assert not created.json()["host"]["has_password"]
    sub = client.get("/api/v1/subscription", headers=headers(created.json()["token"]))
    assert sub.json()["plan"] == "trial"
    assert client.get(
        "/api/v1/subscription", headers=headers("supabase-access-token")
    ).status_code == 401
    assert client.post("/api/v1/auth/google", json=GOOGLE_BODY).json()["account_created"] is False


def test_google_link_unverified_verified_and_conflict(platform_env, monkeypatch):
    client, factory, _ = platform_env
    token = signup(client).json()["token"]
    google_mock(monkeypatch)
    rejected = client.post("/api/v1/auth/google", json=GOOGLE_BODY)
    assert rejected.status_code == 409
    assert rejected.json()["detail"]["code"] == "link_required"
    linked = client.post("/api/v1/auth/google/link", json=GOOGLE_BODY, headers=headers(token))
    assert linked.status_code == 200
    google_mock(monkeypatch, user_id="22222222-2222-4222-8222-222222222222")
    rejected = client.post("/api/v1/auth/google", json=GOOGLE_BODY)
    assert rejected.json()["detail"]["code"] == "google_account_conflict"
    client.delete("/api/v1/auth/google/link", headers=headers(token))
    token = client.post("/api/v1/auth/login", json={"email": EMAIL, "password": PASSWORD}).json()["token"]
    with factory() as db:
        db.scalar(select(HostUser)).is_verified = True
        db.commit()
    linked = client.post("/api/v1/auth/google", json=GOOGLE_BODY)
    assert linked.status_code == 200
    assert not linked.json()["account_created"]


def test_password_recovery_and_logout_all(platform_env):
    client, factory, smtp = platform_env
    token = signup(client).json()["token"]
    client.post("/api/v1/auth/password/forgot", json={"email": EMAIL})
    code = otp(smtp)
    assert client.post("/api/v1/auth/password/reset", json={"email": EMAIL, "code": "000000" if code != "000000" else "000001", "new_password": "new-password-123"}).status_code == 400
    reset = client.post("/api/v1/auth/password/reset", json={"email": EMAIL, "code": code, "new_password": "new-password-123"})
    assert reset.status_code == 200
    assert client.get("/api/v1/auth/me", headers=headers(token)).status_code == 401
    assert client.post("/api/v1/auth/password/reset", json={"email": EMAIL, "code": code, "new_password": "new-password-123"}).status_code == 400
    token = client.post("/api/v1/auth/login", json={"email": EMAIL, "password": "new-password-123"}).json()["token"]
    second = client.post("/api/v1/auth/login", json={"email": EMAIL, "password": "new-password-123"}).json()["token"]
    changed = client.post("/api/v1/auth/password/change", json={"current_password": "new-password-123", "new_password": "changed-password-123"}, headers=headers(token))
    assert changed.status_code == 200
    assert client.get("/api/v1/auth/me", headers=headers(second)).status_code == 401
    assert client.get("/api/v1/auth/me", headers=headers(token)).status_code == 200
    assert client.post("/api/v1/auth/logout-all", headers=headers(token)).status_code == 200
    assert client.get("/api/v1/auth/me", headers=headers(token)).status_code == 401
    assert client.post("/api/v1/auth/password/forgot", json={"email": "absent@example.com"}).status_code == 200


def test_delete_account_isolation_and_shared_org(platform_env):
    client, factory, _ = platform_env
    first = signup(client).json()
    second = signup(client, "second@example.com").json()
    first_h, second_h = headers(first["token"]), headers(second["token"])
    prop = client.post("/api/v1/properties", json={"name": "Other Property", "slug": "other"}, headers=second_h).json()
    assert client.post("/api/v1/auth/account/delete", json={"confirm": "DELETE", "password": "wrong"}, headers=first_h).status_code == 400
    response = client.post("/api/v1/auth/account/delete", json={"confirm": "DELETE", "password": PASSWORD}, headers=first_h)
    assert response.status_code == 200, response.text
    assert response.json()["deleted_organization"]
    assert client.get("/api/v1/properties/" + prop["id"], headers=second_h).status_code == 200
    assert client.get("/api/v1/auth/me", headers=second_h).status_code == 200
    third = signup(client, "third@example.com").json()
    with factory() as db:
        host = db.get(HostUser, third["host"]["id"])
        host.organization_id = second["organization_id"]
        db.commit()
    response = client.post("/api/v1/auth/account/delete", json={"confirm": "DELETE", "password": PASSWORD}, headers=headers(third["token"]))
    assert response.status_code == 200, response.text
    assert not response.json()["deleted_organization"]
    assert client.get("/api/v1/properties/" + prop["id"], headers=second_h).status_code == 200


def test_trial_expiry_property_limit_admin_and_finance_gate(platform_env, monkeypatch):
    client, factory, _ = platform_env
    created = signup(client).json()
    h = headers(created["token"])
    with factory() as db:
        sub = db.get(Subscription, created["organization_id"])
        sub.trial_ends_at = now() - timedelta(days=1)
        db.commit()
    assert client.get("/api/v1/subscription", headers=h).json()["plan"] == "free"
    assert client.get("/api/v1/finances/expenses/export", headers=h).status_code == 403
    assert client.post("/api/v1/properties", json={"name": "One", "slug": "one"}, headers=h).status_code == 201
    restricted = client.post("/api/v1/properties", json={"name": "Two", "slug": "two"}, headers=h)
    assert restricted.json()["detail"]["code"] == "plan_required"
    monkeypatch.setattr(settings, "ADMIN_API_KEY", "test-admin-key")
    body = {"email": EMAIL, "plan": "pro"}
    assert client.put("/api/v1/admin/subscriptions", json=body).status_code == 403
    assert client.put("/api/v1/admin/subscriptions", json=body, headers={"X-Admin-Key": "test-admin-key"}).status_code == 200
    assert client.get("/api/v1/subscription", headers=h).json()["plan"] == "pro"


def test_property_calendar_tasks_guests_and_tenant_boundaries(platform_env, monkeypatch):
    client, factory, _ = platform_env
    first, second = signup(client).json(), signup(client, "second@example.com").json()
    h, other = headers(first["token"]), headers(second["token"])
    prop = client.post("/api/v1/properties", headers=h, json={"name": "Villa", "slug": "villa", "description": "Warm villa", "amenities": ["WiFi"], "airbnb_ical_url": "https://www.airbnb.com/calendar/ical/test.ics"}).json()
    assert prop["description"] == "Warm villa"
    assert client.get(f"/api/v1/properties/{prop['id']}/feed.ics").status_code == 404
    assert client.get(f"/api/v1/properties/{prop['id']}/feed.ics?token={prop['ical_feed_token']}").status_code == 200
    from backend.app.services import ical_service
    monkeypatch.setattr(ical_service, "download_feed", lambda url: b"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:test-event\r\nDTSTART;VALUE=DATE:20261201\r\nDTEND;VALUE=DATE:20261203\r\nSUMMARY:Reserved\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")
    synced = client.post(f"/api/v1/properties/{prop['id']}/sync-channels", headers=h)
    assert synced.status_code == 200, synced.text
    assert synced.json()["imported"] == 1
    assert client.get("/api/v1/properties/external-blocks", headers=other).json() == []
    booking = {"property_id": prop["id"], "guest_first_name": "Guest", "guest_last_name": "One", "check_in_date": "2026-12-10", "check_out_date": "2026-12-12", "number_of_guests": 1}
    created = client.post("/api/v1/reservations", headers=h, json=booking)
    assert created.status_code == 201, created.text
    res = created.json()
    assert res["nightly_rate"] == "15000.00"
    assert client.post(f"/api/v1/reservations/{res['id']}/check-in", headers=other).status_code == 404
    assert client.post(f"/api/v1/reservations/{res['id']}/check-in", headers=h).status_code == 200
    assert client.post(f"/api/v1/reservations/{res['id']}/check-out", headers=h).status_code == 200
    assert client.post(f"/api/v1/reservations/{res['id']}/check-out", headers=h).status_code == 409
    tasks = client.get("/api/v1/tasks", headers=h).json()
    assert len(tasks) == 1 and tasks[0]["kind"] == "cleaning"
    assert client.patch("/api/v1/tasks/" + tasks[0]["id"], json={"status": "done"}, headers=other).status_code == 404
    assert client.patch("/api/v1/tasks/" + tasks[0]["id"], json={"status": "done"}, headers=h).status_code == 200
    assert client.get("/api/v1/tasks/today", headers=h).json()["tasks"] == []
    guests = client.get("/api/v1/guests", headers=h).json()
    assert len(guests) == 1
    assert client.get("/api/v1/guests/" + guests[0]["id"], headers=other).status_code == 404
    form = client.post(f"/api/v1/reservations/{res['id']}/guest-form", headers=h).json()
    assert client.get(f"/api/v1/public/forms/{form['token']}/fill").status_code == 200


def test_migrations_are_additive_and_idempotent(tmp_path):
    engine = create_engine(f"sqlite:///{(tmp_path / 'migration.sqlite').as_posix()}")
    Base.metadata.create_all(engine)
    with engine.begin() as connection:
        connection.execute(text("INSERT INTO organizations (id,name,currency,country,created_at,updated_at) VALUES ('kept','Kept','KES','Kenya',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)"))
    run_migrations(engine)
    run_migrations(engine)
    with engine.connect() as connection:
        assert connection.execute(text("SELECT name FROM organizations WHERE id='kept'")).scalar() == "Kept"
    engine.dispose()


def test_ical_rejects_ssrf_and_invalid_calendars():
    from backend.app.services.ical_service import validate_feed_url, parse_feed
    for url in ("http://www.airbnb.com/a", "https://127.0.0.1/a", "https://evil.example/a", "https://airbnb.com@evil.example/a", "https://www.airbnb.com:444/a"):
        with pytest.raises(ValueError):
            validate_feed_url(url)
    with pytest.raises(ValueError):
        parse_feed(b"<html>not a calendar</html>")
