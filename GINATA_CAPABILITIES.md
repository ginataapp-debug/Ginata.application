# Ginata Property Management — Full Capabilities

> **Last Updated:** October 19, 2026  
> **Version:** 2.0 — Post-iCal Sync & Finances  
> **Currency:** KES (Kenyan Shilling)  
> **Tax Policy:** 0.00% VAT (Direct Rate, No KRA PIN)

---

## 1. Property Portfolio Management

### 1.1 Add / Edit / Delete Properties
- Create **unlimited properties** (houses, villas, apartments, cottages) for direct and manual host inventory.
- Not dependent on Airbnb or Booking.com — ideal for **walk-in, phone, and direct bookings**.
- Each property has: **Name, City, Country, Physical Address, Nightly Rate (KES), Cleaning Fee (KES)**.
- All properties default to **0.00% VAT** (Direct Rate — No VAT applied).

### 1.2 Cover Image Support
- **Live Image Preview** in the property creation/edit dialog.
- Paste any public image URL (Unsplash, Google Drive, etc.) and see it rendered instantly before saving.
- Cover image displayed as a hero banner on each property card in the portfolio view.

### 1.3 Search & Filter
- Full-text search across property name, city, and country.
- Active estate count badge always visible.

---

## 2. Airbnb & Booking.com iCal Calendar Synchronization

### 2.1 Import Feeds (OTA → Ginata)
- **Paste Airbnb iCal Feed URL** into any property.
- **Paste Booking.com iCal Feed URL** into any property.
- Click **"Sync Channels Now"** to import blocked dates from external calendars.
- Visual **sync badges** (Airbnb red, Booking.com navy) on each property card show sync status.

### 2.2 Export Feed (Ginata → OTA)
- Each property auto-generates a **Ginata `.ics` export feed URL**.
- Copy the URL and paste it into Airbnb or Booking.com's "Other Calendars" section.
- Prevents double-bookings across all platforms.

### 2.3 Sync Modal
- Per-property **Sync iCal** button opens a dedicated dialog.
- Shows the export feed URL with a copy-to-clipboard button.
- Input fields for Airbnb and Booking.com import URLs.
- One-click **Sync Channels Now** button.

---

## 3. Reservation & Booking Management

### 3.1 Manual Booking Creation
- Full-featured booking dialog: guest name, phone, email, check-in/out dates, number of guests, number of nights.
- Automatic **nightly rate × nights + cleaning fee** calculation.
- **Conflict detection**: prevents overlapping bookings for the same property/dates.
- Supports **booking source** selection: Direct, Airbnb, Booking.com, Referral, Walk-in.

### 3.2 Agent Referral & Commission System
- Toggle **"Has Agent Referral"** on any direct booking.
- Enter **Agent Name**, **Agent Phone**, and **Commission Percentage**.
- System auto-calculates:
  - **Agent Commission Amount (KES)** = Total × Commission %
  - **Net Host Payout (KES)** = Total − Commission
- Agent badge (purple) displayed on reservation cards: `AGENT: Name (X%)`.

### 3.3 Reservation Lifecycle
- Status tracking: **Confirmed**, **Checked In**, **Checked Out**, **Cancelled**.
- Edit existing reservations (dates, guest info, amounts).
- Record **partial and full payments** with M-Pesa, Bank Transfer, Cash, and Card.
- Balance tracking: Paid vs. Outstanding.

### 3.4 Unified Calendar View
- Month-view calendar showing all bookings across all properties.
- Color-coded by property and booking status.
- Click-to-book on empty dates.

---

## 4. Finances & Property Expenses

### 4.1 Financial Dashboard
- **Net Host Profit** (KES): Gross Revenue − Agent Commissions − House Expenses.
- **Collected Cash** (KES): Total payments received.
- **Gross Bookings** (KES): Sum of all reservation totals.
- **Agent Commissions Paid** (KES): Sum of all agent referral commissions.
- **House Expenses** (KES): Sum of all property operating expenses.

### 4.2 Expense Recording
- Record expenses per property with:
  - **Expense Description** (e.g., "Master Bedroom AC repair & gas refill")
  - **Category**: Maintenance, Utilities, Cleaning, Supplies, Staff, HOA & Security, Wifi & Tech, Other
  - **Amount (KES)**
  - **Fundi / Vendor Name**
  - **Payment Method**: M-Pesa, Bank Transfer, Cash, Card
  - **Receipt / M-Pesa Reference** (e.g., MPESA QWE492)
  - **Date**

### 4.3 Expense Filtering
- Filter by **property** (dropdown of all estates).
- Filter by **category** (chip selector).
- View **House Financial Profiles** — per-property cards showing rate and quick filter access.

### 4.4 Expense Ledger
- Scrollable list of all expenses with category icons, property names, vendor names, references, and dates.
- Delete individual expense records with confirmation dialog.
- "No VAT Applied • Direct Rates" label always visible.

---

## 5. Unified Guest Inbox & Messages

