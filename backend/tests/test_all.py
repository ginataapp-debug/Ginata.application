import io
from datetime import date, datetime, timedelta
from decimal import Decimal
import pypdf
import docx
import pytest
from fastapi.testclient import TestClient

from backend.app.main import app, seed_database
from backend.app.core.config import settings
from backend.app.core.database import SessionLocal
from backend.app.models.models import (
    Organization, Property, Reservation, Invoice, Payment, Receipt,
    GuestFormSubmission, GeneratedDocument, DocumentTemplate
)
from backend.app.services.document_generator import (
    generate_invoice_pdf, generate_receipt_pdf, generate_invoice_docx, generate_invoice_csv
)
from backend.app.services.sequence_service import get_next_sequence_number

from backend.app.core.database import Base, engine

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    seed_database()
    # Seed 2 test properties for unit tests
    db = SessionLocal()
    try:
        from backend.app.models.models import Property, PropertyUnit
        p1 = Property(
            organization_id=settings.DEFAULT_ORG_ID,
            name="Karen Forest Villa",
            slug="karen-forest-villa",
            city="Nairobi",
            country="Kenya",
            address="Karen Road",
            default_nightly_rate=Decimal("25000.00"),
            cleaning_fee=Decimal("3500.00"),
            tax_rate=Decimal("0.0000")
        )
        p2 = Property(
            organization_id=settings.DEFAULT_ORG_ID,
            name="The Olive Grove Loft",
            slug="the-olive-grove-loft",
            city="Naivasha",
            country="Kenya",
            address="Moi South Lake Road",
            default_nightly_rate=Decimal("18000.00"),
            cleaning_fee=Decimal("2500.00"),
            tax_rate=Decimal("0.0000")
        )
        db.add_all([p1, p2])
        db.flush()
        u1 = PropertyUnit(property_id=p1.id, name="Main Villa", max_guests=6, bedrooms=3, bathrooms=3)
        u2 = PropertyUnit(property_id=p2.id, name="Loft Suite", max_guests=4, bedrooms=2, bathrooms=2)
        db.add_all([u1, u2])
        db.flush()

        from backend.app.models.models import Guest, HostUser, Reservation
        from backend.app.core.security import hash_password

        pwd_hash, salt = hash_password("host123456")
        db.add(
            HostUser(
                organization_id=settings.DEFAULT_ORG_ID,
                email="host@ginata.ke",
                password_hash=pwd_hash,
                salt=salt,
                full_name="Host",
                phone="+254 700 000 000",
                is_active=True,
                is_verified=True,
            )
        )
        g = Guest(
            organization_id=settings.DEFAULT_ORG_ID,
            first_name="Amina",
            last_name="Kariuki",
            email="amina.k@example.com",
            phone="+254 744 556 677"
        )
        db.add(g)
        db.flush()

        cin = date.today() + timedelta(days=5)
        cout = date.today() + timedelta(days=9)
        r = Reservation(
            organization_id=settings.DEFAULT_ORG_ID,
            property_id=p1.id,
            unit_id=u1.id,
            primary_guest_id=g.id,
            booking_source="direct",
            booking_reference="DIR-SEED-001",
            reservation_status="confirmed",
            payment_status="unpaid",
            guest_info_status="pending",
            check_in_date=cin,
            check_out_date=cout,
            check_in_time="14:00",
            check_out_time="10:30",
            number_of_guests=2,
            number_of_nights=4,
            nightly_rate=Decimal("25000.00"),
            base_amount=Decimal("100000.00"),
            cleaning_fee=Decimal("4000.00"),
            service_fee=Decimal("1000.00"),
            discount_amount=Decimal("2000.00"),
            tax_amount=Decimal("0.00"),
            total_amount=Decimal("103000.00"),
            amount_paid=Decimal("0.00"),
            balance_due=Decimal("103000.00"),
            currency="KES"
        )
        db.add(r)
        db.flush()

        from backend.app.models.models import InvoiceLineItem
        inv_num = get_next_sequence_number(db, settings.DEFAULT_ORG_ID, "INV")
        rec_num = get_next_sequence_number(db, settings.DEFAULT_ORG_ID, "REC")
        inv = Invoice(
            organization_id=settings.DEFAULT_ORG_ID,
            reservation_id=r.id,
            invoice_number=inv_num,
            document_type="invoice",
            status="issued",
            issue_date=date.today(),
            due_date=date.today() + timedelta(days=7),
            currency="KES",
            supplier_name="Ginata Property Management",
            supplier_tax_pin="P051234567Z",
            supplier_address="Karen Road, Nairobi",
            supplier_email="host@ginata.ke",
            supplier_phone="+254 700 000 000",
            billing_name="Amina Kariuki",
            billing_email="amina.k@example.com",
            billing_phone="+254 744 556 677",
            subtotal=Decimal("100000.00"),
            discount_total=Decimal("2000.00"),
            tax_total=Decimal("0.00"),
            grand_total=Decimal("98000.00"),
            amount_paid=Decimal("25000.00"),
            balance_due=Decimal("73000.00"),
            payment_terms="Net 7 days",
            payment_instructions="Pay via M-Pesa Paybill: 247247, Account: DIR-SEED-001"
        )
        db.add(inv)
        db.flush()

        li = InvoiceLineItem(
            invoice_id=inv.id,
            position=0,
            description="Luxury Villa Accommodation",
            quantity=Decimal("4.00"),
            unit_price=Decimal("25000.00"),
            tax_rate=Decimal("0.0000"),
            tax_amount=Decimal("0.00"),
            discount_amount=Decimal("2000.00"),
            total_amount=Decimal("98000.00")
        )
        db.add(li)
        db.flush()

        pm = Payment(
            organization_id=settings.DEFAULT_ORG_ID,
            reservation_id=r.id,
            invoice_id=inv.id,
            amount=Decimal("25000.00"),
            currency="KES",
            payment_method="mpesa",
            transaction_reference="QKJ991209M",
            is_verified=True,
            verification_source="manual",
            payment_date=datetime.utcnow()
        )
        db.add(pm)
        db.flush()

        rec = Receipt(
            organization_id=settings.DEFAULT_ORG_ID,
            payment_id=pm.id,
            receipt_number=rec_num,
            receipt_date=date.today(),
            amount_received=Decimal("25000.00"),
            currency="KES",
            payment_method="mpesa",
            transaction_reference="QKJ991209M",
            remaining_balance=Decimal("73000.00"),
            issued_to_name="Amina Kariuki",
            issued_by_name="Host"
        )
        db.add(rec)
        db.commit()
    finally:
        db.close()

    # Authenticate the seeded host so org-scoped endpoints resolve the tenant
    # from a valid session token (the app now requires Bearer auth).
    login_res = client.post(
        "/api/v1/auth/login",
        json={"email": "host@ginata.ke", "password": "host123456"},
    )
    assert login_res.status_code == 200, login_res.text
    token = login_res.json()["token"]
    client.headers.update({
        "Authorization": f"Bearer {token}",
        "X-Organization-ID": settings.DEFAULT_ORG_ID,
    })
    yield
    client.headers.pop("Authorization", None)

