# Ginata Property Management — Production Deployment Guide
## Supabase PostgreSQL, FastAPI Backend, and Flutter Clients

> **Cost:** Depends on provider plans, usage, storage, backups, and SMTP delivery. Free tiers may have quotas or expire.
> **Hosting:** Managed PostgreSQL, a Python web service, and a static Flutter web app.
> Verify current provider limits and backup arrangements before production use.

---

## 🏗️ 1. Architecture Overview

```mermaid
graph TD
    Client1[Mobile Android App / APK] -->|HTTPS| Backend[FastAPI on Render / Koyeb Free]
    Client2[Web App on Vercel / Netlify Free] -->|HTTPS| Backend
    Backend -->|PostgreSQL Connection Pool| SupabaseDB[(Supabase Free PostgreSQL)]
    Backend -->|Public S3 URL| SupabaseStorage[(Supabase Storage: Images & PDFs)]
```

| Component | Free Provider | What It Provides | Free Tier Limit |
|---|---|---|---|
| **Database** | **Supabase** (PostgreSQL) | Full relational database with pgvector, auto-backups, and table editor | 500 MB database, 2 projects |
| **Media & Images** | **Supabase Storage** | Public & private buckets for cover photos, guest IDs, and receipts | 1 GB file storage, 2 GB bandwidth |
| **Backend API** | **Render.com** or **Koyeb** | Python/FastAPI web service with free `https://*.onrender.com` domain | 750 free hours/month (always on) |
| **Frontend Web** | **Vercel** or **Netlify** | Flutter Web client hosted on global CDN with free `https://*.vercel.app` | 100 GB bandwidth/month |
| **Mobile App** | **Direct APK** | Android standalone app installed directly on any smartphone or tablet | Unlimited |

---

## ⚡ 2. Step-by-Step Supabase Setup (10 Minutes)

