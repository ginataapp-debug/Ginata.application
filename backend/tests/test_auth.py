"""Auth-only app and temporary SQLite database; never import test_all or start main."""
import hashlib
import re
import smtplib
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import sessionmaker

from backend.app.api.v1 import auth
from backend.app.core.config import settings
from backend.app.core.database import Base, get_db
from backend.app.core.security import hash_auth_token, verify_password
from backend.app.models.models import HostUser, HostSession, HostEmailVerification, Organization

EMAIL = "host@example.com"
PASSWORD = " secure password 123 "


def now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


@pytest.fixture
def auth_env(tmp_path, monkeypatch):
    # Only this engine is created/dropped, never the application's configured DB.
    engine = create_engine(f"sqlite:///{(tmp_path / 'auth.sqlite').as_posix()}", connect_args={"check_same_thread": False})

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False)
    isolated_app = FastAPI()
    isolated_app.include_router(auth.router, prefix="/api/v1")

    def isolated_db():
        with factory() as db:
            yield db

    isolated_app.dependency_overrides[get_db] = isolated_db
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", False)
    monkeypatch.setattr(settings, "RATE_LIMIT_ENABLED", False)
    monkeypatch.setattr(settings, "AUTH_SESSION_TTL_HOURS", 24)
    monkeypatch.setattr(settings, "SMTP_HOST", "smtp.example.test")
    monkeypatch.setattr(settings, "SMTP_PORT", 587)
    monkeypatch.setattr(settings, "SMTP_FROM_EMAIL", "no-reply@example.test")
    monkeypatch.setattr(settings, "SMTP_USERNAME", "test-user")
    monkeypatch.setattr(settings, "SMTP_PASSWORD", "test-password")
    monkeypatch.setattr(settings, "SMTP_USE_SSL", False)
    monkeypatch.setattr(settings, "SMTP_STARTTLS", True)
    monkeypatch.setattr(settings, "EMAIL_OTP_MAX_ATTEMPTS", 3)
    monkeypatch.setattr(settings, "EMAIL_OTP_RESEND_SECONDS", 60)
    smtp = MagicMock()
    smtp.send_message.return_value = {}
    smtp_factory = MagicMock()
    smtp_factory.return_value.__enter__.return_value = smtp
    # All SMTP entry points are mocked: these tests cannot send real emails.
    monkeypatch.setattr(auth.smtplib, "SMTP", smtp_factory)
    monkeypatch.setattr(auth.smtplib, "SMTP_SSL", smtp_factory)
    with TestClient(isolated_app) as client:
        yield client, factory, smtp
    isolated_app.dependency_overrides.clear()
    engine.dispose()


def signup(client, email=EMAIL, password=PASSWORD):
    return client.post("/api/v1/auth/signup", json={"full_name": "Test Host", "email": email, "password": password})


def login(client, email=EMAIL, password=PASSWORD):
    return client.post("/api/v1/auth/login", json={"email": email, "password": password})


def headers(token):
    return {"Authorization": f"Bearer {token}"}


def otp(smtp):
    message = smtp.send_message.call_args.args[0]
    return re.search(r"code is ([0-9]{6})", message.get_content()).group(1)


def verify(client, code):
    return client.post("/api/v1/auth/verification/verify", json={"email": EMAIL, "code": code})


def resend(client):
    return client.post("/api/v1/auth/verification/send", json={"email": EMAIL, "password": PASSWORD})


def test_independent_device_sessions_hashed_storage_and_logout(auth_env):
    client, factory, smtp = auth_env
    created = signup(client)
    assert created.status_code == 201
    first = created.json()["token"]
    assert created.json()["host"]["is_verified"] is False
    assert created.json()["verification_required"] is False
    assert "not been verified" in created.json()["message"]
    second = login(client).json()["token"]
    third = login(client).json()["token"]
    assert len({first, second, third}) == 3
    for token in (first, second, third):
        assert client.get("/api/v1/auth/me", headers=headers(token)).status_code == 200
    with factory() as db:
        sessions = db.scalars(select(HostSession)).all()
        assert {s.token_hash for s in sessions} == {hash_auth_token(t) for t in (first, second, third)}
        assert all(s.token_hash not in (first, second, third) for s in sessions)
        assert all(s.expires_at > s.created_at for s in sessions)
        assert db.scalar(select(HostUser)).session_token is None
    assert client.post("/api/v1/auth/logout", headers=headers(second)).status_code == 200
    assert client.get("/api/v1/auth/me", headers=headers(second)).status_code == 401
    for token in (first, third):
        assert client.get("/api/v1/auth/me", headers=headers(token)).status_code == 200
    smtp.send_message.assert_not_called()


