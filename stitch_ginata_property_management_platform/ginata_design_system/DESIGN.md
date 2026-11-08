---
name: Ginata Design System
colors:
  surface: '#fdf9f2'
  surface-dim: '#dddad3'
  surface-bright: '#fdf9f2'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f7f3ec'
  surface-container: '#f1ede6'
  surface-container-high: '#ebe8e1'
  surface-container-highest: '#e6e2db'
  on-surface: '#1c1c18'
  on-surface-variant: '#404946'
  inverse-surface: '#31302c'
  inverse-on-surface: '#f4f0e9'
  outline: '#707975'
  outline-variant: '#c0c8c4'
  surface-tint: '#37675b'
  primary: '#003329'
  on-primary: '#ffffff'
  primary-container: '#174a3f'
  on-primary-container: '#87b9aa'
  inverse-primary: '#9ed1c2'
  secondary: '#466557'
  on-secondary: '#ffffff'
  secondary-container: '#c5e7d6'
  on-secondary-container: '#4a695c'
  tertiary: '#442500'
  on-tertiary: '#ffffff'
  tertiary-container: '#633800'
  on-tertiary-container: '#ed9e48'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#baedde'
  primary-fixed-dim: '#9ed1c2'
  on-primary-fixed: '#00201a'
  on-primary-fixed-variant: '#1d4f44'
  secondary-fixed: '#c8ead9'
  secondary-fixed-dim: '#adcebe'
  on-secondary-fixed: '#012016'
  on-secondary-fixed-variant: '#2f4d40'
  tertiary-fixed: '#ffdcbe'
  tertiary-fixed-dim: '#ffb870'
  on-tertiary-fixed: '#2d1600'
  on-tertiary-fixed-variant: '#693c00'
  background: '#fdf9f2'
  on-background: '#1c1c18'
  surface-variant: '#e6e2db'
typography:
  headline-xl:
    fontFamily: Playfair Display
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-xl-mobile:
    fontFamily: Playfair Display
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 32px
  headline-lg:
    fontFamily: Playfair Display
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
  headline-md:
    fontFamily: Playfair Display
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 26px
  title-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 12px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1.25rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system expresses quiet luxury, bespoke stewardship, and effortless operational command for boutique hoteliers and high-end short-term rental operators. It balances the calm refinement of an architectural monograph with the fluid, tactile precision of iOS-native utilities.

### Design Principles
- **Effortless Command:** Complex multi-calendar synchronizations, check-in logistics, and turnover dispatching feel calm, spacious, and unhurried.
- **Warm Editorial Tactility:** Replaces harsh utilitarian SaaS ergonomics with warm cream canvases, deep forest shadows, and organic radii reminiscent of physical concierge keycards and bespoke stationery.
- **Glass & Depth:** High-performance mobile interfaces utilize frosted parchment surfaces, micro-elevation, and subtle brass accents to guide attention to high-value reservation milestones.
- **Clarity under Pressure:** Critical alerts (double bookings, turnover delays) surface through subdued, warm ochre and terracotta pills that command focus without inducing cognitive panic.

## Colors

The palette draws inspiration from heritage estates, evergreen pine groves, and artisanal paper stock. The base interface eschews clinical stark whites in favor of an ambient cream base layered with crisp white cards and deep green structural anchors.

### Functional Mapping
- **Canvas Base:** `#FCF8F1` (Warm Cream). The foundation for all app screens, eliminating eye fatigue.
- **Surface Clean:** `#FFFFFF` (Crisp White). Primary card elevated state for active bookings, guest portfolios, and modal sheets.
- **Surface Subdued:** `#F4EFEB` (Soft Parchment). Secondary containers, unselected calendar segments, and search input fields.
- **Text Primary:** `#0D2620` (Deep Pine). High-legibility text for guest names, rates, and titles.
- **Text Secondary:** `#4A5550` (Slate Olive). Contextual metadata, property addresses, and timestamp captions.
- **Primary Action & Focus:** `#174A3F` (Deep Forest Green). Primary interaction targets, confirmed badges, and active tab highlights.
- **Secondary Accent:** `#7A9A8B` (Muted Sage). Active switches, progress indicators, and neutral status pills.
- **Attention / Warning:** `#C27A27` (Warm Ochre). Booking conflicts, urgent guest messaging, and pending verification states.
- **Alert / Destructive:** `#C85A48` (Soft Terracotta). Overbookings, cleaning delays, and cancellations.
- **Prestige Touch:** `#D4AF37` / `#B89758` (Refined Brass). Subtle hairline dividers, VIP status badges, and star-tier ratings.

## Typography

The type system pairs the editorial elegance of Playfair Display with the clean geometry and high screen legibility of Plus Jakarta Sans.

### Hierarchical Roles
- **Editorial Headlines (`headline-*`):** Rendered in Playfair Display. Reserved for hero property portfolio titles, financial revenue dashboards, and welcome states. Conveys prestige and tailored hospitality.
- **Section Headers & Metric Identifiers (`title-*`):** Rendered in Plus Jakarta Sans Semi-Bold to ensure immediate legibility during rapid navigation.
- **Operational Body & Logistics (`body-*`):** Plus Jakarta Sans Regular. Set with generous line height for effortless readability of guest check-in notes, lockbox instructions, and reservation summaries.
- **Status Badges, Indicators & Meta (`label-*`):** Plus Jakarta Sans Bold/Semi-Bold. Capitalization with subtle positive tracking (+0.4px) for pill tags, navigation bar items, and data labels.

## Layout & Spacing

