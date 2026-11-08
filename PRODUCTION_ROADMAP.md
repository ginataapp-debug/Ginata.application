# Ginata Property Management — Production Roadmap

> **Last Updated:** October 19, 2026  
> **Current Status:** MVP Feature-Complete (Development Mode)  
> **Target:** Production-Ready Deployment

---

## Overview

This document describes **everything remaining** to make Ginata a fully production-ready, deployed property management system. Items are organized by priority and domain.

---

## 🔴 CRITICAL — Must Fix Before Go-Live

### 1. Backend: Authentication & Authorization
**Current State:** No auth — API is completely open.  
**What to do:**
1. Add **JWT-based authentication** using `python-jose` and `passlib`.
2. Create a `User` model with fields: `email`, `hashed_password`, `role` (owner/manager/staff), `organization_id`.
3. Add `/auth/register`, `/auth/login`, `/auth/refresh` endpoints.
4. Protect all API routes with `Depends(get_current_user)`.
5. Implement **role-based access control (RBAC)**:
   - `owner`: full access
   - `manager`: can manage properties, bookings, expenses, messages
   - `staff`: can view bookings, forms, mark turnovers
6. **Files to modify:** `backend/app/models/models.py`, `backend/app/main.py`, create `backend/app/auth.py`, create `backend/app/api/v1/auth.py`.

### 2. Backend: Switch to PostgreSQL
**Current State:** SQLite (single-file, no concurrent writes).  
**What to do:**
1. Install `asyncpg` and `databases` packages.
2. Change `DATABASE_URL` in `backend/app/models/models.py` to a PostgreSQL connection string.
3. Set up a managed PostgreSQL instance (Supabase, Railway, Neon, or AWS RDS).
4. Run Alembic migrations: `alembic init alembic`, `alembic revision --autogenerate`, `alembic upgrade head`.
5. **Files to modify:** `backend/app/models/models.py`, add `alembic.ini`, create `alembic/` migration directory.

### 3. Frontend: Login & Session Management
**Current State:** No login screen, no session tokens.  
**What to do:**
1. Create `frontend/lib/screens/login_screen.dart` with email/password form.
2. Store JWT in `SharedPreferences` or `flutter_secure_storage`.
3. Add `Authorization: Bearer <token>` header to all API calls in `api_service.dart`.
4. Add logout functionality and session expiry handling.
5. Guard all navigation behind auth check in `main.dart`.

### 4. Environment Configuration
**Current State:** Hardcoded `http://127.0.0.1:8000` base URL.  
**What to do:**
1. Create `.env` file with `API_BASE_URL`, `DATABASE_URL`, `JWT_SECRET`, `CORS_ORIGINS`.
2. Use `python-dotenv` in backend and `flutter_dotenv` in frontend.
3. Set up separate configs for dev, staging, and production.
4. **Files to modify:** `backend/app/main.py`, `frontend/lib/services/api_service.dart`.

---

## 🟠 HIGH PRIORITY — Needed for Real Usage

### 5. Backend: Real iCal Calendar Sync
**Current State:** Import endpoint exists but needs real HTTP fetching of external .ics feeds.  
**What to do:**
1. Install `httpx` for async HTTP requests and `icalendar` for parsing.
2. In `backend/app/api/v1/properties.py` `sync_channels` endpoint:
   - Fetch the Airbnb/Booking.com iCal URLs via HTTP GET.
   - Parse the `.ics` file to extract `VEVENT` entries (DTSTART, DTEND, SUMMARY).
   - Create `Reservation` records with `source: 'airbnb'` or `source: 'booking.com'` for each blocked date range.
   - Skip duplicates (match on property_id + dates + source).
3. Set up a **background scheduler** (APScheduler or Celery Beat) to auto-sync every 15 minutes.
4. **Files to modify:** `backend/app/api/v1/properties.py`, add `backend/app/tasks/sync_ical.py`.

