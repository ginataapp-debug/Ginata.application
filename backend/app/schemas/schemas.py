from datetime import datetime, date
from decimal import Decimal
from typing import List, Optional, Any, Dict
from pydantic import BaseModel, EmailStr, Field, model_validator

# Base & Shared
class OrmModel(BaseModel):
    class Config:
        from_attributes = True

# Organization
class OrganizationBase(BaseModel):
    name: str
    currency: str = "KES"
    tax_id: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    country: str = "Kenya"
    logo_url: Optional[str] = None

class OrganizationResponse(OrganizationBase, OrmModel):
    id: str
    created_at: datetime
    updated_at: datetime

class OrganizationUpdate(BaseModel):
    name: Optional[str] = None
    currency: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    logo_url: Optional[str] = None

# Property Unit
class PropertyUnitBase(BaseModel):
    name: str
    max_guests: int = 4
    bedrooms: int = 1
    bathrooms: int = 1
    status: str = "active"

class PropertyUnitCreate(PropertyUnitBase):
    pass

class PropertyUnitResponse(PropertyUnitBase, OrmModel):
    id: str
    property_id: str
    created_at: datetime

# Property
class PropertyBase(BaseModel):
    name: str
    slug: str
    address: Optional[str] = None
    city: Optional[str] = None
    country: str = "Kenya"
    default_nightly_rate: Decimal = Decimal("15000.00")
    currency: str = "KES"
    cleaning_fee: Decimal = Decimal("3500.00")
    tax_rate: Decimal = Decimal("0.0000")  # 0% VAT default (VAT removed)
    image_url: Optional[str] = None
    airbnb_ical_url: Optional[str] = None
    booking_com_ical_url: Optional[str] = None

class PropertyCreate(PropertyBase):
    units: Optional[List[PropertyUnitCreate]] = None

class PropertyUpdate(BaseModel):
    name: Optional[str] = None
    slug: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    default_nightly_rate: Optional[Decimal] = None
    currency: Optional[str] = None
    cleaning_fee: Optional[Decimal] = None
    tax_rate: Optional[Decimal] = None
    image_url: Optional[str] = None
    airbnb_ical_url: Optional[str] = None
    booking_com_ical_url: Optional[str] = None

class PropertyResponse(PropertyBase, OrmModel):
    id: str
    organization_id: str
    ical_feed_token: Optional[str] = None
    last_synced_at: Optional[datetime] = None
    units: List[PropertyUnitResponse] = []
    created_at: datetime
    updated_at: datetime

# Guest
class GuestBase(BaseModel):
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    id_type: Optional[str] = None
    id_number_masked: Optional[str] = None
    nationality: Optional[str] = None

class GuestCreate(GuestBase):
    pass

class GuestResponse(GuestBase, OrmModel):
    id: str
    organization_id: str
    created_at: datetime

# Additional Reservation Guest
class ReservationGuestBase(BaseModel):
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    is_primary: bool = False
    age_category: str = "adult"

class ReservationGuestResponse(ReservationGuestBase, OrmModel):
    id: str
    reservation_id: str

# Conflict Checking
class ConflictCheckRequest(BaseModel):
    property_id: str
    unit_id: Optional[str] = None
    check_in_date: date
    check_out_date: date
    exclude_reservation_id: Optional[str] = None

class ConflictDetail(BaseModel):
    reservation_id: str
    booking_reference: Optional[str] = None
    guest_name: str
    check_in_date: date
    check_out_date: date
    reservation_status: str

class ConflictCheckResponse(BaseModel):
    has_conflict: bool
    message: str
    conflicts: List[ConflictDetail] = []

# Reservation
class InitialPaymentInput(BaseModel):
    amount: Decimal
    payment_method: str = "mpesa"
    transaction_reference: Optional[str] = None
    notes: Optional[str] = None

