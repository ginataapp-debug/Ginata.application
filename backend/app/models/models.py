import uuid
from datetime import datetime, date
from decimal import Decimal
from sqlalchemy import (
    Column, String, Integer, Numeric, Boolean, Date, DateTime, Text, ForeignKey, JSON, Index, UniqueConstraint
)
from sqlalchemy.orm import relationship
from backend.app.core.database import Base

def generate_uuid() -> str:
    return str(uuid.uuid4())

class Organization(Base):
    __tablename__ = "organizations"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    currency = Column(String(10), default="KES", nullable=False)
    tax_id = Column(String(100), nullable=True)  # e.g., KRA PIN
    phone = Column(String(50), nullable=True)
    email = Column(String(255), nullable=True)
    address = Column(String(255), nullable=True)
    city = Column(String(100), nullable=True)
    country = Column(String(100), default="Kenya", nullable=False)
    logo_url = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    properties = relationship("Property", back_populates="organization", cascade="all, delete-orphan")
    reservations = relationship("Reservation", back_populates="organization", cascade="all, delete-orphan")
    invoices = relationship("Invoice", back_populates="organization", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="organization", cascade="all, delete-orphan")
    document_templates = relationship("DocumentTemplate", back_populates="organization", cascade="all, delete-orphan")
    host_users = relationship("HostUser", back_populates="organization", cascade="all, delete-orphan")