def test_expired_inactive_and_legacy_sessions_are_rejected(auth_env):
    client, factory, _ = auth_env
    token = signup(client).json()["token"]
    with factory() as db:
        session = db.scalar(select(HostSession))
        session.expires_at = now() - timedelta(seconds=1)
        host = db.scalar(select(HostUser))
        host.session_token = "legacy-raw-token"
        db.commit()
    for rejected in (token, "legacy-raw-token", "unknown-token"):
        assert client.get("/api/v1/auth/me", headers=headers(rejected)).status_code == 401
    assert client.get("/api/v1/auth/me").status_code == 401
    fresh = login(client).json()["token"]
    with factory() as db:
        host = db.scalar(select(HostUser))
        assert host.session_token is None
        host.is_active = False
        db.commit()
    assert client.get("/api/v1/auth/me", headers=headers(fresh)).status_code == 401
    assert login(client).status_code == 403


def test_legacy_password_upgrade_and_no_password_trimming(auth_env):
    client, factory, _ = auth_env
    signup(client)
    salt = "original-salt"
    old_hash = hashlib.pbkdf2_hmac("sha256", PASSWORD.encode(), salt.encode(), 100_000).hex()
    with factory() as db:
        host = db.scalar(select(HostUser))
        host.password_hash, host.salt, host.session_token = old_hash, salt, "legacy"
        db.commit()
    assert login(client, password=PASSWORD.strip()).status_code == 401
    assert login(client).status_code == 200
    with factory() as db:
        host = db.scalar(select(HostUser))
        assert host.password_hash.startswith("pbkdf2_sha256$600000$")
        assert host.salt != salt
        assert verify_password(PASSWORD, host.salt, host.password_hash)
        assert host.session_token is None


def test_signup_validation_and_private_organizations(auth_env):
    client, factory, _ = auth_env
    assert signup(client, password="123456789").status_code == 422
    assert signup(client, email="not-an-email").status_code == 422
    first = signup(client).json()
    second = signup(client, email="other@example.com").json()
    assert first["organization_id"] != second["organization_id"]
    assert signup(client).status_code == 400
    with factory() as db:
        assert len(db.scalars(select(Organization)).all()) == 2


def test_confirmation_required_smtp_success_and_single_use(auth_env, monkeypatch):
    client, factory, smtp = auth_env
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", True)
    response = signup(client)
    assert response.status_code == 201
    body = response.json()
    assert body["verification_required"] is True
    assert body["token"] is None
    assert body["host"]["is_verified"] is False
    code = otp(smtp)
    smtp.starttls.assert_called_once()
    smtp.login.assert_called_once_with("test-user", "test-password")
    with factory() as db:
        challenge = db.scalar(select(HostEmailVerification))
        assert challenge.code_hash != code
        assert verify_password(code, challenge.id, challenge.code_hash)
        assert db.scalar(select(HostSession)) is None
    blocked = login(client)
    assert blocked.status_code == 403
    assert blocked.json()["detail"]["verification_required"] is True
    accepted = verify(client, code)
    assert accepted.status_code == 200
    assert accepted.json()["host"]["is_verified"] is True
    token = accepted.json()["token"]
    assert client.get("/api/v1/auth/me", headers=headers(token)).status_code == 200
    assert verify(client, code).status_code == 400
    assert login(client).status_code == 200
    with factory() as db:
        assert db.scalar(select(HostEmailVerification)).consumed_at is not None


def test_confirmation_expiry(auth_env, monkeypatch):
    client, factory, smtp = auth_env
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", True)
    signup(client)
    code = otp(smtp)
    with factory() as db:
        db.scalar(select(HostEmailVerification)).expires_at = now() - timedelta(seconds=1)
        db.commit()
    assert verify(client, code).status_code == 400
    with factory() as db:
        assert db.scalar(select(HostUser)).is_verified is False
        assert db.scalar(select(HostSession)) is None


def test_confirmation_attempt_limit_and_resend_invalidation(auth_env, monkeypatch):
    client, factory, smtp = auth_env
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", True)
    monkeypatch.setattr(auth.secrets, "randbelow", lambda _: 123456)
    signup(client)
    assert resend(client).status_code == 429
    for _ in range(3):
        assert verify(client, "000000").status_code == 400
    assert verify(client, "123456").status_code == 400
    with factory() as db:
        challenge = db.scalar(select(HostEmailVerification))
        assert challenge.attempts == 3
        challenge.created_at = now() - timedelta(seconds=61)
        db.commit()
    monkeypatch.setattr(auth.secrets, "randbelow", lambda _: 654321)
    assert resend(client).status_code == 200
    assert otp(smtp) == "654321"
    assert verify(client, "123456").status_code == 400
    assert verify(client, "654321").status_code == 200