class ReservationCreate(BaseModel):
    property_id: str
    unit_id: Optional[str] = None
    guest_first_name: Optional[str] = "Guest"
    guest_last_name: Optional[str] = ""
    primary_guest: Optional[Dict[str, Any]] = None

    @model_validator(mode="before")
    @classmethod
    def extract_primary_guest(cls, data: Any) -> Any:
        if isinstance(data, dict):
            pg = data.get("primary_guest")
            if isinstance(pg, dict):
                if not data.get("guest_first_name") and pg.get("first_name"):
                    data["guest_first_name"] = pg.get("first_name")
                if not data.get("guest_last_name") and pg.get("last_name") is not None:
                    data["guest_last_name"] = pg.get("last_name")
                if not data.get("guest_email") and pg.get("email"):
                    data["guest_email"] = pg.get("email")
                if not data.get("guest_phone") and pg.get("phone"):
                    data["guest_phone"] = pg.get("phone")
        return data
    guest_email: Optional[str] = None
    guest_phone: Optional[str] = None
    booking_source: str = "direct"  # direct, phone, walk_in, airbnb, booking_com, other
    booking_reference: Optional[str] = None
    reservation_status: str = "confirmed"  # draft or confirmed
    check_in_date: date
    check_out_date: date
    check_in_time: str = "15:00"
    check_out_time: str = "11:00"
    number_of_guests: int = 1
    nightly_rate: Decimal
    cleaning_fee: Optional[Decimal] = Decimal("0.00")
    service_fee: Optional[Decimal] = Decimal("0.00")
    discount_amount: Optional[Decimal] = Decimal("0.00")
    tax_amount: Optional[Decimal] = None  # auto-computed from property tax_rate if None
    currency: str = "KES"
    internal_notes: Optional[str] = None
    special_requests: Optional[str] = None
    initial_payment: Optional[InitialPaymentInput] = None
    override_conflict: bool = False
    conflict_override_reason: Optional[str] = None

    # Agent Referral / Commission
    has_agent: bool = False
    agent_name: Optional[str] = None
    agent_phone: Optional[str] = None
    agent_commission_percent: Decimal = Decimal("0.00")

class ReservationUpdate(BaseModel):
    unit_id: Optional[str] = None
    check_in_date: Optional[date] = None
    check_out_date: Optional[date] = None
    check_in_time: Optional[str] = None
    check_out_time: Optional[str] = None
    number_of_guests: Optional[int] = None
    nightly_rate: Optional[Decimal] = None
    cleaning_fee: Optional[Decimal] = None
    service_fee: Optional[Decimal] = None
    discount_amount: Optional[Decimal] = None
    tax_amount: Optional[Decimal] = None
    booking_source: Optional[str] = None
    booking_reference: Optional[str] = None
    internal_notes: Optional[str] = None
    special_requests: Optional[str] = None
    override_conflict: bool = False
    conflict_override_reason: Optional[str] = None

    # Agent Referral / Commission
    has_agent: Optional[bool] = None
    agent_name: Optional[str] = None
    agent_phone: Optional[str] = None
    agent_commission_percent: Optional[Decimal] = None

class ReservationResponse(OrmModel):
    id: str
    organization_id: str
    property_id: str
    unit_id: Optional[str] = None
    primary_guest_id: str
    booking_reference: Optional[str] = None
    booking_source: str
    reservation_status: str
    payment_status: str
    guest_info_status: str
    check_in_date: date
    check_out_date: date
    check_in_time: str
    check_out_time: str
    number_of_guests: int
    number_of_nights: int
    nightly_rate: Decimal
    base_amount: Decimal
    cleaning_fee: Decimal
    service_fee: Decimal
    discount_amount: Decimal
    tax_amount: Decimal
    total_amount: Decimal
    currency: str
    amount_paid: Decimal
    balance_due: Decimal

    # Agent Referral / Commission
    has_agent: bool = False
    agent_name: Optional[str] = None
    agent_phone: Optional[str] = None
    agent_commission_percent: Decimal = Decimal("0.00")
    agent_commission_amount: Decimal = Decimal("0.00")
    net_host_amount: Decimal = Decimal("0.00")

    internal_notes: Optional[str] = None
    special_requests: Optional[str] = None
    has_conflict: bool
    conflict_override_reason: Optional[str] = None
    conflict_overridden_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    property: Optional[PropertyBase] = None
    unit: Optional[PropertyUnitBase] = None
    primary_guest: Optional[GuestBase] = None