class HostUser(Base):
    __tablename__ = "host_users"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    salt = Column(String(100), nullable=False)
    full_name = Column(String(200), nullable=False)
    phone = Column(String(50), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    session_token = Column(String(255), nullable=True, index=True)
    last_login_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    organization = relationship("Organization", back_populates="host_users")


class HostSession(Base):
    __tablename__ = "host_sessions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    host_id = Column(String(36), ForeignKey("host_users.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash = Column(String(64), unique=True, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class HostEmailVerification(Base):
    __tablename__ = "host_email_verifications"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    host_id = Column(String(36), ForeignKey("host_users.id", ondelete="CASCADE"), nullable=False, index=True)
    email = Column(String(255), nullable=False)
    code_hash = Column(String(255), nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    consumed_at = Column(DateTime, nullable=True)
    attempts = Column(Integer, default=0, nullable=False)


class Property(Base):
    __tablename__ = "properties"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    slug = Column(String(255), nullable=False)
    address = Column(String(255), nullable=True)
    city = Column(String(100), nullable=True)
    country = Column(String(100), default="Kenya", nullable=False)
    default_nightly_rate = Column(Numeric(12, 2), default=Decimal("15000.00"), nullable=False)
    currency = Column(String(10), default="KES", nullable=False)
    cleaning_fee = Column(Numeric(12, 2), default=Decimal("3500.00"), nullable=False)
    tax_rate = Column(Numeric(5, 4), default=Decimal("0.0000"), nullable=False)  # 0% default (VAT removed)
    image_url = Column(String(500), nullable=True)

    # Multi-channel Calendar Sync URLs (iCal feeds)
    airbnb_ical_url = Column(String(500), nullable=True)
    booking_com_ical_url = Column(String(500), nullable=True)
    ical_feed_token = Column(String(100), default=generate_uuid, nullable=False)
    last_synced_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    organization = relationship("Organization", back_populates="properties")
    units = relationship("PropertyUnit", back_populates="property", cascade="all, delete-orphan")
    reservations = relationship("Reservation", back_populates="property", cascade="all, delete-orphan")
    expenses = relationship("Expense", back_populates="property", cascade="all, delete-orphan")
    inventory_items = relationship("PropertyInventoryItem", back_populates="property", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("organization_id", "slug", name="uq_org_property_slug"),
    )


class PropertyUnit(Base):
    __tablename__ = "property_units"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    property_id = Column(String(36), ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    max_guests = Column(Integer, default=4, nullable=False)
    bedrooms = Column(Integer, default=1, nullable=False)
    bathrooms = Column(Integer, default=1, nullable=False)
    status = Column(String(50), default="active", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    property = relationship("Property", back_populates="units")
    reservations = relationship("Reservation", back_populates="unit")


class Guest(Base):
    __tablename__ = "guests"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255), nullable=True, index=True)
    phone = Column(String(50), nullable=True, index=True)
    id_type = Column(String(50), nullable=True)  # passport, national_id, driving_license
    id_number_masked = Column(String(100), nullable=True)
    nationality = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    reservations = relationship("Reservation", back_populates="primary_guest")


class Reservation(Base):
    __tablename__ = "reservations"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(String(36), ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True)
    unit_id = Column(String(36), ForeignKey("property_units.id", ondelete="SET NULL"), nullable=True, index=True)
    primary_guest_id = Column(String(36), ForeignKey("guests.id", ondelete="RESTRICT"), nullable=False, index=True)

    booking_reference = Column(String(100), nullable=True)
    booking_source = Column(String(50), default="direct", nullable=False)  # direct, phone, walk_in, airbnb, booking_com, other
    reservation_status = Column(String(50), default="confirmed", nullable=False)  # draft, confirmed, checked_in, checked_out, cancelled
    payment_status = Column(String(50), default="unpaid", nullable=False)  # unpaid, partial, paid, refunded
    guest_info_status = Column(String(50), default="pending", nullable=False)  # pending, completed, needs_review

    check_in_date = Column(Date, nullable=False, index=True)
    check_out_date = Column(Date, nullable=False, index=True)
    check_in_time = Column(String(10), default="15:00", nullable=False)
    check_out_time = Column(String(10), default="11:00", nullable=False)
    number_of_guests = Column(Integer, default=1, nullable=False)
    number_of_nights = Column(Integer, default=1, nullable=False)

    nightly_rate = Column(Numeric(12, 2), nullable=False)
    base_amount = Column(Numeric(12, 2), nullable=False)
    cleaning_fee = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    service_fee = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    discount_amount = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    tax_amount = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    total_amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(10), default="KES", nullable=False)

    amount_paid = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    balance_due = Column(Numeric(12, 2), nullable=False)

    # Agent Referral / Commission Tracking
    has_agent = Column(Boolean, default=False, nullable=False)
    agent_name = Column(String(200), nullable=True)
    agent_phone = Column(String(50), nullable=True)
    agent_commission_percent = Column(Numeric(5, 2), default=Decimal("0.00"), nullable=False)
    agent_commission_amount = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    net_host_amount = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)

    internal_notes = Column(Text, nullable=True)
    special_requests = Column(Text, nullable=True)

    has_conflict = Column(Boolean, default=False, nullable=False)
    conflict_override_reason = Column(Text, nullable=True)
    conflict_overridden_by = Column(String(100), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    organization = relationship("Organization", back_populates="reservations")
    property = relationship("Property", back_populates="reservations")
    unit = relationship("PropertyUnit", back_populates="reservations")
    primary_guest = relationship("Guest", back_populates="reservations")
    additional_guests = relationship("ReservationGuest", back_populates="reservation", cascade="all, delete-orphan")
    guest_form_submissions = relationship("GuestFormSubmission", back_populates="reservation", cascade="all, delete-orphan")
    invoices = relationship("Invoice", back_populates="reservation", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="reservation", cascade="all, delete-orphan")
    generated_documents = relationship("GeneratedDocument", back_populates="reservation", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_res_org_dates", "organization_id", "property_id", "check_in_date", "check_out_date"),
    )


class ReservationGuest(Base):
    __tablename__ = "reservation_guests"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    reservation_id = Column(String(36), ForeignKey("reservations.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(200), nullable=False)
    email = Column(String(255), nullable=True)
    phone = Column(String(50), nullable=True)
    is_primary = Column(Boolean, default=False, nullable=False)
    age_category = Column(String(20), default="adult", nullable=False)  # adult, child, infant

    reservation = relationship("Reservation", back_populates="additional_guests")


class GuestForm(Base):
    __tablename__ = "guest_forms"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(String(36), ForeignKey("properties.id", ondelete="SET NULL"), nullable=True)
    mode = Column(String(50), default="ginata_hosted", nullable=False)  # ginata_hosted, google_forms
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    fields_config = Column(JSON, nullable=True)

    # Google forms specific fields
    google_form_id = Column(String(255), nullable=True)
    google_sheet_id = Column(String(255), nullable=True)
    google_connected_email = Column(String(255), nullable=True)
    google_sync_status = Column(String(50), default="disconnected", nullable=False)  # connected, syncing, failed, disconnected
    google_last_sync_at = Column(DateTime, nullable=True)
    google_last_error = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class GuestFormSubmission(Base):
    __tablename__ = "guest_form_submissions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    reservation_id = Column(String(36), ForeignKey("reservations.id", ondelete="CASCADE"), nullable=False, index=True)
    token = Column(String(100), unique=True, nullable=False, index=True)
    token_expires_at = Column(DateTime, nullable=False)
    token_revoked = Column(Boolean, default=False, nullable=False)
    form_status = Column(String(50), default="unopened", nullable=False)  # unopened, opened, submitted, completed, needs_review

    submitted_at = Column(DateTime, nullable=True)
    guest_name = Column(String(200), nullable=True)
    guest_email = Column(String(255), nullable=True)
    guest_phone = Column(String(50), nullable=True)
    eta = Column(String(50), nullable=True)
    flight_number = Column(String(50), nullable=True)
    transport_mode = Column(String(50), nullable=True)
    dietary_requirements = Column(Text, nullable=True)
    special_requests = Column(Text, nullable=True)
    id_type = Column(String(50), nullable=True)
    id_number = Column(String(100), nullable=True)
    id_photo_url = Column(String(500), nullable=True)
    companion_details = Column(JSON, nullable=True)
    raw_data = Column(JSON, nullable=True)

    review_notes = Column(Text, nullable=True)
    reviewed_by = Column(String(100), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    reservation = relationship("Reservation", back_populates="guest_form_submissions")


class Invoice(Base):
    __tablename__ = "invoices"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    reservation_id = Column(String(36), ForeignKey("reservations.id", ondelete="CASCADE"), nullable=False, index=True)
    invoice_number = Column(String(100), nullable=False)  # unique per org
    document_type = Column(String(50), default="invoice", nullable=False)  # invoice, pro_forma, quotation
    status = Column(String(50), default="draft", nullable=False)  # draft, issued, paid, partially_paid, cancelled, amended

    issue_date = Column(Date, default=date.today, nullable=False)
    due_date = Column(Date, nullable=False)
    currency = Column(String(10), default="KES", nullable=False)

    # Supplier details snapshot
    supplier_name = Column(String(255), nullable=False)
    supplier_tax_pin = Column(String(100), nullable=True)
    supplier_address = Column(String(255), nullable=True)
    supplier_email = Column(String(255), nullable=True)
    supplier_phone = Column(String(50), nullable=True)
    supplier_logo_url = Column(String(500), nullable=True)

    # Guest / Primary billing contact
    billing_name = Column(String(200), nullable=False)
    billing_email = Column(String(255), nullable=True)
    billing_phone = Column(String(50), nullable=True)

    # Optional Company details (without altering guest personal identity)
    billing_company_name = Column(String(255), nullable=True)
    billing_company_pin = Column(String(100), nullable=True)
    billing_company_address = Column(String(255), nullable=True)

    subtotal = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    discount_total = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    tax_total = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    grand_total = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    amount_paid = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    balance_due = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)

    payment_terms = Column(Text, nullable=True)
    payment_instructions = Column(Text, nullable=True)  # M-Pesa, Bank details
    notes = Column(Text, nullable=True)
    footer = Column(Text, nullable=True)

    version = Column(Integer, default=1, nullable=False)
    issued_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    organization = relationship("Organization", back_populates="invoices")
    reservation = relationship("Reservation", back_populates="invoices")
    line_items = relationship("InvoiceLineItem", back_populates="invoice", cascade="all, delete-orphan", order_by="InvoiceLineItem.position")
    payment_allocations = relationship("PaymentAllocation", back_populates="invoice", cascade="all, delete-orphan")
    credit_notes = relationship("CreditNote", back_populates="invoice", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("organization_id", "invoice_number", name="uq_org_invoice_num"),
    )


class InvoiceLineItem(Base):
    __tablename__ = "invoice_line_items"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    invoice_id = Column(String(36), ForeignKey("invoices.id", ondelete="CASCADE"), nullable=False, index=True)
    position = Column(Integer, default=0, nullable=False)
    description = Column(String(255), nullable=False)
    quantity = Column(Numeric(10, 2), default=Decimal("1.00"), nullable=False)
    unit_price = Column(Numeric(12, 2), nullable=False)
    tax_rate = Column(Numeric(5, 4), default=Decimal("0.00"), nullable=False)
    tax_amount = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    discount_amount = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    total_amount = Column(Numeric(12, 2), nullable=False)

    invoice = relationship("Invoice", back_populates="line_items")


class Payment(Base):
    __tablename__ = "payments"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    reservation_id = Column(String(36), ForeignKey("reservations.id", ondelete="CASCADE"), nullable=False, index=True)
    invoice_id = Column(String(36), ForeignKey("invoices.id", ondelete="SET NULL"), nullable=True, index=True)

    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(10), default="KES", nullable=False)
    payment_method = Column(String(50), default="mpesa", nullable=False)  # mpesa, card, bank_transfer, cash, other
    transaction_reference = Column(String(100), nullable=True)  # M-Pesa receipt or transaction code
    is_verified = Column(Boolean, default=False, nullable=False)  # distinguish manually recorded vs verified
    verification_source = Column(String(50), default="manual", nullable=False)  # manual, mpesa_c2b, stripe
    payment_date = Column(DateTime, default=datetime.utcnow, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    organization = relationship("Organization", back_populates="payments")
    reservation = relationship("Reservation", back_populates="payments")
    allocations = relationship("PaymentAllocation", back_populates="payment", cascade="all, delete-orphan")
    receipt = relationship("Receipt", back_populates="payment", uselist=False, cascade="all, delete-orphan")


class PaymentAllocation(Base):
    __tablename__ = "payment_allocations"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    payment_id = Column(String(36), ForeignKey("payments.id", ondelete="CASCADE"), nullable=False, index=True)
    invoice_id = Column(String(36), ForeignKey("invoices.id", ondelete="CASCADE"), nullable=False, index=True)
    allocated_amount = Column(Numeric(12, 2), nullable=False)

    payment = relationship("Payment", back_populates="allocations")
    invoice = relationship("Invoice", back_populates="payment_allocations")


class Receipt(Base):
    __tablename__ = "receipts"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    payment_id = Column(String(36), ForeignKey("payments.id", ondelete="CASCADE"), nullable=False, unique=True)
    receipt_number = Column(String(100), nullable=False)
    receipt_date = Column(Date, default=date.today, nullable=False)
    amount_received = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(10), default="KES", nullable=False)
    payment_method = Column(String(50), nullable=False)
    transaction_reference = Column(String(100), nullable=True)
    remaining_balance = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    issued_to_name = Column(String(200), nullable=False)
    issued_by_name = Column(String(200), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    payment = relationship("Payment", back_populates="receipt")

    __table_args__ = (
        UniqueConstraint("organization_id", "receipt_number", name="uq_org_receipt_num"),
    )


class CreditNote(Base):
    __tablename__ = "credit_notes"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    invoice_id = Column(String(36), ForeignKey("invoices.id", ondelete="CASCADE"), nullable=False, index=True)
    credit_note_number = Column(String(100), nullable=False)
    reason = Column(Text, nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(10), default="KES", nullable=False)
    issued_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    invoice = relationship("Invoice", back_populates="credit_notes")

    __table_args__ = (
        UniqueConstraint("organization_id", "credit_note_number", name="uq_org_credit_note_num"),
    )


class DocumentTemplate(Base):
    __tablename__ = "document_templates"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(String(36), ForeignKey("properties.id", ondelete="CASCADE"), nullable=True)
    name = Column(String(255), default="Standard Forest Estate", nullable=False)
    layout_style = Column(String(50), default="minimalist_luxury", nullable=False)  # minimalist_luxury, classic_monograph, modern_corporate
    primary_color = Column(String(20), default="#003329", nullable=False)  # Forest Green
    secondary_color = Column(String(20), default="#466557", nullable=False)  # Sage
    font_family = Column(String(50), default="Plus Jakarta Sans", nullable=False)
    logo_url = Column(String(500), nullable=True)
    header_text = Column(Text, nullable=True)
    footer_text = Column(Text, nullable=True)
    payment_instructions = Column(Text, nullable=True)
    tax_notes = Column(Text, nullable=True)
    is_default = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    organization = relationship("Organization", back_populates="document_templates")


class GeneratedDocument(Base):
    __tablename__ = "generated_documents"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    reservation_id = Column(String(36), ForeignKey("reservations.id", ondelete="CASCADE"), nullable=False, index=True)
    invoice_id = Column(String(36), ForeignKey("invoices.id", ondelete="SET NULL"), nullable=True)
    receipt_id = Column(String(36), ForeignKey("receipts.id", ondelete="SET NULL"), nullable=True)
    document_type = Column(String(50), nullable=False)  # invoice, pro_forma, receipt, credit_note, quotation
    file_format = Column(String(10), nullable=False)  # pdf, docx, csv
    file_path = Column(String(500), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_size = Column(Integer, default=0, nullable=False)
    version = Column(Integer, default=1, nullable=False)
    secure_token = Column(String(100), unique=True, nullable=False, index=True)
    token_expires_at = Column(DateTime, nullable=False)
    is_revoked = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    reservation = relationship("Reservation", back_populates="generated_documents")
    delivery_attempts = relationship("DocumentDeliveryAttempt", back_populates="document", cascade="all, delete-orphan")


class DocumentDeliveryAttempt(Base):
    __tablename__ = "document_delivery_attempts"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    document_id = Column(String(36), ForeignKey("generated_documents.id", ondelete="CASCADE"), nullable=False, index=True)
    channel = Column(String(50), nullable=False)  # email, whatsapp, secure_link
    recipient = Column(String(255), nullable=False)
    status = Column(String(50), default="draft", nullable=False)  # draft, queued, sent, delivered, failed
    error_message = Column(Text, nullable=True)
    attempted_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    delivered_at = Column(DateTime, nullable=True)

    document = relationship("GeneratedDocument", back_populates="delivery_attempts")


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_type = Column(String(50), nullable=False)  # reservation, payment, invoice, receipt, guest_form
    entity_id = Column(String(36), nullable=False)
    action = Column(String(100), nullable=False)  # created, confirmed, overridden_conflict, payment_recorded, issued, etc.
    actor_name = Column(String(100), default="Host", nullable=False)
    details = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class OrgSequence(Base):
    __tablename__ = "org_sequences"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    series_key = Column(String(50), nullable=False)  # invoice, receipt, credit_note
    year = Column(Integer, nullable=False)
    current_val = Column(Integer, default=0, nullable=False)

    __table_args__ = (
        UniqueConstraint("organization_id", "series_key", "year", name="uq_org_series_year"),
    )


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(String(36), ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True)
    reservation_id = Column(String(36), ForeignKey("reservations.id", ondelete="SET NULL"), nullable=True)

    title = Column(String(255), nullable=False)
    category = Column(String(100), default="maintenance", nullable=False)  # maintenance, utilities, cleaning, supplies, repair, management, staff, other
    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(10), default="KES", nullable=False)
    expense_date = Column(Date, default=date.today, nullable=False)
    vendor_name = Column(String(200), nullable=True)
    receipt_reference = Column(String(100), nullable=True)
    payment_method = Column(String(50), default="mpesa", nullable=False)  # mpesa, bank_wire, cash, card
    notes = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    property = relationship("Property", back_populates="expenses")


class PropertyInventoryItem(Base):
    __tablename__ = "property_inventory_items"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(String(36), ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True)

    name = Column(String(255), nullable=False)
    category = Column(String(100), default="linen", nullable=False)  # linen, electronics, kitchenware, furniture, toiletries, security, keys, other
    quantity = Column(Integer, default=1, nullable=False)
    condition = Column(String(50), default="good", nullable=False)  # new, good, fair, needs_replacement, damaged
    room_location = Column(String(100), nullable=True)  # Master Bedroom, Kitchen, Living Room, etc.
    replacement_cost_kes = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    last_inspected_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    notes = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    property = relationship("Property", back_populates="inventory_items")


class MessageThread(Base):
    __tablename__ = "message_threads"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(String(36), ForeignKey("properties.id", ondelete="SET NULL"), nullable=True)
    reservation_id = Column(String(36), ForeignKey("reservations.id", ondelete="SET NULL"), nullable=True)

    channel = Column(String(50), default="whatsapp", nullable=False)  # whatsapp, airbnb, booking_com, sms, internal
    participant_name = Column(String(200), nullable=False)
    participant_contact = Column(String(200), nullable=True)  # phone or email or external ID
    status = Column(String(50), default="active", nullable=False)  # active, archived
    last_message_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    messages = relationship("Message", back_populates="thread", cascade="all, delete-orphan", order_by="Message.created_at.asc()")


class Message(Base):
    __tablename__ = "messages"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    thread_id = Column(String(36), ForeignKey("message_threads.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_type = Column(String(50), default="host", nullable=False)  # host, guest, agent, system
    sender_name = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    is_read = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    thread = relationship("MessageThread", back_populates="messages")


class MessageTemplate(Base):
    """Pre-built, reusable guest messages a host can copy & paste into Airbnb,
    Booking.com, WhatsApp, SMS or email. Scoped per organization so it follows
    the host across devices."""
    __tablename__ = "message_templates"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(255), nullable=False)
    category = Column(String(50), default="general", nullable=False)  # airbnb, booking_com, whatsapp, sms, email, general
    body = Column(Text, nullable=False)
    variables = Column(JSON, nullable=True)  # list of {{placeholder}} keys used in body
    is_active = Column(Boolean, default=True, nullable=False)
    use_count = Column(Integer, default=0, nullable=False)  # times copied by the host
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
