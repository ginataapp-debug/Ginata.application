# Ginata pre-launch audit

**Audit date:** 2026-11-12
**Release commit:** `c5a087d58ed7c3d8ed25a35a217e7fca49f11029`
**Scope:** Read-only production checks plus isolated local tests. No production records were created, changed, or deleted.

## Executive result

The committed backend is live and reports healthy, and its OpenAPI document contains the release routes. The Flutter tests and both isolated backend suites pass. The local web release renders the branded sign-in page at desktop and phone widths.

This is **not a complete live end-to-end sign-off**. The release APK was installed on an authorized Android phone and its existing signed-in session opened the live dashboard, but full workflows were not exercised. There is no confirmed public web host and no direct read-only view of the production Supabase database or Render environment. Production Google sign-in reports disabled. Verify the items in [Launch blockers and next steps](#launch-blockers-and-next-steps) before announcing the web or APK as live.

## Results by area

| Area | Status | Evidence and limits |
|---|---|---|
| Authentication, password, branding and settings | PARTIAL | The isolated auth/platform tests cover signup, hashed sessions, email-code confirmation/recovery, password change, logout/revocation, and Google sign-in code paths. Flutter widget tests cover reset/change-password requests and brand settings load/save/error behavior. Live login, SMTP delivery, and authenticated settings were not exercised. |
| Properties | PARTIAL | Local API tests cover property creation, subscription limits, and tenant boundaries. Production property records were not read or changed. |
| Bookings and calendar operations | PARTIAL | The 18-test isolated backend integration suite covers manual booking, overlap conflicts, checkout, guest-form flows, and related behavior. No production booking was created or modified. |
| Guests and guest check-in | PARTIAL | Local tests cover guest form processing, matching, retries, review states, and tenant ownership. No production guest records or live guest submission were used. |
| Finance and payments | PARTIAL | Isolated integration tests cover invoice calculations, payments/receipts, expenses, and financial summaries. Live balances, exports, and payment-provider behavior were not tested. |
| iCal calendar sync | PARTIAL | Local tests cover invalid/SSRF calendar inputs and calendar behavior. No real Airbnb/Booking.com feed was connected or synchronized during this audit. |
| Google integrations | PARTIAL | OAuth and Forms flows pass isolated tests with mocked Google responses. Production `/api/v1/auth/config` returns `google_sign_in_enabled: false`; Google sign-in is unavailable in the observed live configuration. The Forms poller is running, but live Google credentials/forms were not tested. |
| Notifications | PARTIAL | Local tests cover notification creation, deduplication, and read flows. Production root status reports the poller healthy, but no live notification was generated or inspected. |
| Inventory, invoices and documents | PARTIAL | Invoice/document generation and theming pass isolated tests. Inventory API and Flutter property-screen entry points exist, and inventory routes are present in production OpenAPI, but there is no dedicated inventory test in the exercised suites and no live item was created. |
| Subscription and plan limits | PARTIAL | Local tests cover trial expiry, property limits, and feature gates. Production subscription records and entitlement behavior were not tested. |
| Tenant isolation | PARTIAL | Isolated API tests cover cross-tenant property access, shared organizations, and host scoping. Production cross-tenant behavior was not tested against real accounts. |
| Supabase, RLS, storage and migrations | PARTIAL | The additive migration/idempotence test passes. Source enables RLS and revokes direct `anon`/`authenticated` table grants for tables owned by the connecting role; this is source behavior, not confirmation of the live database’s owner, grants, or schema. Upload tests use isolated/local storage, not the live Supabase bucket. |
| Backend and Render | PASS (health/routes) | `https://ginata-backend.onrender.com/`, `/docs`, and `/openapi.json` returned HTTP 200. The root reports operational; the worker reported running and a successful cycle. OpenAPI lists 96 paths, including the release password, property, reservation, guest, task, subscription, finance, Google, and inventory routes. The live service does not expose its deployed commit SHA, so exact binary-to-commit identity was not independently verified. |
| Installed Android APK | PARTIAL | Version 1.0.1+3 installed successfully on the authorized Android phone, launched into its existing signed-in session, and displayed the live dashboard; the visible layout fit the phone screen. No records or settings were changed, and authenticated workflows were not exercised. APK SHA-256: `2D9A490F7308ED34FFAC1C69140F0800F07E111FC4FFB63B80F9CD1CE742BDF2`. |
| Web, desktop and mobile | PARTIAL | The built Flutter web artifact is available on this computer at `http://127.0.0.1:8766/`; no public domain is needed for local browser testing. It rendered the Ginata sign-in screen, and at 390 px width the document had no horizontal overflow. This checks the unauthenticated local build, not authenticated workflows or the actual production site. The documented `ginata-estates.vercel.app` URL returns 404; `ginata.co.ke` and `www.ginata.co.ke` did not resolve. A CORS preflight from the documented Vercel origin returned HTTP 400 without an allow-origin header. |

## Test evidence

- Flutter: `flutter test` — **14 passed**.
- Flutter static analysis: `flutter analyze` — **no issues found**.
- Backend auth/platform/Google OAuth/Google Forms suites — **42 passed**.
- Backend integration suite (`test_all.py`) — **18 passed**, run with a disposable SQLite database and temporary document/upload directories. It was not run against the configured/default application database.
- APK artifact metadata and checksum were checked. No APK installation was attempted because no device was available.
- The production checks were limited to public health, documentation/OpenAPI, capability/config responses, and the known web hostnames. No production write endpoints were invoked.
- The release APK was installed and launched on the attached phone. An existing session displayed the live dashboard; testing stopped at this read-only visual smoke check.

## Security and operations notes

- A scan of tracked source for common credential/private-key patterns found no matches. This does not inspect Render or Supabase environment variables.
- Passwords use salted PBKDF2-SHA256; session tokens are stored as hashes, as verified by isolated tests.
- Production Google sign-in is explicitly disabled according to the public auth configuration endpoint.
- The Forms worker runs inside each FastAPI process. The live root confirms a running worker in the responding process, but Render replica count is not exposed here. Before scaling beyond one instance, verify that only one poller runs or add a shared distributed lock. Google response processing is idempotent/concurrency-aware; calendar polling has no visible cross-process leader lock.
- PostgreSQL RLS/grants and storage access must be checked against the actual Supabase project. The committed SQL schema alone is not evidence that production migrations or permissions were applied.

## Launch blockers and next steps

1. **Confirm the production web URL.** The documented Vercel URL currently returns 404 and the two `ginata.co.ke` names do not resolve from this environment. Deploy the Flutter web build to the intended host and verify its root page returns 200.
2. **Configure and verify web CORS.** Add only the real HTTPS web origin to Render's `CORS_ALLOWED_ORIGINS`, redeploy, then confirm a browser preflight succeeds. The documented Vercel origin currently fails preflight.
3. **Decide whether Google sign-in is required.** If yes, configure the Supabase provider and redirect URLs, redeploy, and verify `/api/v1/auth/config` reports it enabled. Separately verify Google OAuth credentials and a real Forms connection if those features are part of launch.
4. **Verify production email and password recovery** using a dedicated test account and a mailbox you control. Confirm SMTP delivery, one-time code expiry, reset, and login with the new password. Do not put credentials in this document or source control.
5. **Verify Supabase without modifying customer data.** Confirm the production schema/migrations, table owner, RLS state, `anon`/`authenticated` grants, and private storage bucket configuration. Take a database backup before applying schema changes; follow [SUPABASE_PRODUCTION_SETUP.md](./SUPABASE_PRODUCTION_SETUP.md).
6. **Install the APK on a real Android device or emulator.** Check login, password recovery, branding/settings, property and booking views, and logout. Confirm the installed version is 1.0.1+3.
7. **Run an authenticated web smoke test** on both desktop and a phone-sized viewport against the confirmed production host. Validate settings save/reload, password change, properties, bookings, finance, notifications, and Google features that are enabled.
8. **Confirm Render worker topology.** Keep one instance while using the in-process poller, or ensure a distributed lock prevents duplicate Forms/iCal polling before increasing replicas.

The operational setup and deployment steps are in [LAUNCH_GUIDE.md](./LAUNCH_GUIDE.md). This audit did not change application code, deploy a new release, or alter production data.