# Guest Forms
class GuestFormResponse(OrmModel):
    id: str
    organization_id: str
    property_id: Optional[str] = None
    mode: str
    title: str
    description: Optional[str] = None
    is_active: bool
    fields_config: Optional[Dict[str, Any]] = None
    google_form_id: Optional[str] = None
    google_sheet_id: Optional[str] = None
    google_connected_email: Optional[str] = None
    google_sync_status: str
    google_last_sync_at: Optional[datetime] = None
    google_last_error: Optional[str] = None
    created_at: datetime

class GoogleFormsConfigRequest(BaseModel):
    form: str = Field(..., min_length=1, max_length=500, description="Google Form edit link or form ID")
    property_id: Optional[str] = None

class GoogleFormResponseOut(OrmModel):
    id: str
    google_response_id: str
    reservation_id: Optional[str] = None
    match_status: str
    sync_status: str
    match_reason: Optional[str] = None
    guest_name: Optional[str] = None
    guest_email: Optional[str] = None
    guest_phone: Optional[str] = None
    booking_reference: Optional[str] = None
    check_in_date: Optional[date] = None
    answers: Optional[List[Dict[str, Any]]] = None
    submitted_at: Optional[datetime] = None
    last_error: Optional[str] = None
    created_at: datetime

class GoogleFormAssignRequest(BaseModel):
    reservation_id: str = Field(..., min_length=1, max_length=36)

class HostNotificationOut(OrmModel):
    id: str
    kind: str
    title: str
    body: Optional[str] = None
    entity_type: Optional[str] = None
    entity_id: Optional[str] = None
    read_at: Optional[datetime] = None
    created_at: datetime

class PublicGuestFormView(BaseModel):
    token: str
    reservation_id: str
    property_name: str
    property_address: Optional[str] = None
    check_in_date: date
    check_out_date: date
    number_of_nights: int
    number_of_guests: int
    primary_guest_name: str
    form_status: str
    token_expires_at: datetime
    is_expired: bool
    is_revoked: bool

class PublicGuestFormSubmitRequest(BaseModel):
    guest_name: str
    guest_email: Optional[str] = None
    guest_phone: Optional[str] = None
    eta: Optional[str] = None
    flight_number: Optional[str] = None
    transport_mode: Optional[str] = None
    dietary_requirements: Optional[str] = None
    special_requests: Optional[str] = None
    id_type: Optional[str] = None
    id_number: Optional[str] = None
    id_photo_url: Optional[str] = None
    companion_details: Optional[List[Dict[str, Any]]] = None
    honeypot: Optional[str] = None  # Spam prevention field (must be empty)

class GuestFormSubmissionResponse(OrmModel):
    id: str
    organization_id: str
    reservation_id: str
    token: str
    token_expires_at: datetime
    token_revoked: bool
    form_status: str
    submitted_at: Optional[datetime] = None
    guest_name: Optional[str] = None
    guest_email: Optional[str] = None
    guest_phone: Optional[str] = None
    eta: Optional[str] = None
    flight_number: Optional[str] = None
    transport_mode: Optional[str] = None
    dietary_requirements: Optional[str] = None
    special_requests: Optional[str] = None
    id_type: Optional[str] = None
    id_number: Optional[str] = None
    id_photo_url: Optional[str] = None
    companion_details: Optional[Any] = None
    review_notes: Optional[str] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime

class SubmissionReviewRequest(BaseModel):
    action: str = Field(..., description="'complete' or 'needs_review'")
    review_notes: Optional[str] = None
    update_guest_profile: bool = True

# Invoice Line Items
class InvoiceLineItemBase(BaseModel):
    position: int = 0
    description: str
    quantity: Decimal = Decimal("1.00")
    unit_price: Decimal
    tax_rate: Decimal = Decimal("0.00")
    tax_amount: Optional[Decimal] = Decimal("0.00")
    discount_amount: Optional[Decimal] = Decimal("0.00")
    total_amount: Optional[Decimal] = None

class InvoiceLineItemCreate(InvoiceLineItemBase):
    pass

class InvoiceLineItemResponse(InvoiceLineItemBase, OrmModel):
    id: str
    invoice_id: str