### 5.1 Multi-Channel Thread Management
- View conversations across: **WhatsApp**, **Airbnb**, **Booking.com**, **SMS**, **Direct**.
- Channel-colored avatars and badges for instant identification.
- Filter threads by channel using chip selector.

### 5.2 Chat Interface
- Two-pane layout (wide screen) or stacked view (mobile).
- Chat-style message bubbles: host messages (forest green, right-aligned), guest messages (cream, left-aligned).
- Timestamps on each message.
- Real-time send/receive with text input and send button.
- Keyboard enter-to-send support.

### 5.3 New Conversation
- "New Message" button opens a dialog to start a thread.
- Specify: **Channel**, **Guest Full Name**, **Phone/Contact**, **Initial Message**.
- Auto-sends the first message upon thread creation.

---

## 6. Property Inventory Tracking

### 6.1 Per-Property Inventory Management
- **Inventory** button on each property card opens a full-featured modal.
- Track items with: **Name**, **Category** (Furniture, Linen, Electronics, Kitchenware, Bath & Amenities, Decor, Other), **Quantity**, **Condition** (Excellent, Good, Fair, Damaged, Needs Replacement), **Room Location**, **Replacement Cost (KES)**, **Notes / Serial No.**

### 6.2 Condition Badges
- Color-coded condition indicators: Green (Excellent), Teal (Good), Amber (Fair), Red (Damaged/Needs Replacement).

### 6.3 CRUD Operations
- Add items via accordion form.
- Delete items individually.
- View item count and full list per property.

---

## 7. Guest Check-In Forms (Digital)

### 7.1 Shareable Form Links
- Generate unique check-in form URLs per property.
- Send via WhatsApp, SMS, or email.
- Guests fill in: name, nationality, passport/ID, phone, email, arrival details, special requests.

### 7.2 Form Submission Management
- View all submissions with status: Pending, Matched, Reviewed.
- Match form submissions to existing reservations.
- Google Sheets sync integration.

### 7.3 Spam Protection
- Honeypot field for bot detection.
- Rate limiting on form submissions.

---

## 8. Invoice Studio & Document Generation

### 8.1 Invoice Generation
- Generate professional PDF invoices for any reservation.
- Includes: guest details, property, dates, nightly rate, cleaning fee, total, payments, balance.
- Zero VAT (0.00%) on all invoices.
- Sequential invoice numbering.

### 8.2 Receipt Generation
- Generate payment receipts for partial and full payments.
- M-Pesa reference tracking.
- Secure download links with expiry.

### 8.3 Document Archive
- View all generated documents (invoices, receipts).
- Download and share capabilities.
- Audit logging for all document generation.

---

## 9. Host Profile & Settings

### 9.1 Organization Profile
- Edit: Organization Name, Host Name, Phone, Email, Address.
- Branding settings for invoices and forms.

### 9.2 Template Customization
- Customize invoice and receipt templates.
- Set default nightly rates, cleaning fees, and check-in/out times.

---

## 10. Home Dashboard

### 10.1 Live Financial Metrics
- **Net Host Profit**, **Collected Cash**, **Active Reservations**, **Portfolio Size** — all pulled from live backend data.
- Real-time sync status indicator.

### 10.2 Quick Access Shortcuts
- Horizontally scrollable shortcut buttons to every section: New Stay, Estates & Inventory, Calendar, Stays & Agents, Finances & Expenses, Guest Messages, Guest Forms, Invoice Studio.

### 10.3 Today's Schedule
- Upcoming check-ins and check-outs from live reservation data.
- Turnover progress tracking.
- Portfolio spotlight banner.

---

## 11. App Branding

### 11.1 Logo & Favicon
- Ginata logo set as web favicon and app icon.
- Logo displayed in the app bar on every screen.

### 11.2 Splash Screen
- Elegant forest-green (#003329) loading splash screen with animated spinner and Ginata brand mark.

### 11.3 Design System
- **Forest Green** primary (#003329)
- **Sage** secondary (#466557)
- **Warm Cream** canvas (#FCF8F1)
- **Brass Gold** accents (#B89758)
- Consistent typography, spacing, and component styling across all screens.

---

## 12. Navigation

- **9-tab bottom navigation bar** with horizontal scroll:
  Home | Estates | Calendar | Stays | Finances | Messages | Forms | Studio | Profile
- Floating pill-style navigation bar with selection indicator dot.
- IndexedStack for instant tab switching without rebuilds.

---

## 13. Backend API

- **FastAPI** backend with SQLAlchemy ORM and SQLite database.
- Full REST API covering:
  - Properties CRUD + iCal feed export + channel sync
  - Reservations CRUD + conflict detection + agent commission calculation
  - Expenses CRUD + financial summary P&L
  - Messages threads + messages
  - Guest forms + spam protection
  - Invoices + receipts + secure download
  - Organization profile
  - Property inventory CRUD
- 12 automated tests — all passing.
- Audit logging for all mutations.