# 1. Manual booking creation and updates
def test_manual_booking_creation_and_update():
    # Fetch existing property
    prop_res = client.get("/api/v1/properties")
    assert prop_res.status_code == 200
    props = prop_res.json()
    assert len(props) > 0
    prop = props[0]

    # Create direct booking
    check_in = date.today() + timedelta(days=20)
    check_out = date.today() + timedelta(days=24)
    booking_payload = {
        "property_id": prop["id"],
        "unit_id": prop["units"][0]["id"] if prop.get("units") else None,
        "guest_first_name": "Amina",
        "guest_last_name": "Kariuki",
        "guest_email": "amina.k@example.com",
        "guest_phone": "+254 744 556 677",
        "booking_source": "direct",
        "booking_reference": "DIR-TEST-001",
        "reservation_status": "confirmed",
        "check_in_date": check_in.isoformat(),
        "check_out_date": check_out.isoformat(),
        "check_in_time": "14:00",
        "check_out_time": "10:30",
        "number_of_guests": 2,
        "nightly_rate": "25000.00",
        "cleaning_fee": "4000.00",
        "service_fee": "1000.00",
        "discount_amount": "2000.00",
        "currency": "KES",
        "internal_notes": "First-time direct guest from Nairobi"
    }
    res = client.post("/api/v1/reservations", json=booking_payload)
    assert res.status_code == 201, res.text
    booking = res.json()

    assert booking["reservation_status"] == "confirmed"
    assert booking["payment_status"] == "unpaid"
    assert booking["guest_info_status"] == "pending"
    assert Decimal(booking["nightly_rate"]) == Decimal("25000.00")
    assert booking["number_of_nights"] == 4
    assert Decimal(booking["base_amount"]) == Decimal("100000.00")
    # Base 100,000 + Cleaning 4,000 + Svc 1,000 - Disc 2,000 = 103,000 subtotal * 16% VAT = 16,480 -> Total = 119,480
    assert Decimal(booking["total_amount"]) == Decimal("103000.00")
    assert Decimal(booking["balance_due"]) == Decimal("103000.00")

    # Update booking internal notes and number of guests
    res_id = booking["id"]
    patch_payload = {
        "number_of_guests": 3,
        "internal_notes": "Updated: extra infant bed requested"
    }
    patch_res = client.patch(f"/api/v1/reservations/{res_id}", json=patch_payload)
    assert patch_res.status_code == 200
    updated = patch_res.json()
    assert updated["number_of_guests"] == 3
    assert "extra infant bed" in updated["internal_notes"]

