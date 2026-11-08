from datetime import timezone, datetime, date, timedelta
from decimal import Decimal
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.models.models import (
    Invoice, InvoiceLineItem, Reservation, Property, Organization,
    CreditNote, DocumentTemplate
)
from backend.app.schemas.schemas import (
    InvoiceCreate, InvoiceUpdate, CreditNoteCreate
)
from backend.app.services.audit_service import log_audit_event
from backend.app.services.sequence_service import get_next_sequence_number

def create_invoice_from_reservation(
    db: Session,
    organization_id: str,
    invoice_in: InvoiceCreate,
    actor_name: str = "Host Clara"
) -> Invoice:
    """
    Creates an itemized invoice, pro forma invoice, or quotation connected to a reservation.
    """
    res = db.execute(
        select(Reservation).where(
            Reservation.id == invoice_in.reservation_id,
            Reservation.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not res:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reservation not found")

    org = db.execute(select(Organization).where(Organization.id == organization_id)).scalar_one_or_none()
    prop = res.property
    template = db.execute(
        select(DocumentTemplate).where(
            DocumentTemplate.organization_id == organization_id,
            DocumentTemplate.is_default == True
        )
    ).scalar_one_or_none()

    doc_type = invoice_in.document_type or "invoice"
    series_code = "QUO" if doc_type == "quotation" else "INV"
    invoice_no = get_next_sequence_number(db, organization_id, series_code)

    issue_d = date.today()
    due_d = invoice_in.due_date or (issue_d + timedelta(days=7))

    # Billing contact defaults to primary guest
    guest = res.primary_guest
    billing_name = invoice_in.billing_name or (f"{guest.first_name} {guest.last_name}" if guest else "Valued Guest")
    billing_email = invoice_in.billing_email or (guest.email if guest else None)
    billing_phone = invoice_in.billing_phone or (guest.phone if guest else None)

    invoice = Invoice(
        organization_id=organization_id,
        reservation_id=res.id,
        invoice_number=invoice_no,
        document_type=doc_type,
        status="draft",
        issue_date=issue_d,
        due_date=due_d,
        currency=invoice_in.currency or res.currency or "KES",
        supplier_name=org.name if org else "Ginata Hospitality",
        supplier_tax_pin=org.tax_id if (org and org.tax_id) else None,
        supplier_address=org.address if org else "P.O. Box 45000, Nairobi, Kenya",
        supplier_email=org.email if org else "concierge@ginata.co.ke",
        supplier_phone=org.phone if org else "+254 700 123 456",
        supplier_logo_url=org.logo_url or (template.logo_url if template else None),
        billing_name=billing_name,
        billing_email=billing_email,
        billing_phone=billing_phone,
        billing_company_name=invoice_in.billing_company_name,
        billing_company_pin=invoice_in.billing_company_pin,
        billing_company_address=invoice_in.billing_company_address,
        payment_terms=invoice_in.payment_terms or "Payment due within 7 days of invoice date.",
        payment_instructions=invoice_in.payment_instructions or (
            template.payment_instructions if template and template.payment_instructions else
            "M-Pesa Paybill: 247247 | Account: GINATA-STAY | Bank: KCB Bank, Forest Branch, A/C: 1122334455"
        ),
        notes=invoice_in.notes or f"Stay at {prop.name if prop else 'Ginata Estate'} for {res.number_of_nights} nights ({res.check_in_date} to {res.check_out_date}).",
        footer=invoice_in.footer or (template.footer_text if template and template.footer_text else "Thank you for staying with Ginata.")
    )
    db.add(invoice)
    db.flush()

    # Generate itemized line items:
    # 1. Accommodation nights
    line_items: List[InvoiceLineItem] = []
    pos = 0

    if invoice_in.line_items and len(invoice_in.line_items) > 0:
        for item_in in invoice_in.line_items:
            qty = Decimal(str(item_in.quantity))
            price = Decimal(str(item_in.unit_price))
            item_tax_rate = Decimal(str(item_in.tax_rate))
            disc = Decimal(str(item_in.discount_amount or Decimal("0.00")))
            sub = (qty * price) - disc
            tax_amt = (sub * item_tax_rate).quantize(Decimal("0.01"))
            total = sub + tax_amt
            li = InvoiceLineItem(
                invoice_id=invoice.id,
                position=pos,
                description=item_in.description,
                quantity=qty,
                unit_price=price,
                tax_rate=item_tax_rate,
                tax_amount=tax_amt,
                discount_amount=disc,
                total_amount=total
            )
            db.add(li)
            line_items.append(li)
            pos += 1
    else:
        # Default line items from reservation
        tax_rate = prop.tax_rate if prop else Decimal("0.1600")
        stay_desc = f"Accommodation: {prop.name if prop else 'Villa'} ({res.check_in_date} - {res.check_out_date})"
        stay_sub = Decimal(res.number_of_nights) * res.nightly_rate
        stay_tax = (stay_sub * tax_rate).quantize(Decimal("0.01"))
        stay_tot = stay_sub + stay_tax
        li_stay = InvoiceLineItem(
            invoice_id=invoice.id,
            position=pos,
            description=stay_desc,
            quantity=Decimal(res.number_of_nights),
            unit_price=res.nightly_rate,
            tax_rate=tax_rate,
            tax_amount=stay_tax,
            discount_amount=Decimal("0.00"),
            total_amount=stay_tot
        )
        db.add(li_stay)
        line_items.append(li_stay)
        pos += 1

        if res.cleaning_fee and res.cleaning_fee > 0:
            clean_tax = (res.cleaning_fee * tax_rate).quantize(Decimal("0.01"))
            li_clean = InvoiceLineItem(
                invoice_id=invoice.id,
                position=pos,
                description="Professional Cleaning & Turnover Fee",
                quantity=Decimal("1.00"),
                unit_price=res.cleaning_fee,
                tax_rate=tax_rate,
                tax_amount=clean_tax,
                discount_amount=Decimal("0.00"),
                total_amount=res.cleaning_fee + clean_tax
            )
            db.add(li_clean)
            line_items.append(li_clean)
            pos += 1

        if res.service_fee and res.service_fee > 0:
            svc_tax = (res.service_fee * tax_rate).quantize(Decimal("0.01"))
            li_svc = InvoiceLineItem(
                invoice_id=invoice.id,
                position=pos,
                description="Hospitality & Concierge Service Fee",
                quantity=Decimal("1.00"),
                unit_price=res.service_fee,
                tax_rate=tax_rate,
                tax_amount=svc_tax,
                discount_amount=Decimal("0.00"),
                total_amount=res.service_fee + svc_tax
            )
            db.add(li_svc)
            line_items.append(li_svc)
            pos += 1

        if res.discount_amount and res.discount_amount > 0:
            li_disc = InvoiceLineItem(
                invoice_id=invoice.id,
                position=pos,
                description="Special Stay Discount",
                quantity=Decimal("1.00"),
                unit_price=Decimal("0.00"),
                tax_rate=Decimal("0.00"),
                tax_amount=Decimal("0.00"),
                discount_amount=res.discount_amount,
                total_amount=-res.discount_amount
            )
            db.add(li_disc)
            line_items.append(li_disc)
            pos += 1

    # Recalculate invoice totals
    subtotal = Decimal("0.00")
    disc_total = Decimal("0.00")
    tax_total = Decimal("0.00")
    grand_total = Decimal("0.00")

    for li in line_items:
        subtotal += (li.quantity * li.unit_price)
        disc_total += li.discount_amount
        tax_total += li.tax_amount
        grand_total += li.total_amount

    invoice.subtotal = subtotal
    invoice.discount_total = disc_total
    invoice.tax_total = tax_total
    invoice.grand_total = grand_total
    invoice.amount_paid = res.amount_paid
    invoice.balance_due = max(Decimal("0.00"), grand_total - res.amount_paid)

    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="invoice",
        entity_id=invoice.id,
        action="created_invoice",
        actor_name=actor_name,
        details={"invoice_number": invoice.invoice_number, "grand_total": str(grand_total), "type": doc_type}
    )

    db.commit()
    db.refresh(invoice)
    return invoice


def update_invoice(
    db: Session,
    organization_id: str,
    invoice_id: str,
    update_in: InvoiceUpdate,
    actor_name: str = "Host Clara"
) -> Invoice:
    """Updates invoice line items and details if still in draft."""
    invoice = db.execute(
        select(Invoice).where(
            Invoice.id == invoice_id,
            Invoice.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invoice not found")

    if invoice.status == "issued" and not update_in.force_edit:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot directly edit an issued invoice without force_edit flag. Issue a credit note or create an amendment version."
        )

    if update_in.document_type:
        invoice.document_type = update_in.document_type
    if update_in.due_date:
        invoice.due_date = update_in.due_date
    if update_in.billing_name:
        invoice.billing_name = update_in.billing_name
    if update_in.billing_email:
        invoice.billing_email = update_in.billing_email
    if update_in.billing_phone:
        invoice.billing_phone = update_in.billing_phone
    if update_in.billing_company_name is not None:
        invoice.billing_company_name = update_in.billing_company_name
    if update_in.billing_company_pin is not None:
        invoice.billing_company_pin = update_in.billing_company_pin
    if update_in.billing_company_address is not None:
        invoice.billing_company_address = update_in.billing_company_address
    if update_in.payment_terms:
        invoice.payment_terms = update_in.payment_terms
    if update_in.payment_instructions:
        invoice.payment_instructions = update_in.payment_instructions
    if update_in.notes:
        invoice.notes = update_in.notes
    if update_in.footer:
        invoice.footer = update_in.footer

    # Update line items if provided
    if update_in.line_items is not None:
        # Delete existing line items
        for old_item in invoice.line_items:
            db.delete(old_item)
        db.flush()

        subtotal = Decimal("0.00")
        disc_total = Decimal("0.00")
        tax_total = Decimal("0.00")
        grand_total = Decimal("0.00")

        for pos, item_in in enumerate(update_in.line_items):
            qty = Decimal(str(item_in.quantity))
            price = Decimal(str(item_in.unit_price))
            item_tax_rate = Decimal(str(item_in.tax_rate))
            disc = Decimal(str(item_in.discount_amount or Decimal("0.00")))
            sub = (qty * price) - disc
            tax_amt = (sub * item_tax_rate).quantize(Decimal("0.01"))
            total = sub + tax_amt

            li = InvoiceLineItem(
                invoice_id=invoice.id,
                position=pos,
                description=item_in.description,
                quantity=qty,
                unit_price=price,
                tax_rate=item_tax_rate,
                tax_amount=tax_amt,
                discount_amount=disc,
                total_amount=total
            )
            db.add(li)
            subtotal += (qty * price)
            disc_total += disc
            tax_total += tax_amt
            grand_total += total

        invoice.subtotal = subtotal
        invoice.discount_total = disc_total
        invoice.tax_total = tax_total
        invoice.grand_total = grand_total
        invoice.balance_due = max(Decimal("0.00"), grand_total - invoice.amount_paid)

    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="invoice",
        entity_id=invoice.id,
        action="updated_invoice",
        actor_name=actor_name,
        details={"invoice_number": invoice.invoice_number, "grand_total": str(invoice.grand_total)}
    )

    db.commit()
    db.refresh(invoice)
    return invoice


def issue_invoice(
    db: Session,
    organization_id: str,
    invoice_id: str,
    actor_name: str = "Host Clara"
) -> Invoice:
    """Freezes invoice, marks status as 'issued', and records timestamp."""
    invoice = db.execute(
        select(Invoice).where(
            Invoice.id == invoice_id,
            Invoice.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invoice not found")

    invoice.status = "issued"
    invoice.issued_at = datetime.now(timezone.utc).replace(tzinfo=None)

    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="invoice",
        entity_id=invoice.id,
        action="issued_invoice",
        actor_name=actor_name,
        details={"invoice_number": invoice.invoice_number, "issued_at": str(invoice.issued_at)}
    )

    db.commit()
    db.refresh(invoice)
    return invoice


def create_credit_note(
    db: Session,
    organization_id: str,
    credit_in: CreditNoteCreate,
    actor_name: str = "Host Clara"
) -> CreditNote:
    """Issues a credit note against an invoice."""
    invoice = db.execute(
        select(Invoice).where(
            Invoice.id == credit_in.invoice_id,
            Invoice.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invoice not found")

    crn_number = get_next_sequence_number(db, organization_id, "CRN")
    cn = CreditNote(
        organization_id=organization_id,
        invoice_id=invoice.id,
        credit_note_number=crn_number,
        reason=credit_in.reason,
        amount=credit_in.amount,
        currency=credit_in.currency or invoice.currency,
        issued_at=datetime.now(timezone.utc).replace(tzinfo=None)
    )
    db.add(cn)

    # Adjust invoice balance
    invoice.grand_total = max(Decimal("0.00"), invoice.grand_total - credit_in.amount)
    invoice.balance_due = max(Decimal("0.00"), invoice.grand_total - invoice.amount_paid)

    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="credit_note",
        entity_id=cn.id,
        action="issued_credit_note",
        actor_name=actor_name,
        details={"credit_note_number": crn_number, "amount": str(credit_in.amount), "invoice_number": invoice.invoice_number}
    )

    db.commit()
    db.refresh(cn)
    return cn
