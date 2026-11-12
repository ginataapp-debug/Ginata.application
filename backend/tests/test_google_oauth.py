"""Isolated OAuth tests; all Google network calls are mocked and SQLite is temporary."""
import base64
from datetime import datetime, timedelta, timezone
from urllib.parse import parse_qs, urlparse
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import sessionmaker

from backend.app.api.v1 import auth, google_oauth
from backend.app.core.config import settings
from backend.app.core.database import Base, get_db
from backend.app.models.models import GoogleOAuthCredential, GoogleOAuthState
from backend.app.services import google_oauth_service
from backend.app.services.google_oauth_service import (
    GOOGLE_API_SCOPES,
    GoogleOAuthError,
    decrypt_google_refresh_token,
    encrypt_google_refresh_token,
    get_valid_google_access_token,
)

CALLBACK = "https://ginata-backend.onrender.com/api/v1/integrations/google/callback"


def now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


@pytest.fixture
def oauth_env(tmp_path, monkeypatch):
    engine = create_engine(
        f"sqlite:///{(tmp_path / 'google-oauth.sqlite').as_posix()}", connect_args={"check_same_thread": False}
    )

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False)
    isolated_app = FastAPI()
    isolated_app.include_router(auth.router, prefix="/api/v1")
    isolated_app.include_router(google_oauth.router, prefix="/api/v1")

    def isolated_db():
        with factory() as db:
            yield db

    isolated_app.dependency_overrides[get_db] = isolated_db
    monkeypatch.setattr(settings, "REQUIRE_EMAIL_VERIFICATION", False)
    monkeypatch.setattr(settings, "RATE_LIMIT_ENABLED", False)
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_ID", "test-client.apps.googleusercontent.com")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_SECRET", "test-client-secret")
    monkeypatch.setattr(settings, "GOOGLE_REDIRECT_URI", CALLBACK)
    monkeypatch.setattr(
        settings, "GOOGLE_TOKEN_ENCRYPTION_KEY", base64.urlsafe_b64encode(b"\x11" * 32).decode("ascii")
    )
    monkeypatch.setattr(settings, "GOOGLE_OAUTH_STATE_SECRET", "test-state-secret-with-at-least-32-bytes")
    monkeypatch.setattr(settings, "GOOGLE_OAUTH_STATE_TTL_MINUTES", 10)
    exchange = MagicMock(return_value={
        "access_token": "test-access-token",
        "refresh_token": "test-refresh-token",
        "scope": "openid email " + " ".join(sorted(GOOGLE_API_SCOPES)),
    })
    identity = MagicMock(return_value={
        "sub": "google-account-123", "email": "Host.Google@example.com", "email_verified": True,
    })
    revoke = MagicMock()
    monkeypatch.setattr(google_oauth, "exchange_google_authorization_code", exchange)
    monkeypatch.setattr(google_oauth, "fetch_google_identity", identity)
    monkeypatch.setattr(google_oauth, "revoke_google_refresh_token", revoke)
    with TestClient(isolated_app) as client:
        yield client, factory, exchange, identity, revoke
    isolated_app.dependency_overrides.clear()
    engine.dispose()


def signup(client, email="host@example.com"):
    response = client.post("/api/v1/auth/signup", json={
        "full_name": "Test Host", "email": email, "password": "secure password 123",
    })
    assert response.status_code == 201
    return response.json()["token"]


def headers(token):
    return {"Authorization": f"Bearer {token}"}


def authorization(client, token):
    response = client.get("/api/v1/integrations/google/authorize", headers=headers(token))
    assert response.status_code == 200
    return response.json()


def state_from(payload):
    return parse_qs(urlparse(payload["authorization_url"]).query)["state"][0]


def connect(client, token):
    state = state_from(authorization(client, token))
    return client.get("/api/v1/integrations/google/callback", params={"code": "test-code", "state": state})


