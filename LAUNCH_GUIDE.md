# Ginata release and launch guide

This guide covers deploying the backend changes, publishing the web build, and
installing the Android APK. The application source in this release includes the
routes that are currently missing from the live backend. The live Render service
must deploy the release commit before those features will work.

## 1. Push the release commit to GitHub

The release commit is created locally in this repository. From the repository
root, review it and push it to the branch connected to Render:

```powershell
git status --short
git show --stat --oneline HEAD
git push origin main
```

Do not add `.env` files, `frontend/android/key.properties`, a signing keystore,
database files, or credentials to Git. Keep a secure backup of the Android
release keystore: future Android updates must use the same signing key.

## 2. Deploy and configure the backend

In Render, open the existing `ginata-backend` Web Service connected to
`xjijou/Ginata` and confirm it deploys the pushed `main` commit. If creating the
service for the first time, use the repository root as the root directory,
`pip install -r requirements.txt` as the build command, and
`python -m uvicorn backend.app.main:app --host 0.0.0.0 --port $PORT` as the
start command.

Before deploying against an existing database, take a database backup. The
backend runs additive schema setup at startup; it does not delete existing
records. Confirm the Render instance can reach the Supabase database and that
the database connection string uses TLS. Use a server-only PostgreSQL session
pooler URL, for example:

```text
postgresql+psycopg://postgres.<PROJECT_REF>:<URL_ENCODED_PASSWORD>@<SESSION_POOLER_HOST>:5432/postgres?sslmode=require
```

Configure these values in Render's Environment settings. Never put secrets in
Flutter build arguments, the web build, or the Git repository.

| Variable | Required value |
|---|---|
| `DATABASE_URL` | Supabase PostgreSQL session-pooler URL shown above |
| `PUBLIC_API_BASE_URL` | `https://ginata-backend.onrender.com` |
| `REQUIRE_EMAIL_VERIFICATION` | `true` for production account verification |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM_EMAIL` | Credentials for a real SMTP provider and verified sender; use port `587`, `SMTP_STARTTLS=true`, `SMTP_USE_SSL=false`, or port `465`, `SMTP_STARTTLS=false`, `SMTP_USE_SSL=true` |
| `CORS_ALLOWED_ORIGINS` | The exact HTTPS origin of the deployed web app, without a path; add additional origins comma-separated |
| `CORS_ALLOWED_ORIGIN_REGEX` | Keep the local-only default or set to an empty string in production |
| `SEED_DEMO_HOST` | `false` |

Set the following only when enabling the corresponding integration:

| Variable | Purpose |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Enable Supabase Google sign-in |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side account deletion and private media storage; never expose this key to clients |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Google Forms integration OAuth credentials |
| `GOOGLE_REDIRECT_URI` | `https://ginata-backend.onrender.com/api/v1/integrations/google/callback` |
| `GOOGLE_TOKEN_ENCRYPTION_KEY` | Secret 32-byte URL-safe base64 key used to encrypt stored Google refresh tokens |
| `GOOGLE_OAUTH_STATE_SECRET` | Secret with at least 32 random bytes for OAuth state signing |
| `GOOGLE_FORMS_POLL_SECONDS` | Poll interval in seconds; `60` is the default, `0` disables background polling |
| `ADMIN_API_KEY` | Optional secret for the protected subscription administration endpoint |

Generate the two Google Forms secrets locally in PowerShell, then paste each
result directly into Render. Do not commit or share the generated values:

```powershell
py -3 -c "import base64,secrets; print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode())"
py -3 -c "import secrets; print(secrets.token_urlsafe(48))"
```

If configuring Google sign-in through Supabase, enable the Google provider in
Supabase Auth and add the exact production redirect URLs to Supabase's redirect
allow list and the backend's `AUTH_REDIRECT_URLS`. Google Forms integration uses
the separate Google OAuth client and callback URL listed above.

After setting environment variables, save them and deploy/restart the service.
Watch the Render deployment and startup logs for database or SMTP errors. Do not
switch real users to email verification until the SMTP sender can deliver mail.

## 3. Verify the backend deployment

Wait for the Render deployment to finish, then open:

```text
https://ginata-backend.onrender.com/
https://ginata-backend.onrender.com/openapi.json
```

The root endpoint must return HTTP 200. In the OpenAPI paths, confirm that these
release routes are present before installing the updated clients:

- `/api/v1/auth/config`
- `/api/v1/auth/password/forgot` and `/api/v1/auth/password/reset`
- `/api/v1/auth/account/delete`
- `/api/v1/subscription`
- `/api/v1/tasks` and `/api/v1/tasks/today`
- `/api/v1/guests`
- `/api/v1/properties/external-blocks`
- `/api/v1/media/{key}`
- `/api/v1/reservations/{reservation_id}/check-in`
- `/api/v1/reservations/{reservation_id}/check-out`

If a route is missing, the running service has not deployed the release commit.
Review the Render deploy log and branch/commit selection before testing the app.

Create a new test account and verify the full confirmation email flow before
relying on production sign-in. Test property creation, booking/check-in/check-out,
guest records, expenses, and document uploads using test data first.

## 4. Build and publish the web app

Use the Flutter SDK from the repository's `frontend` directory:

```powershell
cd frontend
flutter pub get
flutter build web --release --dart-define=API_URL=https://ginata-backend.onrender.com/api/v1
```

The static website is generated in `frontend/build/web/`. Deploy the contents of
that folder to the configured Vercel/Netlify static site or another HTTPS static
host. Add the final site origin (for example `https://your-site.example`) to
Render's `CORS_ALLOWED_ORIGINS`, then restart the backend. Do not include a
trailing slash or page path in the origin. If the site has a preview domain, add
that origin too while testing.

For a quick local browser check, serve `frontend/build/web/` over HTTP rather
than opening `index.html` directly:

```powershell
cd frontend/build/web
py -3 -m http.server 8080
```

Open `http://localhost:8080`, sign in, and confirm the browser console has no
CORS or failed API errors. Stop the local server with Ctrl+C.

## 5. Install and test the Android APK

Build the release APK from `frontend`:

```powershell
cd frontend
flutter build apk --release --dart-define=API_URL=https://ginata-backend.onrender.com/api/v1
```

The APK is written to:

```text
frontend/build/app/outputs/flutter-apk/app-release.apk
```

Copy it to the Android device, open it, and approve installation if Android asks
to allow installs from that file-sharing app. Alternatively, with USB debugging
enabled and Android Platform Tools installed:

```powershell
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The release is version `1.0.1` (version code `2`) so it can update the previous
`1.0.0` installation. Sign in with a test host, verify email confirmation, then
exercise the same booking, guest, operations, finance, and document flows as the
web app. A store release requires the private upload keystore and a Play App
Bundle; the APK is for direct installation/testing.

## 6. Release checks

- Flutter tests: `flutter test` from `frontend`.
- Flutter analyzer: `flutter analyze` from `frontend`.
- Isolated backend tests (from repository root):

  ```powershell
  py -3 -m pytest backend\tests\test_auth.py backend\tests\test_google_oauth.py backend\tests\test_google_forms_sync.py backend\tests\test_platform.py -q
  ```

- Do not run `backend/tests/test_all.py` against a live or valuable database; its
  fixture resets the configured database. Use a disposable test database for
  that legacy suite.
- Keep database backups, SMTP credentials, Supabase service-role keys, Google
  client secrets, OAuth encryption keys, and Android signing material private.