# 2. Calendar updates and overlapping reservations
def test_calendar_and_overlapping_conflict_detection():
    props = client.get("/api/v1/properties").json()
    prop = props[0]
    unit_id = prop["units"][0]["id"] if prop.get("units") else None

    d_in = date.today() + timedelta(days=30)
    d_out = date.today() + timedelta(days=35)

    # First booking
    res1 = client.post("/api/v1/reservations", json={
        "property_id": prop["id"],
        "unit_id": unit_id,
        "guest_first_name": "Conflict",
        "guest_last_name": "Base",
        "guest_email": "c.base@example.com",
        "check_in_date": d_in.isoformat(),
        "check_out_date": d_out.isoformat(),
        "nightly_rate": "20000.00",
        "currency": "KES"
    })
    assert res1.status_code == 201

    # Overlapping attempt (same dates) without override -> must fail with 409
    res_conflict = client.post("/api/v1/reservations", json={
        "property_id": prop["id"],
        "unit_id": unit_id,
        "guest_first_name": "Overlapping",
        "guest_last_name": "Guest",
        "guest_email": "c.overlap@example.com",
        "check_in_date": (d_in + timedelta(days=1)).isoformat(),
        "check_out_date": (d_out + timedelta(days=2)).isoformat(),
        "nightly_rate": "20000.00",
        "currency": "KES",
        "override_conflict": False
    })
    assert res_conflict.status_code == 409
    assert "Overlapping booking detected" in res_conflict.json()["detail"]

    # Overlap attempt with explicit override -> must succeed with audit record
    res_override = client.post("/api/v1/reservations", json={
        "property_id": prop["id"],
        "unit_id": unit_id,
        "guest_first_name": "Overriding",
        "guest_last_name": "VIP",
        "guest_email": "c.override@example.com",
        "check_in_date": (d_in + timedelta(days=1)).isoformat(),
        "check_out_date": (d_out + timedelta(days=2)).isoformat(),
        "nightly_rate": "20000.00",
        "currency": "KES",
        "override_conflict": True,
        "conflict_override_reason": "Host VIP guest approved adjacent wing upgrade"
    })
    assert res_override.status_code == 201
    overridden_booking = res_override.json()
    assert overridden_booking["has_conflict"] is True
    assert overridden_booking["conflict_override_reason"] == "Host VIP guest approved adjacent wing upgrade"

    # Calendar must reflect both slots
    cal_res = client.get(f"/api/v1/properties/{prop['id']}/calendar")
    assert cal_res.status_code == 200
    cal_data = cal_res.json()
    assert len(cal_data["slots"]) >= 2

# 3. Checkout boundary behavior (Day X checkout and Day X checkin is allowed)
def test_checkout_boundary_behavior():
    props = client.get("/api/v1/properties").json()
    prop = props[1]  # The Olive Grove Loft
    unit_id = prop["units"][0]["id"] if prop.get("units") else None

    day_a = date.today() + timedelta(days=40)
    day_b = date.today() + timedelta(days=43)
    day_c = date.today() + timedelta(days=46)

    # Res A: day_a to day_b
    r_a = client.post("/api/v1/reservations", json={
        "property_id": prop["id"],
        "unit_id": unit_id,
        "guest_first_name": "Boundary",
        "guest_last_name": "A",
        "check_in_date": day_a.isoformat(),
        "check_out_date": day_b.isoformat(),
        "nightly_rate": "18500.00",
        "currency": "KES"
    })
    assert r_a.status_code == 201

    # Res B starts exactly on day_b (checkout of Res A) -> MUST SUCCEED WITHOUT CONFLICT!
    r_b = client.post("/api/v1/reservations", json={
        "property_id": prop["id"],
        "unit_id": unit_id,
        "guest_first_name": "Boundary",
        "guest_last_name": "B",
        "check_in_date": day_b.isoformat(),
        "check_out_date": day_c.isoformat(),
        "nightly_rate": "18500.00",
        "currency": "KES",
        "override_conflict": False
    })
    assert r_b.status_code == 201, r_b.text
    assert r_b.json()["has_conflict"] is False