# Invoice
class InvoiceCreate(BaseModel):
    reservation_id: Optional[str] = None
    document_type: str = "invoice"  # invoice, pro_forma, quotation
    due_date: Optional[date] = None
    currency: str = "KES"
    billing_name: Optional[str] = None
    billing_email: Optional[str] = None
    billing_phone: Optional[str] = None
    billing_company_name: Optional[str] = None
    billing_company_pin: Optional[str] = None
    billing_company_address: Optional[str] = None
    payment_terms: Optional[str] = None
    payment_instructions: Optional[str] = None
    notes: Optional[str] = None
    footer: Optional[str] = None
    line_items: Optional[List[InvoiceLineItemCreate]] = None

class InvoiceUpdate(BaseModel):
    document_type: Optional[str] = None
    due_date: Optional[date] = None
    billing_name: Optional[str] = None
    billing_email: Optional[str] = None
    billing_phone: Optional[str] = None
    billing_company_name: Optional[str] = None
    billing_company_pin: Optional[str] = None
    billing_company_address: Optional[str] = None
    payment_terms: Optional[str] = None
    payment_instructions: Optional[str] = None
    notes: Optional[str] = None
    footer: Optional[str] = None
    line_items: Optional[List[InvoiceLineItemCreate]] = None
    force_edit: bool = False

class InvoiceResponse(OrmModel):
    id: str
    organization_id: str
    reservation_id: str
    invoice_number: str
    document_type: str
    status: str
    issue_date: date
    due_date: date
    currency: str
    supplier_name: str
    supplier_tax_pin: Optional[str] = None
    supplier_address: Optional[str] = None
    supplier_email: Optional[str] = None
    supplier_phone: Optional[str] = None
    supplier_logo_url: Optional[str] = None
    billing_name: str
    billing_email: Optional[str] = None
    billing_phone: Optional[str] = None
    billing_company_name: Optional[str] = None
    billing_company_pin: Optional[str] = None
    billing_company_address: Optional[str] = None
    subtotal: Decimal
    discount_total: Decimal
    tax_total: Decimal
    grand_total: Decimal
    amount_paid: Decimal
    balance_due: Decimal
    payment_terms: Optional[str] = None
    payment_instructions: Optional[str] = None
    notes: Optional[str] = None
    footer: Optional[str] = None
    version: int
    issued_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    line_items: List[InvoiceLineItemResponse] = []

# Payments & Receipts
class PaymentCreate(BaseModel):
    reservation_id: str
    invoice_id: Optional[str] = None
    amount: Decimal
    currency: str = "KES"
    payment_method: str = "mpesa"  # mpesa, card, bank_transfer, cash, other
    transaction_reference: Optional[str] = None
    is_verified: bool = False
    verification_source: str = "manual"
    payment_date: Optional[datetime] = None
    notes: Optional[str] = None

class ReceiptResponse(OrmModel):
    id: str
    organization_id: str
    payment_id: str
    receipt_number: str
    receipt_date: date
    amount_received: Decimal
    currency: str
    payment_method: str
    transaction_reference: Optional[str] = None
    remaining_balance: Decimal
    issued_to_name: str
    issued_by_name: str
    created_at: datetime

class ReceiptUpdate(BaseModel):
    receipt_date: Optional[date] = None
    amount_received: Optional[Decimal] = None
    payment_method: Optional[str] = None
    transaction_reference: Optional[str] = None
    remaining_balance: Optional[Decimal] = None
    issued_to_name: Optional[str] = None
    issued_by_name: Optional[str] = None

class PaymentResponse(OrmModel):
    id: str
    organization_id: str
    reservation_id: str
    invoice_id: Optional[str] = None
    amount: Decimal
    currency: str
    payment_method: str
    transaction_reference: Optional[str] = None
    is_verified: bool
    verification_source: str
    payment_date: datetime
    notes: Optional[str] = None
    created_at: datetime
    receipt: Optional[ReceiptResponse] = None

# Credit Note
class CreditNoteCreate(BaseModel):
    invoice_id: str
    amount: Decimal
    reason: str
    currency: str = "KES"

class CreditNoteResponse(OrmModel):
    id: str
    organization_id: str
    invoice_id: str
    credit_note_number: str
    reason: str
    amount: Decimal
    currency: str
    issued_at: datetime

