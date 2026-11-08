# Ginata Property Management — 100% Free Production Deployment Guide
## Complete Setup Using Supabase Free Tier (No VM, No Custom Domain, Zero Monthly Cost)

> **Cost:** \$0.00 / month forever  
> **Hosting Type:** Serverless & Cloud-native (Managed PostgreSQL + Free Cloud API + Free Global CDN Web App)  
> **No Credit Card Required** for initial setup on most tiers

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
`https://ginata-api.onrender.com`

---

## 🌐 4. Step-by-Step Free Frontend Web Deployment on Vercel (5 Minutes)

### Step 4.1: Build Flutter Web for Production
In your terminal, navigate to the `frontend` folder and build with your live Render backend URL:
```bash
flutter build web --release --dart-define=API_URL=https://ginata-api.onrender.com/api/v1
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

1. Build the Android package:
   ```bash
   flutter build apk --release
   ```
2. The generated APK will be at:
   `frontend/build/app/outputs/flutter-apk/app-release.apk`
3. Send this file to your phone via WhatsApp, Google Drive, or USB cable.
4. Tap the file on your Android phone and click **Install**.
5. You now have the Ginata Property Management app installed natively with its custom forest-green icon!

---

## 🔒 6. Zero-Maintenance Checklist

- [x] **No VM to patch or maintain:** Supabase and Render manage all OS updates, firewall rules, and uptime automatically.
- [x] **No domain renewal fees:** Render provides `*.onrender.com` with free SSL, and Vercel provides `*.vercel.app` with free SSL.
- [x] **Automatic backups:** Supabase performs daily automated backups of your database.
- [x] **0.00% VAT:** Conforms to direct rate rental operations without KRA PIN burdens.
- [x] **Live iCal Feeds:** Your Airbnb and Booking.com iCal links sync automatically with `https://ginata-api.onrender.com/api/v1/properties/{id}/feed.ics`.