# 4. Post-confirmation guest-form submission and idempotency
def test_post_confirmation_guest_form_and_idempotency():
    props = client.get("/api/v1/properties").json()
    prop = props[0]

    # Create confirmed booking
    b_res = client.post("/api/v1/reservations", json={
        "property_id": prop["id"],
        "guest_first_name": "Zuri",
        "guest_last_name": "Ochieng",
        "guest_email": "zuri.o@example.com",
        "check_in_date": (date.today() + timedelta(days=50)).isoformat(),
        "check_out_date": (date.today() + timedelta(days=53)).isoformat(),
        "nightly_rate": "28000.00",
        "reservation_status": "confirmed",
        "currency": "KES"
    })
    assert b_res.status_code == 201
    booking_id = b_res.json()["id"]

    # Get guest form token
    form_res = client.post(f"/api/v1/reservations/{booking_id}/guest-form")
    assert form_res.status_code == 200
    token = form_res.json()["token"]
    assert token is not None

    # Public guest form view
    view_res = client.get(f"/api/v1/public/forms/{token}")
    assert view_res.status_code == 200
    view_data = view_res.json()
    assert view_data["property_name"] == prop["name"]
    assert view_data["primary_guest_name"] == "Zuri Ochieng"
    assert view_data["is_expired"] is False

    # First submission
    sub_payload = {
        "guest_name": "Zuri Ochieng",
        "guest_email": "zuri.updated@example.com",
        "guest_phone": "+254 799 111 222",
        "eta": "16:00",
        "flight_number": "KQ404",
        "dietary_requirements": "Vegetarian",
        "id_type": "passport",
        "id_number": "A1234567"
    }
    sub1_res = client.post(f"/api/v1/public/forms/{token}/submit", json=sub_payload)
    assert sub1_res.status_code == 200
    sub1 = sub1_res.json()
    assert sub1["form_status"] == "needs_review"  # Because ID details provided
    assert sub1["eta"] == "16:00"

    # Check reservation guest_info_status is updated, but booking remains confirmed!
    chk_res = client.get(f"/api/v1/reservations/{booking_id}").json()
    assert chk_res["reservation_status"] == "confirmed"
    assert chk_res["guest_info_status"] == "needs_review"

    # Idempotent re-submission (updating flight & requests) -> MUST NOT create duplicate reservation
    sub_payload["flight_number"] = "KQ406"
    sub_payload["special_requests"] = "Late arrival snack tray"
    sub2_res = client.post(f"/api/v1/public/forms/{token}/submit", json=sub_payload)
    assert sub2_res.status_code == 200
    sub2 = sub2_res.json()
    assert sub2["id"] == sub1["id"]  # Same submission record updated!
    assert sub2["flight_number"] == "KQ406"

    # Verify no second reservation was created
    all_res = client.get(f"/api/v1/reservations?property_id={prop['id']}").json()
    matching_res = [r for r in all_res if r["id"] == booking_id]
    assert len(matching_res) == 1

# 5. Anti-spam honeypot
def test_guest_form_honeypot_spam_rejection():
    # Attempt submission with non-empty honeypot field
    form_res = client.post(f"/api/v1/reservations/{client.get('/api/v1/reservations').json()[0]['id']}/guest-form")
    token = form_res.json()["token"]

    spam_payload = {
        "guest_name": "Spam Bot",
        "honeypot": "http://spam-link.ru"
    }
    spam_res = client.post(f"/api/v1/public/forms/{token}/submit", json=spam_payload)
    assert spam_res.status_code == 400
    assert "Spam submission rejected" in spam_res.json()["detail"]