Designed primarily for single-hand mobile efficiency with adaptive layout expansion for tablet concierge desks and desktop revenue managers.

### Layout Mechanics
- **Mobile Canvas Grid:** Single-column modular stacked view with a strict `16px` outer margin safe zone.
- **Vertical Rhythm:** Rooted in an 8-point system (scaled with 4px sub-increments for fine badge alignment).
- **Safe Area Bottom Navigation:** The floating bottom navigation bar reserves `96px` of clear padding at the bottom of all scroll containers to ensure cards never slip beneath the translucent glass dock.
- **Adaptive Layout:** On viewport widths > 768px, single-column booking queues split into a 4-column timeline alongside a persistent 8-column contextual guestfolio pane.

## Elevation & Depth

Visual hierarchy uses subtle frosted layers, translucent parchment sheets, and ultra-diffused forest-tinted drop shadows instead of harsh black elevations.

### Surface Elevation Levels
- **Base Level 0 (Canvas):** Flat `#FCF8F1` backdrop.
- **Elevation Level 1 (Resting Cards):** `#FFFFFF` fill with an ultra-soft shadow: `0 4px 20px -2px rgba(13, 38, 32, 0.04), 0 1px 3px 0 rgba(13, 38, 32, 0.02)`.
- **Elevation Level 2 (Interactive & Active Cards):** `#FFFFFF` fill with a crisp boundary and gentle lift: `0 12px 32px -4px rgba(13, 38, 32, 0.07), 0 2px 6px 0 rgba(13, 38, 32, 0.03)`.
- **Elevation Level 3 (Modals & Sheet Drawers):** `#FFFFFF` anchored over a backdrop scrim (`rgba(13, 38, 32, 0.35)` with 8px Gaussian blur). Shadow: `0 24px 48px -12px rgba(13, 38, 32, 0.18)`.
- **Translucent Glass Surface (Bottom Navigation Dock & Sticky Bar):** Background `rgba(252, 248, 241, 0.82)` paired with `backdrop-filter: blur(20px)` and a top border hairline of `rgba(23, 74, 63, 0.08)`.

## Shapes

The shape vocabulary uses soft, natural curvatures inspired by modern high-end architectural contours and smooth river stones.

### Geometry Specifications
- **Pill Elements (Full Round):** Applied to status badges, chips, search inputs, floating filters, and call-to-action buttons (`border-radius: 9999px`).
- **Standard Cards:** `16px` (`rounded-lg` per standard scales; equivalent to `rounded-2xl` in Apple iOS design language).
- **Hero Containers & Bottom Sheets:** `24px` to `32px` upper radius (`rounded-xl` to `rounded-3xl`) for seamless organic containment.
- **Avatar & Channel Badges:** Squircle / continuous corner radius (`22%` smoothing) for property thumbnails and host avatars.

## Components

### Buttons
- **Primary Action:** Solid Deep Forest Green (`#174A3F`), crisp white text (`#FFFFFF`), full pill shape, `48px` minimum height on touch targets. Subtle internal upper-border brass highlight (`1px inset rgba(212, 175, 55, 0.2)`).
- **Secondary Action:** Soft Parchment fill (`#F4EFEB`), Deep Pine text (`#0D2620`), zero border, soft tactile press state down-scaling (`scale(0.98)`).
- **Ghost/Tertiary:** No background, Muted Slate Olive text (`#4A5550`), underline on hover/focus.

### Status Badges & Chips
Status pills feature an ultra-refined `10px` or `11px` bold label with an organic `24px` height and a miniature leading `6px` status dot:
- **Confirmed / Ready:** Subtle Sage tint (`rgba(122, 154, 139, 0.15)`), Deep Forest Green text (`#174A3F`), active green indicator dot.
- **Pending Review:** Warm Ochre tint (`rgba(194, 122, 39, 0.12)`), Ochre text (`#A16218`), amber indicator dot.
- **Conflict Detected / Action Needed:** Soft Terracotta tint (`rgba(200, 90, 72, 0.12)`), Terracotta text (`#B84330`), pulsing red-orange dot.
- **Cleaned & Inspected:** Parchment tint (`#EFE9DF`), Slate Olive text (`#384841`), steady brass indicator dot.

### Reservation & Property Cards
- Encased in Crisp White (`#FFFFFF`) with a `16px` border radius and Elevation Level 1.
- Features horizontal channel iconography (Airbnb coral badge or Booking.com navy glyph) embedded as subtle micro-tags in the top-right corner.
- Internal padding is strictly `16px` or `20px` to maintain visual serenity.

### Input Fields & Search Bars
- Background set to Soft Warm Parchment (`#F4EFEB`) to contrast against Crisp White cards or modal surfaces.
- Border is a barely perceptible hairline (`1px solid rgba(23, 74, 63, 0.08)`).
- On focus, transitions cleanly to a Deep Forest Green hairline (`1.5px solid #174A3F`) with an ambient warm glow without loud focus rings.

### Checkboxes, Toggles & Radios
- Selection controls use Deep Forest Green (`#174A3F`) for selected states with crisp white check glyphs.
- Switches feature a warm bone toggle knob sliding over a Sage Green track when enabled, and Warm Parchment track when disabled.

### Mobile Bottom Navigation
- Floating dock positioned `16px` above the bottom screen edge, with a continuous `28px` rounded pill silhouette.
- Surface constructed with frosted translucent cream (`rgba(252, 248, 241, 0.88)` with `backdrop-filter: blur(24px)`).
- Active items use Deep Forest Green glyphs with a micro-indicator brass pin directly underneath; inactive items rest in Muted Slate Olive (`#7A9A8B`).