# Document Templates
class DocumentTemplateBase(BaseModel):
    name: str = "Standard Forest Estate"
    layout_style: str = "minimalist_luxury"  # minimalist_luxury, classic_monograph, modern_corporate
    primary_color: str = "#003329"
    secondary_color: str = "#466557"
    font_family: str = "Plus Jakarta Sans"
    logo_url: Optional[str] = None
    header_text: Optional[str] = None
    footer_text: Optional[str] = None
    payment_instructions: Optional[str] = None
    tax_notes: Optional[str] = None
    is_default: bool = True

class DocumentTemplateCreate(DocumentTemplateBase):
    property_id: Optional[str] = None

class DocumentTemplateUpdate(BaseModel):
    name: Optional[str] = None
    layout_style: Optional[str] = None
    primary_color: Optional[str] = None
    secondary_color: Optional[str] = None
    font_family: Optional[str] = None
    logo_url: Optional[str] = None
    header_text: Optional[str] = None
    footer_text: Optional[str] = None
    payment_instructions: Optional[str] = None
    tax_notes: Optional[str] = None
    is_default: Optional[bool] = None

class DocumentTemplateResponse(DocumentTemplateBase, OrmModel):
    id: str
    organization_id: str
    property_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

# Document Generation & Delivery
class DocumentExportRequest(BaseModel):
    format: str = "pdf"  # pdf, docx, csv

class GeneratedDocumentResponse(OrmModel):
    id: str
    organization_id: str
    reservation_id: str
    invoice_id: Optional[str] = None
    receipt_id: Optional[str] = None
    document_type: str
    file_format: str
    file_name: str
    file_size: int
    version: int
    secure_token: str
    token_expires_at: datetime
    is_revoked: bool
    created_at: datetime

class DocumentSendRequest(BaseModel):
    channel: str = Field(..., description="'email', 'whatsapp', or 'secure_link'")
    recipient: str = Field(..., description="Email address or WhatsApp phone number")
    custom_message: Optional[str] = None

class DeliveryAttemptResponse(OrmModel):
    id: str
    document_id: str
    channel: str
    recipient: str
    status: str  # draft, queued, sent, delivered, failed
    error_message: Optional[str] = None
    attempted_at: datetime
    delivered_at: Optional[datetime] = None

# Audit Log
class AuditLogResponse(OrmModel):
    id: str
    entity_type: str
    entity_id: str
    action: str
    actor_name: str
    details: Optional[Any] = None
    created_at: datetime

# Calendar View Response
class CalendarReservationSlot(BaseModel):
    reservation_id: str
    property_id: str
    unit_id: Optional[str] = None
    guest_name: str
    booking_source: str
    reservation_status: str
    check_in_date: date
    check_out_date: date
    has_conflict: bool
    total_amount: Decimal
    currency: str

class PropertyCalendarResponse(BaseModel):
    property_id: str
    property_name: str
    units: List[PropertyUnitBase] = []
    slots: List[CalendarReservationSlot] = []

# Financial Timeline
class FinancialTimelineItem(BaseModel):
    type: str  # reservation_confirmed, payment_recorded, invoice_issued, receipt_issued, credit_note
    date: datetime
    title: str
    description: str
    amount: Optional[Decimal] = None
    currency: Optional[str] = None
    reference_id: Optional[str] = None

class ReservationFinancialTimeline(BaseModel):
    reservation_id: str
    total_amount: Decimal
    amount_paid: Decimal
    balance_due: Decimal
    currency: str
    timeline: List[FinancialTimelineItem] = []


# Expenses & House Finances
class ExpenseBase(BaseModel):
    property_id: str
    reservation_id: Optional[str] = None
    title: str
    category: str = "maintenance"
    amount: Decimal
    currency: str = "KES"
    expense_date: date = Field(default_factory=date.today)
    vendor_name: Optional[str] = None
    receipt_reference: Optional[str] = None
    payment_method: str = "mpesa"
    notes: Optional[str] = None

class ExpenseCreate(ExpenseBase):
    pass