# 6. Tenant isolation and authorization
def test_tenant_isolation():
    # The tenant is derived from the authenticated host, so a foreign org header
    # is ignored and the host only ever sees their own organization's data.
    res = client.get("/api/v1/reservations", headers={"X-Organization-ID": "foreign-unauthorized-org"})
    assert res.status_code == 200
    for r in res.json():
        assert r["organization_id"] == settings.DEFAULT_ORG_ID

    # No session token -> unauthorized.
    no_auth = client.get("/api/v1/reservations", headers={"Authorization": ""})
    assert no_auth.status_code == 401

    # Invalid / revoked token -> unauthorized.
    bad_auth = client.get("/api/v1/reservations", headers={"Authorization": "Bearer not-a-real-token"})
    assert bad_auth.status_code == 401

# 7. Invoice calculations, company billing details, and issuance
def test_invoice_calculations_and_issuance():
    res_list = client.get("/api/v1/reservations").json()
    target_res = res_list[0]

    # Create invoice with custom company billing details
    inv_payload = {
        "reservation_id": target_res["id"],
        "document_type": "invoice",
        "billing_name": target_res["primary_guest"]["first_name"] + " " + target_res["primary_guest"]["last_name"],
        "billing_company_name": "Safari Logistics Kenya Ltd",
        "billing_company_pin": "P051992834K",
        "billing_company_address": "Kenyatta Avenue, Nairobi",
        "line_items": [
            {
                "description": "Executive Villa Accommodation (3 Nights)",
                "quantity": 3,
                "unit_price": "30000.00",
                "tax_rate": "0.1600",
                "discount_amount": "5000.00"
            },
            {
                "description": "Airport Chauffeur & Welcome Refreshments",
                "quantity": 1,
                "unit_price": "7500.00",
                "tax_rate": "0.1600",
                "discount_amount": "0.00"
            }
        ]
    }
    inv_res = client.post(f"/api/v1/reservations/{target_res['id']}/invoices", json=inv_payload)
    assert inv_res.status_code == 201
    inv = inv_res.json()
    assert inv["invoice_number"].startswith("GIN-INV-")
    assert inv["billing_company_name"] == "Safari Logistics Kenya Ltd"
    assert inv["billing_company_pin"] == "P051992834K"

    # Line item 1: (3 * 30,000) - 5,000 = 85,000 * 16% = 13,600 tax -> 98,600 total
    # Line item 2: 7,500 * 16% = 1,200 tax -> 8,700 total
    # Subtotal: 90,000 + 7,500 = 97,500
    # Discounts: 5,000
    # Tax: 14,800
    # Grand Total: 98,600 + 8,700 = 107,300
    assert Decimal(inv["grand_total"]) == Decimal("107300.00")
    assert inv["status"] == "draft"

    # Issue invoice
    issue_res = client.post(f"/api/v1/invoices/{inv['id']}/issue")
    assert issue_res.status_code == 200
    issued = issue_res.json()
    assert issued["status"] == "issued"
    assert issued["issued_at"] is not None

    # Editing issued invoice must be rejected
    fail_edit = client.patch(f"/api/v1/invoices/{inv['id']}", json={"notes": "Should fail"})
    assert fail_edit.status_code == 400

# 8. Partial payment and receipt generation
def test_partial_payment_and_receipt_generation():
    res_list = client.get("/api/v1/reservations").json()
    target_res = res_list[0]

    # Record partial payment of KES 25,000
    pay_payload = {
        "reservation_id": target_res["id"],
        "amount": "25000.00",
        "currency": "KES",
        "payment_method": "mpesa",
        "transaction_reference": "QKJ991209M",
        "notes": "Partial M-Pesa deposit via Paybill 247247"
    }
    pay_res = client.post("/api/v1/payments", json=pay_payload)
    assert pay_res.status_code == 201
    pay_data = pay_res.json()
    assert pay_data["amount"] == "25000.00"

    # Receipt must be automatically issued for this recorded payment
    assert pay_data.get("receipt") is not None
    receipt = pay_data["receipt"]
    assert receipt["receipt_number"].startswith("GIN-REC-")
    assert receipt["amount_received"] == "25000.00"
    assert receipt["payment_method"] == "mpesa"