### 6. Backend: Real Messaging Integration
**Current State:** Messages are stored locally but not sent to external channels.  
**What to do:**
1. **WhatsApp:** Integrate the WhatsApp Business API (Meta Cloud API) or Twilio WhatsApp.
   - When host sends a message marked as "whatsapp", POST to the WhatsApp API to deliver it.
   - Set up a webhook endpoint to receive incoming WhatsApp messages and store them.
2. **SMS:** Integrate Africa's Talking SMS API (best for Kenya) or Twilio.
3. **Airbnb/Booking.com:** These platforms don't offer real-time messaging APIs for property managers. Messages will remain manual (copy-paste).
4. **Files to create:** `backend/app/integrations/whatsapp.py`, `backend/app/integrations/sms.py`.

### 7. Frontend: Image Upload (Not Just URL)
**Current State:** Cover images are entered as URLs only.  
**What to do:**
1. Add file upload endpoint: `POST /api/v1/uploads/image` that accepts `multipart/form-data`.
2. Store images in cloud storage (AWS S3, Google Cloud Storage, or Cloudflare R2).
3. In the property dialog, add a "Choose File" button alongside the URL input.
4. Use `image_picker` or `file_picker` Flutter packages for file selection.
5. Display the uploaded image URL in the property form automatically.
6. **Files to create:** `backend/app/api/v1/uploads.py`, modify `frontend/lib/screens/properties_screen.dart`.

### 8. Data Validation & Error Handling
**What to do:**
1. Add comprehensive Pydantic validation on all schemas (email format, phone format, date ranges, positive amounts).
2. Add `try/catch` with user-friendly error messages on all frontend API calls.
3. Add request rate limiting (using `slowapi` or `fastapi-limiter`).
4. Add CORS configuration for production domains only.

---

## 🟡 MEDIUM PRIORITY — Polish & Completeness

### 9. Financial Reports & Export
**What to do:**
1. Add date-range filtering to the financial summary endpoint (start_date, end_date query params).
2. Add CSV/Excel export of expenses: `GET /finances/expenses/export?format=csv`.
3. Add monthly P&L report generation as PDF.
4. Add per-property monthly income vs. expense charts using `fl_chart` in Flutter.
5. **Files to modify:** `backend/app/api/v1/finances.py`, create `frontend/lib/widgets/financial_charts.dart`.

### 10. Guest Form Improvements
**What to do:**
1. Add passport/ID photo upload field.
2. Add digital signature capture (for check-in agreements).
3. Add automatic form-to-reservation matching based on guest name + dates.
4. Add email notification to host when a form is submitted.
5. **Files to modify:** `frontend/lib/screens/guest_forms_screen.dart`, `backend/app/api/v1/guest_forms.py`.

### 11. Calendar Improvements
**What to do:**
1. Add drag-to-extend reservation dates on the calendar.
2. Add blocked-date/maintenance-window creation by clicking on the calendar.
3. Color-code by booking source (Airbnb red, Booking.com blue, Direct green).
4. Add week and day views alongside the current month view.
5. **Files to modify:** `frontend/lib/screens/unified_calendar_screen.dart`.

### 12. Notification System
**What to do:**
1. Add push notifications for:
   - New booking created
   - Payment received
   - Guest form submitted
   - Calendar conflict detected
   - Channel sync completed
2. Use Firebase Cloud Messaging (FCM) for mobile and web push.
3. Add email notifications via SendGrid or Mailgun.
4. **Files to create:** `backend/app/services/notification_service.py`, `backend/app/integrations/email.py`.