def test_authorization_requires_host_and_requests_offline_access(oauth_env):
    client, factory, _, _, _ = oauth_env
    assert client.get("/api/v1/integrations/google/authorize").status_code == 401
    token = signup(client)
    payload = authorization(client, token)
    query = parse_qs(urlparse(payload["authorization_url"]).query)
    assert query["redirect_uri"] == [CALLBACK]
    assert query["access_type"] == ["offline"]
    assert query["prompt"] == ["consent"]
    assert query["include_granted_scopes"] == ["true"]
    assert GOOGLE_API_SCOPES.issubset(set(query["scope"][0].split()))
    assert payload["expires_in"] == 600
    assert "test-client-secret" not in payload["authorization_url"]
    assert "refresh_token" not in payload
    with factory() as db:
        stored = db.scalar(select(GoogleOAuthState))
        assert stored is not None
        assert stored.nonce_hash not in query["state"][0]
        assert stored.consumed_at is None
        assert stored.expires_at > now()


def test_callback_encrypts_token_binds_host_and_rejects_replay(oauth_env):
    client, factory, exchange, identity, _ = oauth_env
    token = signup(client)
    state = state_from(authorization(client, token))
    response = client.get("/api/v1/integrations/google/callback", params={"code": "test-code", "state": state})
    assert response.status_code == 200
    assert "test-refresh-token" not in response.text
    assert "test-access-token" not in response.text
    assert "test-client-secret" not in response.text
    assert response.headers["cache-control"] == "no-store"
    exchange.assert_called_once_with("test-code")
    identity.assert_called_once_with("test-access-token")
    with factory() as db:
        credential = db.scalar(select(GoogleOAuthCredential))
        host_id = db.scalar(select(GoogleOAuthState)).host_id
        assert credential.host_id == host_id
        assert credential.email == "host.google@example.com"
        assert "test-refresh-token" not in credential.encrypted_refresh_token
        assert decrypt_google_refresh_token(credential.encrypted_refresh_token, host_id) == "test-refresh-token"
        assert db.scalar(select(GoogleOAuthState)).consumed_at is not None
    replay = client.get("/api/v1/integrations/google/callback", params={"code": "test-code", "state": state})
    assert replay.status_code == 400
    assert exchange.call_count == 1
    status = client.get("/api/v1/integrations/google/status", headers=headers(token))
    assert status.status_code == 200
    assert set(status.json()) == {"connected", "email", "scopes", "connected_at"}
    assert status.json()["connected"] is True
    assert "token" not in status.text


def test_tampered_expired_and_denied_states_never_reach_google(oauth_env):
    client, factory, exchange, _, _ = oauth_env
    token = signup(client)
    state = state_from(authorization(client, token))
    tampered = client.get("/api/v1/integrations/google/callback", params={"code": "test-code", "state": state + "x"})
    assert tampered.status_code == 400
    with factory() as db:
        db.scalar(select(GoogleOAuthState)).expires_at = now() - timedelta(seconds=1)
        db.commit()
    expired = client.get("/api/v1/integrations/google/callback", params={"code": "test-code", "state": state})
    assert expired.status_code == 400
    denied_state = state_from(authorization(client, token))
    denied = client.get("/api/v1/integrations/google/callback", params={
        "error": "access_denied", "state": denied_state,
    })
    assert denied.status_code == 400
    with factory() as db:
        states = db.scalars(select(GoogleOAuthState)).all()
        assert states[-1].consumed_at is not None
        assert db.scalar(select(GoogleOAuthCredential)) is None
    exchange.assert_not_called()


def test_google_account_cannot_be_shared_between_hosts(oauth_env):
    client, factory, _, _, _ = oauth_env
    first = signup(client)
    second = signup(client, "second@example.com")
    assert connect(client, first).status_code == 200
    response = connect(client, second)
    assert response.status_code == 400
    assert "another Ginata host" in response.text
    with factory() as db:
        credentials = db.scalars(select(GoogleOAuthCredential)).all()
        assert len(credentials) == 1
        assert client.get("/api/v1/integrations/google/status", headers=headers(second)).json()["connected"] is False