# 9. Concurrency-safe sequence numbering
def test_consequential_numbering():
    db = SessionLocal()
    try:
        inv1 = get_next_sequence_number(db, settings.DEFAULT_ORG_ID, "INV")
        inv2 = get_next_sequence_number(db, settings.DEFAULT_ORG_ID, "INV")
        rec1 = get_next_sequence_number(db, settings.DEFAULT_ORG_ID, "REC")
        rec2 = get_next_sequence_number(db, settings.DEFAULT_ORG_ID, "REC")

        assert inv1 != inv2
        assert rec1 != rec2
        # Verify sequence numbers increment
        num1 = int(inv1.split("-")[-1])
        num2 = int(inv2.split("-")[-1])
        assert num2 == num1 + 1
    finally:
        db.close()

# 10. Real PDF, DOCX, and CSV file validity
def test_real_document_generation_and_validity():
    db = SessionLocal()
    try:
        invoice = db.query(Invoice).first()
        receipt = db.query(Receipt).first()

        # 1. Invoice PDF
        pdf_bytes = generate_invoice_pdf(invoice)
        assert len(pdf_bytes) > 1000
        # Parse PDF with pypdf to verify it is valid binary PDF
        pdf_reader = pypdf.PdfReader(io.BytesIO(pdf_bytes))
        assert len(pdf_reader.pages) >= 1
        page1_text = pdf_reader.pages[0].extract_text()
        assert invoice.invoice_number in page1_text or "INVOICE" in page1_text

        # 2. Receipt PDF
        rec_pdf_bytes = generate_receipt_pdf(receipt)
        assert len(rec_pdf_bytes) > 1000
        rec_reader = pypdf.PdfReader(io.BytesIO(rec_pdf_bytes))
        assert len(rec_reader.pages) >= 1
        rec_text = rec_reader.pages[0].extract_text()
        assert "RECEIPT" in rec_text

        # 3. Invoice DOCX
        docx_bytes = generate_invoice_docx(invoice)
        assert len(docx_bytes) > 1000
        # Parse DOCX with python-docx
        doc_obj = docx.Document(io.BytesIO(docx_bytes))
        assert len(doc_obj.paragraphs) > 0
        doc_text = " ".join([p.text for p in doc_obj.paragraphs])
        assert invoice.invoice_number in doc_text

        # 4. Invoice CSV
        csv_str = generate_invoice_csv(invoice)
        assert "Invoice Number" in csv_str
        assert "Grand Total" in csv_str
    finally:
        db.close()

# 11. Secure download expiry and revocation
def test_secure_download_expiry_and_revocation():
    invoices = client.get("/api/v1/invoices").json()
    inv_id = invoices[0]["id"]

    # Export invoice
    exp_res = client.post(f"/api/v1/invoices/{inv_id}/export", json={"format": "pdf"})
    assert exp_res.status_code == 200
    doc_meta = exp_res.json()
    token = doc_meta["secure_token"]

    # Public download using unguessable token
    dl_res = client.get(f"/api/v1/public/documents/{token}/download")
    assert dl_res.status_code == 200
    assert dl_res.headers["content-type"] == "application/pdf"

    # Revoke document
    db = SessionLocal()
    try:
        doc = db.query(GeneratedDocument).filter(GeneratedDocument.secure_token == token).first()
        doc.is_revoked = True
        db.commit()
    finally:
        db.close()

    # Public download after revocation -> MUST RETURN 410 GONE
    dl_revoked = client.get(f"/api/v1/public/documents/{token}/download")
    assert dl_revoked.status_code == 410
    owner_download = client.get(f"/api/v1/documents/{doc_meta['id']}/download")
    assert owner_download.status_code == 200
    assert len(pypdf.PdfReader(io.BytesIO(owner_download.content)).pages) >= 1

# 12. Delivery attempt logging (Email and WhatsApp)
def test_document_delivery_logging():
    invoices = client.get("/api/v1/invoices").json()
    inv_id = invoices[0]["id"]

    # Valid email
    send_res = client.post(f"/api/v1/invoices/{inv_id}/send", json={
        "channel": "email",
        "recipient": "guest.accounting@company.com"
    })
    assert send_res.status_code == 200
    assert send_res.json()["status"] == "sent"

    # Invalid email recipient format -> failure accurately recorded
    send_invalid = client.post(f"/api/v1/invoices/{inv_id}/send", json={
        "channel": "email",
        "recipient": "not-an-email"
    })
    assert send_invalid.status_code == 200
    assert send_invalid.json()["status"] == "failed"
    assert "Invalid email" in send_invalid.json()["error_message"]