class ExpenseUpdate(BaseModel):
    property_id: Optional[str] = None
    title: Optional[str] = None
    category: Optional[str] = None
    amount: Optional[Decimal] = None
    expense_date: Optional[date] = None
    vendor_name: Optional[str] = None
    receipt_reference: Optional[str] = None
    payment_method: Optional[str] = None
    notes: Optional[str] = None

class ExpenseResponse(ExpenseBase, OrmModel):
    id: str
    organization_id: str
    created_at: datetime
    updated_at: datetime


# Property Inventory
class PropertyInventoryItemBase(BaseModel):
    name: str
    category: str = "linen"
    quantity: int = 1
    condition: str = "good"
    room_location: Optional[str] = None
    replacement_cost_kes: Decimal = Decimal("0.00")
    notes: Optional[str] = None

class PropertyInventoryItemCreate(PropertyInventoryItemBase):
    pass

class PropertyInventoryItemUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    quantity: Optional[int] = None
    condition: Optional[str] = None
    room_location: Optional[str] = None
    replacement_cost_kes: Optional[Decimal] = None
    notes: Optional[str] = None

class PropertyInventoryItemResponse(PropertyInventoryItemBase, OrmModel):
    id: str
    organization_id: str
    property_id: str
    last_inspected_at: datetime
    created_at: datetime
    updated_at: datetime


# Messages & Communications
class MessageBase(BaseModel):
    content: str
    sender_type: str = "host"
    sender_name: str = "Host"

class MessageCreate(MessageBase):
    pass

class MessageResponse(MessageBase, OrmModel):
    id: str
    thread_id: str
    is_read: bool
    created_at: datetime

class MessageThreadBase(BaseModel):
    property_id: Optional[str] = None
    reservation_id: Optional[str] = None
    channel: str = "whatsapp"
    participant_name: str
    participant_contact: Optional[str] = None

class MessageThreadCreate(MessageThreadBase):
    initial_message: Optional[str] = None

class MessageThreadResponse(MessageThreadBase, OrmModel):
    id: str
    organization_id: str
    status: str
    last_message_at: datetime
    created_at: datetime
    messages: List[MessageResponse] = []


# Pre-built / reusable message templates (Airbnb, Booking.com, WhatsApp, ...)
class MessageTemplateBase(BaseModel):
    title: str
    category: str = "general"  # airbnb, booking_com, whatsapp, sms, email, general
    body: str
    variables: Optional[List[str]] = None
    is_active: bool = True

class MessageTemplateCreate(MessageTemplateBase):
    pass

class MessageTemplateUpdate(BaseModel):
    title: Optional[str] = None
    category: Optional[str] = None
    body: Optional[str] = None
    variables: Optional[List[str]] = None
    is_active: Optional[bool] = None

class MessageTemplateResponse(MessageTemplateBase, OrmModel):
    id: str
    organization_id: str
    use_count: int = 0
    created_at: datetime
    updated_at: datetime


# Host Authentication Schemas
class HostSignUpRequest(BaseModel):
    full_name: str = Field(min_length=1, max_length=200, pattern=r"\S")
    email: EmailStr = Field(max_length=255)
    password: str = Field(min_length=10, max_length=1024)
    phone: Optional[str] = None
    organization_name: Optional[str] = None

class HostLoginRequest(BaseModel):
    email: EmailStr = Field(max_length=255)
    password: str = Field(min_length=1, max_length=1024)

class HostVerificationSendRequest(HostLoginRequest):
    pass

class HostVerificationRequest(BaseModel):
    email: EmailStr = Field(max_length=255)
    code: str = Field(pattern=r"^[0-9]{6}$")

class HostUserResponse(OrmModel):
    id: str
    organization_id: str
    email: str
    full_name: str
    phone: Optional[str] = None
    is_active: bool
    is_verified: bool
    last_login_at: Optional[datetime] = None
    created_at: datetime

class HostAuthResponse(BaseModel):
    success: bool
    token: Optional[str] = None
    verification_required: bool = False
    host: HostUserResponse
    organization_id: str
    message: str

class HostProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = Field(default=None, min_length=1, max_length=200, pattern=r"\S")
    phone: Optional[str] = None
    email: Optional[EmailStr] = Field(default=None, max_length=255)