def test_required_confirmation_without_smtp_does_not_create_account(auth_env, monkeypatch):
    client, factory, smtp = auth_env
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", True)
    monkeypatch.setattr(settings, "SMTP_HOST", "")
    response = signup(client)
    assert response.status_code == 503
    assert "not configured" in response.json()["detail"]
    smtp.send_message.assert_not_called()
    with factory() as db:
        assert db.scalar(select(HostUser)) is None
        assert db.scalar(select(Organization)) is None


def test_smtp_failure_rolls_back_signup(auth_env, monkeypatch):
    client, factory, smtp = auth_env
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", True)
    smtp.send_message.side_effect = smtplib.SMTPException("mock delivery failure")
    response = signup(client)
    assert response.status_code == 503
    assert "Unable to deliver" in response.json()["detail"]
    with factory() as db:
        assert db.scalar(select(HostUser)) is None
        assert db.scalar(select(HostEmailVerification)) is None
        assert db.scalar(select(Organization)) is None


def test_smtp_ssl_and_plaintext_refusal(auth_env, monkeypatch):
    client, factory, smtp = auth_env
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", True)
    monkeypatch.setattr(settings, "SMTP_STARTTLS", False)
    assert signup(client).status_code == 503
    smtp.send_message.assert_not_called()
    monkeypatch.setattr(settings, "SMTP_USE_SSL", True)
    monkeypatch.setattr(settings, "SMTP_PORT", 465)
    assert signup(client).status_code == 201
    smtp.starttls.assert_not_called()
    assert verify(client, otp(smtp)).status_code == 200


def test_send_requires_password_and_failed_resend_keeps_old_code(auth_env, monkeypatch):
    client, factory, smtp = auth_env
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", True)
    signup(client)
    original = otp(smtp)
    invalid = client.post("/api/v1/auth/verification/send", json={"email": EMAIL, "password": "wrong password"})
    assert invalid.status_code == 401
    assert smtp.send_message.call_count == 1
    with factory() as db:
        db.scalar(select(HostEmailVerification)).created_at = now() - timedelta(seconds=61)
        db.commit()
    smtp.send_message.side_effect = smtplib.SMTPException("mock failure")
    assert resend(client).status_code == 503
    assert verify(client, original).status_code == 200


def test_demo_seed_is_explicit_and_does_not_change_existing_users(auth_env, monkeypatch):
    # Main is imported without running startup; its database bindings are replaced
    # before seed_database is invoked. No application/default database is touched.
    from backend.app import main
    client, factory, _ = auth_env
    monkeypatch.setattr(main, "engine", factory.kw["bind"])
    monkeypatch.setattr(main, "SessionLocal", factory)
    monkeypatch.setattr(settings, "SEED_DEMO_HOST", False)
    main.seed_database()
    with factory() as db:
        assert db.scalar(select(HostUser)) is None
    monkeypatch.setattr(settings, "SEED_DEMO_HOST", True)
    main.seed_database()
    with factory() as db:
        host = db.scalar(select(HostUser))
        assert host.email == "host@ginata.ke"
        assert verify_password("host123456", host.salt, host.password_hash)
        original_id = host.id
    monkeypatch.setattr(settings, "SEED_DEMO_HOST", False)
    main.seed_database()
    with factory() as db:
        host = db.scalar(select(HostUser))
        assert host.id == original_id and host.is_active


def test_verification_flag_and_email_changes_cannot_bypass_confirmation(auth_env, monkeypatch):
    client, factory, smtp = auth_env
    token = signup(client).json()["token"]
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", True)
    assert client.get("/api/v1/auth/me", headers=headers(token)).status_code == 401
    assert resend(client).status_code == 200
    accepted = verify(client, otp(smtp)).json()
    token = accepted["token"]
    response = client.patch("/api/v1/auth/profile", headers=headers(token), json={"email": "new@example.com"})
    assert response.status_code == 400
    response = client.patch("/api/v1/auth/profile", headers=headers(token), json={"email": "new@example.com", "current_password": PASSWORD})
    assert response.status_code == 200
    assert response.json()["is_verified"] is False
    assert client.get("/api/v1/auth/me", headers=headers(token)).status_code == 401
    with factory() as db:
        assert db.scalar(select(HostSession)) is None