def test_message_templates_seed_and_crud():
    # Fresh host starts with an empty library.
    empty = client.get("/api/v1/messages/templates")
    assert empty.status_code == 200, empty.text
    assert empty.json() == []

    # Seeding loads the curated starter library and extracts {{variables}}.
    seeded = client.post("/api/v1/messages/templates/seed")
    assert seeded.status_code == 200, seeded.text
    library = seeded.json()
    assert len(library) >= 6
    welcome = next(t for t in library if t["category"] == "airbnb")
    assert "guest_name" in welcome["variables"]
    assert welcome["use_count"] == 0

    # Seeding is idempotent — never clobbers the host's library.
    again = client.post("/api/v1/messages/templates/seed").json()
    assert len(again) == len(library)

    # Create a custom template; variables are derived from the body.
    created = client.post("/api/v1/messages/templates", json={
        "title": "Late arrival notice",
        "category": "WhatsApp",  # normalized to lowercase on save
        "body": "Hi {{guest_name}}, running late — arrive by {{eta}}. Code {{door_code}}.",
    })
    assert created.status_code == 201, created.text
    tpl = created.json()
    tpl_id = tpl["id"]
    assert tpl["category"] == "whatsapp"
    assert tpl["variables"] == ["guest_name", "eta", "door_code"]

    # Update body re-derives variables.
    updated = client.put(f"/api/v1/messages/templates/{tpl_id}", json={
        "body": "Hello {{guest_name}}, your gate code is {{door_code}}.",
        "is_active": False,
    })
    assert updated.status_code == 200, updated.text
    assert updated.json()["variables"] == ["guest_name", "door_code"]
    assert updated.json()["is_active"] is False

    # Marking used increments the copy counter.
    used = client.post(f"/api/v1/messages/templates/{tpl_id}/use")
    assert used.status_code == 200, used.text
    assert used.json()["use_count"] == 1

    # Delete removes it.
    deleted = client.delete(f"/api/v1/messages/templates/{tpl_id}")
    assert deleted.status_code == 204
    remaining = client.get("/api/v1/messages/templates").json()
    assert all(t["id"] != tpl_id for t in remaining)


def test_document_template_theming_changes_pdf():
    """Layout/typography/color settings must visibly change the rendered PDF."""
    db = SessionLocal()
    try:
        invoice = db.query(Invoice).first()

        default_pdf = generate_invoice_pdf(invoice)
        assert len(default_pdf) > 1000
        assert len(pypdf.PdfReader(io.BytesIO(default_pdf)).pages) >= 1

        serif_tpl = DocumentTemplate(
            layout_style="classic_monograph",
            font_family="Playfair Display",  # -> Times serif family
            primary_color="#123456",
            secondary_color="#654321",
        )
        band_tpl = DocumentTemplate(
            layout_style="modern_corporate",
            font_family="Courier",  # -> mono family
            primary_color="#003329",
            secondary_color="#466557",
        )
        serif_pdf = generate_invoice_pdf(invoice, template=serif_tpl)
        band_pdf = generate_invoice_pdf(invoice, template=band_tpl)

        for pdf_bytes, expected_font in [
            (default_pdf, '/Helvetica'),
            (serif_pdf, '/Times-Roman'),
            (band_pdf, '/Courier'),
        ]:
            reader = pypdf.PdfReader(io.BytesIO(pdf_bytes))
            fonts = {
                font.get_object()['/BaseFont']
                for page in reader.pages
                for font in page['/Resources']['/Font'].get_object().values()
            }
            assert expected_font in fonts
        assert serif_pdf != default_pdf
        assert band_pdf != default_pdf
        assert serif_pdf != band_pdf
    finally:
        db.close()