### 13. Multi-Property Owner & Manager Access
**What to do:**
1. Support multiple organization/host accounts.
2. Add team management: invite co-hosts, managers, and cleaning staff.
3. Each team member gets role-based access (see item #1).
4. Add an organization settings page for team management.

---

## 🟢 LOW PRIORITY — Nice to Have

### 14. Mobile App (iOS & Android)
**Current State:** Flutter web only.  
**What to do:**
1. The codebase is already Flutter — generate iOS and Android builds.
2. Test responsive layouts on real devices.
3. Add platform-specific permissions (camera for photo uploads, contacts for guest lookup).
4. Submit to Apple App Store and Google Play Store.

### 15. Analytics Dashboard
**What to do:**
1. Add occupancy rate calculation: (booked nights / total nights) × 100.
2. Add revenue-per-available-room (RevPAR) metric.
3. Add average daily rate (ADR) tracking.
4. Add historical trends with line charts (monthly revenue, occupancy, expenses).
5. Add agent performance leaderboard (who brings the most bookings, highest commission volume).

### 16. Cleaning & Turnover Management
**What to do:**
1. Create a `Turnover` model: property_id, check_out_reservation, check_in_reservation, cleaner_assigned, status, notes.
2. Auto-generate turnover tasks when back-to-back bookings are detected.
3. Assign cleaners and track completion.
4. Send cleaner notifications via WhatsApp or SMS.

### 17. Guest Reviews & Feedback
**What to do:**
1. After check-out, automatically send a feedback form link.
2. Collect ratings (1-5 stars) and written reviews.
3. Display average property rating on cards.

### 18. Automated Pricing
**What to do:**
1. Add seasonal pricing rules (high season, low season).
2. Add weekend vs. weekday rate differentiation.
3. Add minimum stay requirements.
4. Add early booking discounts and last-minute deals.

---

## 🛠 Deployment Steps

### Step 1: Set Up Production Server
1. Choose a cloud provider: **Railway**, **Render**, **DigitalOcean**, or **AWS**.
2. Set up a PostgreSQL database.
3. Deploy the FastAPI backend with Gunicorn + Uvicorn workers.
4. Set environment variables: `DATABASE_URL`, `JWT_SECRET`, `CORS_ORIGINS`, `API_BASE_URL`.

### Step 2: Build & Deploy Frontend
1. Run `flutter build web --release` to generate optimized web assets.
2. Deploy the `build/web/` folder to **Vercel**, **Netlify**, or serve from the same server as the API.
3. Set the production `API_BASE_URL` (e.g., `https://api.ginata.co.ke`).

### Step 3: Domain & SSL
1. Purchase domain: `ginata.co.ke` or `ginata.app`.
2. Set up SSL certificate (automatic with Cloudflare or Let's Encrypt).
3. Configure DNS: `app.ginata.co.ke` → frontend, `api.ginata.co.ke` → backend.

### Step 4: Monitoring & Logging
1. Set up Sentry for error tracking (both frontend and backend).
2. Set up uptime monitoring (UptimeRobot or Better Stack).
3. Set up structured logging with JSON format for production logs.

### Step 5: Backup & Recovery
1. Set up automated daily PostgreSQL backups.
2. Store backups in a separate cloud storage bucket.
3. Test restore procedure.

---

## Summary Checklist

| # | Item | Priority | Effort |
|---|------|----------|--------|
| 1 | Authentication & Authorization | 🔴 Critical | 2-3 days |
| 2 | PostgreSQL Migration | 🔴 Critical | 1 day |
| 3 | Frontend Login & Session | 🔴 Critical | 1-2 days |
| 4 | Environment Configuration | 🔴 Critical | 0.5 days |
| 5 | Real iCal Sync | 🟠 High | 1-2 days |
| 6 | Real Messaging Integration | 🟠 High | 2-3 days |
| 7 | Image Upload | 🟠 High | 1 day |
| 8 | Validation & Error Handling | 🟠 High | 1 day |
| 9 | Financial Reports & Export | 🟡 Medium | 1-2 days |
| 10 | Guest Form Improvements | 🟡 Medium | 1 day |
| 11 | Calendar Improvements | 🟡 Medium | 1-2 days |
| 12 | Notification System | 🟡 Medium | 2 days |
| 13 | Multi-Owner Access | 🟡 Medium | 2-3 days |
| 14 | Mobile App | 🟢 Low | 2-3 days |
| 15 | Analytics Dashboard | 🟢 Low | 1-2 days |
| 16 | Cleaning Management | 🟢 Low | 1-2 days |
| 17 | Guest Reviews | 🟢 Low | 1 day |
| 18 | Automated Pricing | 🟢 Low | 1-2 days |

**Estimated total to production-ready:** ~3-4 weeks with one developer working full time. Critical items alone can be completed in **~5-6 days**.