def test_reconnect_without_new_refresh_token_preserves_existing_credential(oauth_env):
    client, factory, exchange, _, _ = oauth_env
    token = signup(client)
    assert connect(client, token).status_code == 200
    with factory() as db:
        original = db.scalar(select(GoogleOAuthCredential)).encrypted_refresh_token
    exchange.return_value = {
        "access_token": "new-access-token",
        "scope": "openid email " + " ".join(sorted(GOOGLE_API_SCOPES)),
    }
    assert connect(client, token).status_code == 200
    with factory() as db:
        credential = db.scalar(select(GoogleOAuthCredential))
        assert credential.encrypted_refresh_token == original
        assert decrypt_google_refresh_token(credential.encrypted_refresh_token, credential.host_id) == "test-refresh-token"


def test_first_connection_requires_refresh_token(oauth_env):
    client, factory, exchange, _, _ = oauth_env
    token = signup(client)
    exchange.return_value = {"access_token": "test-access-token", "scope": "openid email " + " ".join(GOOGLE_API_SCOPES)}
    response = connect(client, token)
    assert response.status_code == 400
    assert "offline access" in response.text
    with factory() as db:
        assert db.scalar(select(GoogleOAuthCredential)) is None


def test_encryption_is_host_bound(oauth_env):
    encrypted = encrypt_google_refresh_token("private-refresh-token", "host-one")
    assert decrypt_google_refresh_token(encrypted, "host-one") == "private-refresh-token"
    assert "private-refresh-token" not in encrypted
    with pytest.raises(GoogleOAuthError):
        decrypt_google_refresh_token(encrypted, "host-two")


def test_refresh_token_is_exchanged_only_by_backend_service(oauth_env, monkeypatch):
    client, factory, _, _, _ = oauth_env
    token = signup(client)
    assert connect(client, token).status_code == 200
    post = MagicMock(return_value={"access_token": "refreshed-access-token", "refresh_token": "rotated-refresh-token"})
    monkeypatch.setattr(google_oauth_service, "_post_google_form", post)
    with factory() as db:
        credential = db.scalar(select(GoogleOAuthCredential))
        host_id = credential.host_id
        assert get_valid_google_access_token(db, host_id) == "refreshed-access-token"
    request = post.call_args.args[1]
    assert request["grant_type"] == "refresh_token"
    assert request["refresh_token"] == "test-refresh-token"
    with factory() as db:
        credential = db.scalar(select(GoogleOAuthCredential))
        assert decrypt_google_refresh_token(credential.encrypted_refresh_token, host_id) == "rotated-refresh-token"
        assert credential.last_refreshed_at is not None


def test_disconnect_revokes_and_deletes_only_current_host_connection(oauth_env):
    client, factory, _, _, revoke = oauth_env
    token = signup(client)
    other = signup(client, "other@example.com")
    assert connect(client, token).status_code == 200
    response = client.delete("/api/v1/integrations/google/connection", headers=headers(token))
    assert response.status_code == 200
    revoke.assert_called_once_with("test-refresh-token")
    assert client.get("/api/v1/integrations/google/status", headers=headers(token)).json()["connected"] is False
    assert client.get("/api/v1/integrations/google/status", headers=headers(other)).json()["connected"] is False
    with factory() as db:
        assert db.scalar(select(GoogleOAuthCredential)) is None


def test_missing_server_configuration_fails_closed(oauth_env, monkeypatch):
    client, factory, _, _, _ = oauth_env
    token = signup(client)
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_SECRET", "")
    response = client.get("/api/v1/integrations/google/authorize", headers=headers(token))
    assert response.status_code == 503
    assert "GOOGLE_CLIENT_SECRET" in response.json()["detail"]
    with factory() as db:
        assert db.scalar(select(GoogleOAuthState)) is None