def test_apply_template_regenerates_archived_documents():
    """The apply endpoint promotes the template and re-renders stored PDFs."""
    invoices = client.get("/api/v1/invoices").json()
    inv_id = invoices[0]["id"]

    # Archive a PDF first so there is an existing generated document to refresh.
    exp = client.post(f"/api/v1/invoices/{inv_id}/export", json={"format": "pdf"})
    assert exp.status_code == 200, exp.text
    doc_id = exp.json()["id"]

    templates = client.get("/api/v1/templates").json()
    assert templates, "expected a default template"
    tpl_id = templates[0]["id"]

    # Change the look, then apply it to current invoices & receipts.
    patched = client.patch(f"/api/v1/templates/{tpl_id}", json={
        "layout_style": "modern_corporate",
        "font_family": "Playfair Display",
        "primary_color": "#0B3D2E",
        "secondary_color": "#B89758",
    })
    assert patched.status_code == 200, patched.text

    applied = client.post(f"/api/v1/templates/{tpl_id}/apply")
    assert applied.status_code == 200, applied.text
    body = applied.json()
    assert body["status"] == "applied"
    assert body["template_id"] == tpl_id
    assert body["documents_regenerated"] >= 1

    # The archived document version was bumped by the regeneration.
    db = SessionLocal()
    try:
        doc = db.query(GeneratedDocument).filter(GeneratedDocument.id == doc_id).first()
        assert doc is not None
        assert doc.version >= 2
        assert doc.file_size > 1000
        with open(doc.file_path, 'rb') as saved:
            assert len(pypdf.PdfReader(saved).pages) >= 1
    finally:
        db.close()

    downloaded = client.get(f'/api/v1/documents/{doc_id}/download')
    assert downloaded.status_code == 200
    assert len(pypdf.PdfReader(io.BytesIO(downloaded.content)).pages) >= 1


def test_document_preview_is_real_pdf_and_does_not_create_archive():
    before = client.get('/api/v1/documents').json()
    result = client.post('/api/v1/templates/preview', json={
        'layout_style': 'modern_corporate',
        'font_family': 'Courier',
        'header_text': 'Host & Company',
        'primary_color': '#003329',
        'secondary_color': '#466557',
    })
    assert result.status_code == 200, result.text
    reader = pypdf.PdfReader(io.BytesIO(result.content))
    text = '\n'.join(page.extract_text() for page in reader.pages)
    assert '103,000.00' in text
    assert client.get('/api/v1/documents').json() == before


def test_financial_summary_and_expense_filters():
    properties = client.get('/api/v1/properties').json()
    property_id = properties[0]['id']
    before = client.get('/api/v1/finances/summary', params={'property_id': property_id}).json()
    created = client.post('/api/v1/finances/expenses', json={
        'property_id': property_id, 'title': '=1+1',
        'category': 'Maintenance', 'amount': '1500.25', 'payment_method': 'mpesa',
    })
    assert created.status_code == 201, created.text
    for category in ['maintenance', 'Maintenance']:
        ledger = client.get('/api/v1/finances/expenses', params={'property_id': property_id, 'category': category})
        assert any(e['id'] == created.json()['id'] for e in ledger.json())
        exported = client.get('/api/v1/finances/expenses/export', params={'property_id': property_id, 'category': category})
        assert exported.status_code == 200
        assert '1500.25' in exported.text
        assert "'=1+1" in exported.text
    after = client.get('/api/v1/finances/summary', params={'property_id': property_id}).json()
    assert after['total_expenses'] == pytest.approx(before['total_expenses'] + 1500.25)
    assert after['net_operating_profit'] == pytest.approx(after['gross_revenue'] - after['total_agent_commissions'] - after['total_expenses'])
    invalid = client.post('/api/v1/finances/expenses', json={
        'property_id': property_id, 'title': 'Invalid', 'amount': '-1',
    })
    assert invalid.status_code == 422
    unknown_property = client.post('/api/v1/finances/expenses', json={
        'property_id': 'another-host-property', 'title': 'Invalid', 'amount': '500',
    })
    assert unknown_property.status_code == 404


def test_cover_image_upload_is_authenticated_and_served_from_storage():
    from PIL import Image

    output = io.BytesIO()
    Image.new('RGB', (2, 2), color='green').save(output, format='PNG')
    image_bytes = output.getvalue()
    unauthorized = client.post('/api/v1/uploads/image',
        files={'file': ('cover.png', image_bytes, 'image/png')},
        headers={'Authorization': ''})
    assert unauthorized.status_code == 401
    invalid = client.post('/api/v1/uploads/image',
        files={'file': ('cover.png', b'not an image', 'image/png')})
    assert invalid.status_code == 400
    uploaded = client.post('/api/v1/uploads/image',
        files={'file': ('cover.png', image_bytes, 'image/png')})
    assert uploaded.status_code == 201, uploaded.text
    payload = uploaded.json()
    path = settings.UPLOADS_DIR / payload['filename']
    try:
        assert path.read_bytes() == image_bytes
        assert payload['filename'].startswith(settings.DEFAULT_ORG_ID)
        served = client.get(payload['url'])
        assert served.status_code == 200
        assert served.content == image_bytes
    finally:
        path.unlink(missing_ok=True)