### Step 2.1: Create Your Free Supabase Project
1. Go to [supabase.com](https://supabase.com) and click **Start your project** (sign in with GitHub).
2. Click **New project**:
   - **Name:** `Ginata Estates`
   - **Database Password:** *Choose a strong password (save this!)*
   - **Region:** Choose `Frankfurt (EU)` or `Johannesburg (Africa)` for lowest latency to Kenya.
   - **Pricing Plan:** Free ($0/month).
3. Click **Create new project** and wait ~2 minutes for provisioning.

### Step 2.2: Retrieve Database Connection String
1. In your Supabase dashboard, click the **Settings (gear icon)** at the bottom of the left sidebar.
2. Select **Database**.
3. Under **Connection string**, click the **URI** tab.
4. Select **Transaction pooler (Mode: Transaction, Port: 6543)** or **Session pooler (Port: 5432)**:
   ```text
   postgresql://postgres.[YOUR-PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
   ```
5. Replace `[YOUR-PASSWORD]` with the password you set in Step 2.1.

### Step 2.3: Create Storage Bucket for Property Cover Photos
1. In the Supabase left sidebar, click **Storage**.
2. Click **New bucket**:
   - **Name:** `property-images`
   - **Public bucket:** **Toggle ON** (so guests and host can view cover images without signed URLs).
3. Click **Save bucket**.
4. Repeat to create a second bucket: `guest-documents` (**Public bucket: Toggle OFF** for secure passport/ID storage).

---

## 🚀 3. Step-by-Step Free Backend Deployment on Render.com (10 Minutes)

Render provides a completely free containerized hosting environment with automated HTTPS:

### Step 3.1: Push Your Code to GitHub
1. Create a repository on GitHub (e.g. `ginata-property-management`).
2. Push your project:
   ```bash
   git init
   git add .
   git commit -m "Production release"
   git branch -M main
   git remote add origin https://github.com/[YOUR-USERNAME]/ginata-property-management.git
   git push -u origin main
   ```

### Step 3.2: Create a Free Web Service on Render
1. Go to [render.com](https://render.com) and click **Get Started for Free** (Sign in with GitHub).
2. In the dashboard, click **New +** → **Web Service**.
3. Connect your GitHub repository `ginata-property-management`.
4. Configure the service settings:
   - **Name:** `ginata-api`
   - **Region:** Frankfurt (closest to Kenya)
   - **Branch:** `main`
   - **Runtime:** `Python 3`
   - **Build Command:**
     ```bash
     pip install -r requirements.txt
     ```
   - **Start Command:**
     ```bash
     python -m uvicorn backend.app.main:app --host 0.0.0.0 --port $PORT
     ```
   - **Instance Type:** **Free** ($0/month).

### Step 3.3: Set Environment Variables on Render
Under **Environment Variables**, add:
| Key | Value | Purpose |
|---|---|---|
| `DATABASE_URL` | `postgresql://postgres.[REF]:[PASS]@[HOST]:6543/postgres` | Connects to your Supabase PostgreSQL |
| `PYTHONUNBUFFERED` | `1` | Real-time console logs |

Click **Create Web Service**. Within 3 minutes, Render will build and deploy your backend at:
`https://ginata-backend.onrender.com`

---

## 🌐 4. Step-by-Step Free Frontend Web Deployment on Vercel (5 Minutes)

### Step 4.1: Build Flutter Web for Production
In your terminal, navigate to the `frontend` folder and build with your live Render backend URL:
```bash
flutter build web --release --dart-define=API_URL=https://ginata-backend.onrender.com/api/v1
```
This compiles your entire Flutter application into pure HTML, CSS, JavaScript, and WebAssembly in `frontend/build/web/`.

### Step 4.2: Deploy to Vercel (Free)
1. Install Vercel CLI (or connect GitHub repository on [vercel.com](https://vercel.com)):
   ```bash
   npm install -g vercel
   ```
2. Deploy the `build/web` folder directly:
   ```bash
   cd frontend/build/web
   vercel --prod
   ```
3. Vercel automatically deploys it across 100+ global edge locations with an instant HTTPS URL:
   `https://ginata-estates.vercel.app`

---

## 📱 5. Mobile App (APK) Installation on Any Phone

You do not need to pay $25 to Google Play Console or wait for approval to use the app on mobile:

1. Build the Android package with the same live API URL:
   ```bash
   flutter build apk --release --dart-define=API_URL=https://ginata-backend.onrender.com/api/v1
   ```
2. The generated APK will be at:
   `frontend/build/app/outputs/flutter-apk/app-release.apk`
3. Send this file to your phone via WhatsApp, Google Drive, or USB cable.
4. Tap the file on your Android phone and click **Install**.
5. The release manifest includes `android.permission.INTERNET`; debug/profile manifests alone are not enough for a release APK.

### Google Play / store signing

The project supports an upload key through `frontend/android/key.properties`.
Without that file, release builds fall back to the debug key and are only for
internal testing, not store publication.

1. Create a private upload keystore (keep it backed up; losing it prevents future updates):
   ```bash
   keytool -genkey -v -keystore frontend/android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `frontend/android/key.properties` (already gitignored):
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
3. Build the store package:
   ```bash
   flutter build appbundle --release --dart-define=API_URL=https://ginata-backend.onrender.com/api/v1
   ```
4. Upload `frontend/build/app/outputs/bundle/release/app-release.aab` to Google Play.

---

## 6. Host Accounts, Email Confirmation, and Secure Sign-In

**Supabase Auth is not used by this implementation.** The FastAPI backend owns
accounts, password verification, email confirmation, and sessions in Supabase
PostgreSQL. Enabling Supabase Auth or editing its email templates does not configure
Ginata confirmation emails: configure the backend SMTP environment below instead.
No browser or mobile app should receive your database password or service-role key.

### Account and cross-device behavior
- Signup creates a private organization and an **unverified** `host_users` row.
  Passwords require at least **10 characters**, are never trimmed, and use salted,
  versioned PBKDF2-HMAC-SHA256 with **600,000 iterations**. Existing unversioned
  100,000-iteration hashes are accepted and upgraded after successful password verification.
- Set `REQUIRE_EMAIL_VERIFICATION=true` in production. Signup sends a six-digit
  email code and returns `verification_required=true` with **no token**. The app
  opens a code dialog. Unverified accounts cannot log in or use protected endpoints.
- `POST /api/v1/auth/verification/send` accepts email and password to send/resend a
  code. `POST /api/v1/auth/verification/verify` accepts email and code. Codes are
  stored only as slow salted hashes in `host_email_verifications`, expire, have a
  limited attempt count, and are single-use. Resends invalidate older codes and
  are rate-limited. Correct verification marks the email verified and issues a session.
- If verification is required but SMTP is absent or delivery fails, signup returns
  a clear **503** error, not a false "sent" or "verified" success.
- Each signup (when allowed), confirmed email, or login creates an independent
  `host_sessions` row: only the **SHA256 hash** of a random bearer token is stored,
  together with its expiry. Logging in on another phone does **not** log out your
  first device. Logout revokes only the presented device session.
- Every protected request derives the organization from the authenticated active
  host, not from a client-supplied organization header. Expired tokens and legacy
  `host_users.session_token` values are ignored. Legacy raw tokens are cleared on login.
- Flutter uses `flutter_secure_storage` for bearer tokens, not ordinary
  SharedPreferences. Old plaintext tokens are **deleted, not migrated**, so users
  must sign in once after updating. Passwords are not persisted.
- Successful sign-in shows the actual host and verification status. Online session
  validation is required; connection failures cannot create a fallback login.
- Saved host names, email addresses, phone numbers, and offline guest/business
  records use the secure-storage plugin too. Signing out or switching organizations
  clears the previous host's cache. Legacy plaintext caches are discarded on upgrade.
  Browser storage has the web limitations noted below; protect device access.
- Property and booking saves, payments, expenses, invoices, receipts, and document
  design changes require server confirmation; an offline or rejected request does
  not fabricate a successful save. Cached records remain available for reading.
- Changing the profile email resets verification, invalidates outstanding codes,
  and, when verification is required, revokes all sessions. Sign in with the new
  email and existing password, then use the confirmation dialog to send a code.

### Backend environment on Render / Koyeb

| Key | Production value / default | Purpose |
|---|---|---|
| `DATABASE_URL` | `postgresql+psycopg://postgres.[REF]:[URL-ENCODED-PASSWORD]@[POOLER-HOST]:5432/postgres?sslmode=require` | Copy the **session pooler** URI from Supabase; keep it server-only. |
| `REQUIRE_EMAIL_VERIFICATION` | `true` (local default: `false`) | Enforce real confirmation before access. Local signup still reports the email unverified. |
| `AUTH_SESSION_TTL_HOURS` | `168` | Session lifetime (7 days by default); configure 1–8760 hours. |
| `EMAIL_OTP_TTL_MINUTES` | `10` | Confirmation-code lifetime; configure 1–60 minutes. |
| `EMAIL_OTP_MAX_ATTEMPTS` | `5` | Attempts per code; configure 1–10. |
| `EMAIL_OTP_RESEND_SECONDS` | `60` | Minimum interval between sends per account. |
| `SMTP_HOST` | Your provider's SMTP hostname | Required to send confirmation emails. |
| `SMTP_PORT` | `587` for STARTTLS, or `465` for SSL | Provider's SMTP port. |
| `SMTP_USERNAME` | Your provider's username | SMTP authentication, if required by the provider. |
| `SMTP_PASSWORD` | Your SMTP credential / app password | Store as a backend secret, never in Flutter or git. |
| `SMTP_FROM_EMAIL` | A sender verified with your provider | Required sender address. Configure provider SPF/DKIM as appropriate. |
| `SMTP_STARTTLS` | `true` | Required when not using SSL. Plaintext SMTP is refused. |
| `SMTP_USE_SSL` | `false` for port 587; `true` for port 465 | TLS from connection start on port 465. |
| `SEED_DEMO_HOST` | `false` | Keep disabled in production. Explicit `true` is for isolated local demos/tests only. |
| `CORS_ALLOWED_ORIGINS` | `https://ginata-estates.vercel.app` | Comma-separated exact frontend origins, no paths or wildcard. Add every production web origin here. |
| `CORS_ALLOWED_ORIGIN_REGEX` | `^https?://(localhost|127\.0\.0\.1)(:\d+)?$` | Allows local Flutter web on any loopback port. Set to an empty string to disable, or tighten for production. |

Restart the backend after environment changes. All devices must use the same API:

```bash
flutter build web --release --dart-define=API_URL=https://ginata-backend.onrender.com/api/v1
flutter build apk --release --dart-define=API_URL=https://ginata-backend.onrender.com/api/v1
```

The API defaults to `https://ginata-backend.onrender.com/api/v1` if `API_URL` is not
set. Both AuthService and ApiService share this setting. Local Flutter web is
allowed on loopback ports by the default CORS regex; production web origins must
still be listed explicitly in `CORS_ALLOWED_ORIGINS`.

### Supabase database setup and upgrade precautions
1. Back up any existing database. Set the backend connection URI, deploy this code,
   and restart. Startup creates missing `host_users`, `host_sessions`, and
   `host_email_verifications` tables plus the application's other missing tables.
   **`create_all` does not migrate existing columns or constraints**: reconcile
   an older hand-created schema before production use; do not drop existing tables.
2. Authentication tables must not be directly readable through Supabase's public
   Data API. In Supabase SQL Editor, after the tables exist, an authorized admin
   can apply the following protection (the backend connection role must retain
   the required privileges and be able to bypass RLS; do not grant client policies):

   ```sql
   ALTER TABLE public.host_users ENABLE ROW LEVEL SECURITY;
   ALTER TABLE public.host_sessions ENABLE ROW LEVEL SECURITY;
   ALTER TABLE public.host_email_verifications ENABLE ROW LEVEL SECURITY;
   REVOKE ALL ON TABLE public.host_users, public.host_sessions,
     public.host_email_verifications FROM anon, authenticated;
   ```

   Review protection of every other private tenant table too. Backend tenant
   isolation does not protect a table exposed separately through the Data API.
3. Previously published demo credentials `host@ginata.ke` / `host123456` are no
   longer seeded by default. **An existing demo account is not automatically
   changed or deleted. An authorized administrator must deactivate it in production.**
   Review accounts marked verified by older signup code: those flags are not proof
   of email ownership. Plan an authorized re-verification rollout; this update does
   not silently reset existing users or modify hosted data.
4. Optionally configure Storage separately. Creating buckets alone does not wire
   backend uploads into Supabase Storage. Keep guest identification documents private.
5. Run auth tests in isolation:
   `python -m pytest backend/tests/test_auth.py -q`. They use temporary SQLite and
   mocked SMTP. **Do not run `test_all.py` against your production/default database**;
   its fixture drops tables. Full-suite testing requires a dedicated disposable DB
   and explicit `SEED_DEMO_HOST=true` if those tests rely on the demo host.

### Secure-storage platform notes
`flutter_secure_storage` 11.2 supports the existing Windows file-picker dependency
without a win32 version conflict. Android requires API 23+; review Android backup
exclusions for secure storage before shipping. iOS/macOS require the plugin's
Keychain entitlements; Linux needs libsecret and a running secret service. Those
native platform settings are not changed by this auth patch. Test storage on each
target device. Web requires HTTPS (or localhost) and uses browser encryption, not
a hardware vault; it cannot prevent same-origin XSS, so use CSP and trusted scripts.
Browser keys are device/browser-specific: sign in independently on each device.

No real confirmation email or hosted database change is performed by the tests or
this setup document. SMTP provider quotas/pricing are separate from Supabase, and
free hosting/database tiers and backup guarantees should be checked before launch.

---

## 🔒 7. Zero-Maintenance Checklist

- [x] **No VM to patch or maintain:** Supabase and Render manage all OS updates, firewall rules, and uptime automatically.
- [x] **No domain renewal fees:** Render provides `*.onrender.com` with free SSL, and Vercel provides `*.vercel.app` with free SSL.
- [ ] **Backups:** Confirm your plan's backup coverage and test a restore before relying on it.
- [ ] **Tax configuration:** Verify applicable taxes and registration requirements; a default zero tax rate is not a compliance guarantee.
- [x] **Live iCal Feeds:** Your Airbnb and Booking.com iCal links sync automatically with `https://ginata-backend.onrender.com/api/v1/properties/{id}/feed.ics`.
