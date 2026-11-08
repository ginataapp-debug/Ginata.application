import os
import io
import csv
from datetime import datetime, date
from decimal import Decimal
from pathlib import Path
from typing import Optional, Tuple

import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage, KeepTogether, HRFlowable
)

from backend.app.core.config import settings
from backend.app.models.models import Invoice, Receipt, Reservation, DocumentTemplate

# Color definitions
FOREST_GREEN = colors.HexColor("#003329")
SAGE_GREEN = colors.HexColor("#466557")
WARM_CREAM = colors.HexColor("#FDF9F2")
CHARCOAL = colors.HexColor("#1C1C18")
MUTED_GRAY = colors.HexColor("#707975")
LIGHT_BG = colors.HexColor("#F7F3EC")
BORDER_COLOR = colors.HexColor("#E6E2DB")
WHITE = colors.HexColor("#FFFFFF")

def format_kes(amount: Decimal, currency: str = "KES") -> str:
    """Formats decimal amount into readable currency string (e.g. KES 15,000.00)."""
    return f"{currency} {amount:,.2f}"


def get_logo_path(custom_logo_url: Optional[str] = None) -> Optional[str]:
    """Finds valid logo file path."""
    if custom_logo_url and os.path.exists(custom_logo_url):
        return custom_logo_url
    static_logo = settings.STATIC_DIR / "logo.png"
    if static_logo.exists():
        return str(static_logo)
    root_logo = settings.BASE_DIR.parent / "Ginata App Logo.png"
    if root_logo.exists():
        return str(root_logo)
    return None


def generate_invoice_pdf(
    invoice: Invoice,
    output_path: Optional[str] = None
) -> bytes:
    """
    Generates a professional PDF for an Invoice, Pro Forma, or Quotation using ReportLab.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer if output_path is None else output_path,
        pagesize=A4,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )

    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        "DocTitle",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=20,
        leading=24,
        textColor=FOREST_GREEN
    )
    subtitle_style = ParagraphStyle(
        "DocSubtitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=10,
        leading=13,
        textColor=SAGE_GREEN
    )
    body_style = ParagraphStyle(
        "DocBody",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=13,
        textColor=CHARCOAL
    )
    body_bold = ParagraphStyle(
        "DocBodyBold",
        parent=body_style,
        fontName="Helvetica-Bold"
    )
    table_header = ParagraphStyle(
        "TableHeader",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=11,
        textColor=WHITE
    )
    table_cell = ParagraphStyle(
        "TableCell",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8.5,
        leading=11,
        textColor=CHARCOAL
    )
    table_cell_bold = ParagraphStyle(
        "TableCellBold",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=8.5,
        leading=11,
        textColor=CHARCOAL
    )

    story = []

    # 1. Header with Logo & Document Identification
    logo_path = get_logo_path(invoice.supplier_logo_url)
    logo_flowable = Paragraph(f"<b>{invoice.supplier_name}</b>", title_style)
    if logo_path:
        try:
            logo_flowable = RLImage(logo_path, width=120, height=45)
        except Exception:
            pass

    doc_label = "TAX INVOICE"
    if invoice.document_type == "pro_forma":
        doc_label = "PRO FORMA INVOICE"
    elif invoice.document_type == "quotation":
        doc_label = "PRICE QUOTATION"

    header_table_data = [
        [
            logo_flowable,
            [
                Paragraph(doc_label, title_style),
                Paragraph(f"<b>No:</b> {invoice.invoice_number}", subtitle_style),
                Paragraph(f"<b>Date:</b> {invoice.issue_date.strftime('%d %b %Y')}", body_style),
                Paragraph(f"<b>Due:</b> {invoice.due_date.strftime('%d %b %Y')}", body_style),
                Paragraph(f"<b>Status:</b> {invoice.status.upper()}", subtitle_style),
            ]
        ]
    ]
    header_table = Table(header_table_data, colWidths=[300, 220])
    header_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 15))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=15))

    # 2. Supplier & Guest / Company Billing Details
    supplier_lines = [
        Paragraph("<b>ISSUED BY (HOST)</b>", subtitle_style),
        Paragraph(invoice.supplier_name, body_bold),
        Paragraph(invoice.supplier_address or "Kenya", body_style),
        Paragraph(f"Email: {invoice.supplier_email or 'concierge@ginata.co.ke'}", body_style),
        Paragraph(f"Phone: {invoice.supplier_phone or '+254 700 000 000'}", body_style),
    ]

    billing_lines = [
        Paragraph("<b>BILLED TO (GUEST)</b>", subtitle_style),
        Paragraph(invoice.billing_name, body_bold),
    ]
    if invoice.billing_company_name:
        billing_lines.append(Paragraph(f"<b>Company:</b> {invoice.billing_company_name}", body_bold))
        if invoice.billing_company_address:
            billing_lines.append(Paragraph(invoice.billing_company_address, body_style))
    if invoice.billing_email:
        billing_lines.append(Paragraph(f"Email: {invoice.billing_email}", body_style))
    if invoice.billing_phone:
        billing_lines.append(Paragraph(f"Phone: {invoice.billing_phone}", body_style))

    parties_table = Table([[supplier_lines, billing_lines]], colWidths=[260, 260])
    parties_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BACKGROUND', (0, 0), (-1, -1), LIGHT_BG),
        ('BOX', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0, 0), (-1, -1), 8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
    ]))
    story.append(parties_table)
    story.append(Spacer(1, 15))

    # 3. Reservation Details Card
    res = invoice.reservation
    prop_name = res.property.name if res and res.property else "Ginata Luxury Villa"
    dates_desc = f"{res.check_in_date.strftime('%d %b %Y')} to {res.check_out_date.strftime('%d %b %Y')} ({res.number_of_nights} nights • {res.number_of_guests} guests)" if res else "Stay Details"
    
    res_table = Table([
        [
            Paragraph("<b>Reservation Reference:</b>", body_bold),
            Paragraph(res.booking_reference or res.id[:8] if res else "DIRECT", body_style),
            Paragraph("<b>Property:</b>", body_bold),
            Paragraph(prop_name, body_style)
        ],
        [
            Paragraph("<b>Stay Duration:</b>", body_bold),
            Paragraph(dates_desc, body_style),
            Paragraph("<b>Booking Source:</b>", body_bold),
            Paragraph((res.booking_source or "Direct").upper() if res else "DIRECT", body_style)
        ]
    ], colWidths=[130, 150, 100, 140])
    res_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), WARM_CREAM),
        ('BOX', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(res_table)
    story.append(Spacer(1, 15))

    # 4. Itemized Line Items Table
    headers = [
        Paragraph("#", table_header),
        Paragraph("Description", table_header),
        Paragraph("Qty", table_header),
        Paragraph("Unit Price", table_header),
        Paragraph("Tax", table_header),
        Paragraph("Total", table_header)
    ]
    items_data = [headers]

    for idx, li in enumerate(invoice.line_items, start=1):
        items_data.append([
            Paragraph(str(idx), table_cell),
            Paragraph(li.description, table_cell_bold),
            Paragraph(f"{li.quantity:,.0f}", table_cell),
            Paragraph(format_kes(li.unit_price, invoice.currency), table_cell),
            Paragraph(format_kes(li.tax_amount, invoice.currency), table_cell),
            Paragraph(format_kes(li.total_amount, invoice.currency), table_cell_bold)
        ])

    items_table = Table(items_data, colWidths=[25, 235, 45, 75, 65, 75])
    items_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), FOREST_GREEN),
        ('ALIGN', (0, 0), (-1, 0), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('BOX', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [WHITE, LIGHT_BG]),
    ]))
    story.append(items_table)
    story.append(Spacer(1, 12))

    # 5. Financial Totals Table
    totals_data = [
        [Paragraph("<b>Subtotal:</b>", body_style), Paragraph(format_kes(invoice.subtotal, invoice.currency), body_style)],
        [Paragraph("<b>VAT / Taxes:</b>", body_style), Paragraph(format_kes(invoice.tax_total, invoice.currency), body_style)],
    ]
    if invoice.discount_total > 0:
        totals_data.append([
            Paragraph("<b>Discount:</b>", body_style),
            Paragraph(f"-{format_kes(invoice.discount_total, invoice.currency)}", body_style)
        ])
    totals_data.append([
        Paragraph("<b>Grand Total:</b>", body_bold),
        Paragraph(format_kes(invoice.grand_total, invoice.currency), body_bold)
    ])
    totals_data.append([
        Paragraph("<b>Payments Received:</b>", body_style),
        Paragraph(format_kes(invoice.amount_paid, invoice.currency), body_style)
    ])
    totals_data.append([
        Paragraph("<b>Balance Outstanding:</b>", title_style),
        Paragraph(format_kes(invoice.balance_due, invoice.currency), title_style)
    ])

    totals_table = Table(totals_data, colWidths=[150, 120])
    totals_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'RIGHT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))

    # Wrap totals with layout align right
    align_table = Table([["", totals_table]], colWidths=[250, 270])
    align_table.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP')]))
    story.append(align_table)
    story.append(Spacer(1, 15))

    # 6. Payment Instructions & Footer
    instructions_block = []
    if invoice.payment_instructions:
        instructions_block.append(Paragraph("<b>PAYMENT INSTRUCTIONS</b>", subtitle_style))
        instructions_block.append(Paragraph(invoice.payment_instructions, body_style))
        instructions_block.append(Spacer(1, 4))
    if invoice.payment_terms:
        instructions_block.append(Paragraph(f"<b>Terms:</b> {invoice.payment_terms}", body_style))
    if invoice.notes:
        instructions_block.append(Paragraph(f"<b>Notes:</b> {invoice.notes}", body_style))
    if invoice.footer:
        instructions_block.append(Spacer(1, 6))
        instructions_block.append(Paragraph(f"<i>{invoice.footer}</i>", body_style))

    if instructions_block:
        instr_table = Table([[instructions_block]], colWidths=[520])
        instr_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), LIGHT_BG),
            ('BOX', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
            ('TOPPADDING', (0, 0), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ('LEFTPADDING', (0, 0), (-1, -1), 10),
            ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ]))
        story.append(KeepTogether(instr_table))

    doc.build(story)
    pdf_bytes = buffer.getvalue()
    buffer.close()

    if output_path:
        with open(output_path, "wb") as f:
            f.write(pdf_bytes)

    return pdf_bytes


def generate_receipt_pdf(
    receipt: Receipt,
    output_path: Optional[str] = None
) -> bytes:
    """
    Generates an official Payment Receipt PDF using ReportLab.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer if output_path is None else output_path,
        pagesize=A4,
        rightMargin=40,
        leftMargin=40,
        topMargin=40,
        bottomMargin=40
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "RecTitle",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=20,
        leading=24,
        textColor=FOREST_GREEN
    )
    subtitle_style = ParagraphStyle(
        "RecSub",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=11,
        leading=14,
        textColor=SAGE_GREEN
    )
    body_style = ParagraphStyle(
        "RecBody",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9.5,
        leading=14,
        textColor=CHARCOAL
    )
    body_bold = ParagraphStyle(
        "RecBodyBold",
        parent=body_style,
        fontName="Helvetica-Bold"
    )
    big_amount = ParagraphStyle(
        "RecBigAmt",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=22,
        leading=26,
        textColor=FOREST_GREEN
    )

    story = []

    # Header with Logo
    logo_path = get_logo_path()
    logo_flowable = Paragraph("<b>GINATA PROPERTY MANAGEMENT</b>", title_style)
    if logo_path:
        try:
            logo_flowable = RLImage(logo_path, width=120, height=45)
        except Exception:
            pass

    header_table = Table([
        [
            logo_flowable,
            [
                Paragraph("OFFICIAL RECEIPT", title_style),
                Paragraph(f"<b>Receipt No:</b> {receipt.receipt_number}", subtitle_style),
                Paragraph(f"<b>Date:</b> {receipt.receipt_date.strftime('%d %b %Y')}", body_style),
            ]
        ]
    ], colWidths=[280, 230])
    header_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 15))
    story.append(HRFlowable(width="100%", thickness=1.5, color=FOREST_GREEN, spaceBefore=0, spaceAfter=20))

    # Amount Received Callout Box
    amt_box = Table([
        [
            [
                Paragraph("AMOUNT RECEIVED", subtitle_style),
                Paragraph(format_kes(receipt.amount_received, receipt.currency), big_amount)
            ]
        ]
    ], colWidths=[510])
    amt_box.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), LIGHT_BG),
        ('BOX', (0, 0), (-1, -1), 1, SAGE_GREEN),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 12),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
        ('LEFTPADDING', (0, 0), (-1, -1), 20),
    ]))
    story.append(amt_box)
    story.append(Spacer(1, 20))

    # Receipt Metadata Table
    payment = receipt.payment
    tx_ref = receipt.transaction_reference or (payment.transaction_reference if payment else "N/A")
    res = payment.reservation if payment else None
    prop_name = res.property.name if res and res.property else "Ginata Property"

    details_data = [
        [Paragraph("<b>Received From:</b>", body_bold), Paragraph(receipt.issued_to_name, body_style)],
        [Paragraph("<b>Payment Method:</b>", body_bold), Paragraph(receipt.payment_method.upper(), body_style)],
        [Paragraph("<b>Transaction Ref:</b>", body_bold), Paragraph(tx_ref, body_style)],
        [Paragraph("<b>Payment For:</b>", body_bold), Paragraph(f"Stay at {prop_name} (Ref: {res.booking_reference if res else 'N/A'})", body_style)],
        [Paragraph("<b>Verification:</b>", body_bold), Paragraph("VERIFIED (Recorded by Authorized Host)" if payment and not payment.is_verified else "AUTOMATED VERIFIED", body_style)],
        [Paragraph("<b>Remaining Balance:</b>", body_bold), Paragraph(format_kes(receipt.remaining_balance, receipt.currency), body_bold)],
        [Paragraph("<b>Issued By:</b>", body_bold), Paragraph(receipt.issued_by_name, body_style)],
    ]

    details_table = Table(details_data, colWidths=[150, 360])
    details_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOX', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
        ('ROWBACKGROUNDS', (0, 0), (-1, -1), [WHITE, WARM_CREAM]),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
    ]))
    story.append(details_table)
    story.append(Spacer(1, 30))

    # Signature / Verification Seal
    seal_data = [
        [
            Paragraph("<b>Official Digital Seal</b><br/>Ginata Property Management<br/>Nairobi, Kenya", body_style),
            Paragraph(f"<b>Authorized Signature:</b><br/><i>{receipt.issued_by_name}</i><br/>Ginata Concierge Operations", body_style)
        ]
    ]
    seal_table = Table(seal_data, colWidths=[255, 255])
    seal_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
    ]))
    story.append(seal_table)

    doc.build(story)
    pdf_bytes = buffer.getvalue()
    buffer.close()

    if output_path:
        with open(output_path, "wb") as f:
            f.write(pdf_bytes)

    return pdf_bytes


def generate_invoice_docx(
    invoice: Invoice,
    output_path: Optional[str] = None
) -> bytes:
    """
    Generates a structured, editable Microsoft Word (.docx) document for an Invoice using python-docx.
    Allows recipients to edit or insert company logos.
    """
    doc = docx.Document()

    # Page margins
    for section in doc.sections:
        section.top_margin = Inches(0.5)
        section.bottom_margin = Inches(0.5)
        section.left_margin = Inches(0.5)
        section.right_margin = Inches(0.5)

    # Document Header Title
    doc_label = "TAX INVOICE"
    if invoice.document_type == "pro_forma":
        doc_label = "PRO FORMA INVOICE"
    elif invoice.document_type == "quotation":
        doc_label = "PRICE QUOTATION"

    h1 = doc.add_heading(doc_label, level=1)
    for run in h1.runs:
        run.font.name = "Arial"
        run.font.size = Pt(20)
        run.font.color.rgb = RGBColor(0x00, 0x33, 0x29)  # Forest Green

    # Invoice Meta
    p_meta = doc.add_paragraph()
    p_meta.add_run(f"Invoice Number: {invoice.invoice_number}\n").bold = True
    p_meta.add_run(f"Issue Date: {invoice.issue_date.strftime('%d %B %Y')}\n")
    p_meta.add_run(f"Due Date: {invoice.due_date.strftime('%d %B %Y')}\n")
    p_meta.add_run(f"Status: {invoice.status.upper()}")

    # Supplier & Customer Tables
    table_parties = doc.add_table(rows=1, cols=2)
    table_parties.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell_sup, cell_cust = table_parties.rows[0].cells

    p_sup = cell_sup.paragraphs[0]
    p_sup.add_run("ISSUER / HOST:\n").bold = True
    p_sup.add_run(f"{invoice.supplier_name}\n")
    if invoice.supplier_address:
        p_sup.add_run(f"{invoice.supplier_address}\n")
    if invoice.supplier_email:
        p_sup.add_run(f"Email: {invoice.supplier_email}\n")
    if invoice.supplier_phone:
        p_sup.add_run(f"Phone: {invoice.supplier_phone}\n")

    p_cust = cell_cust.paragraphs[0]
    p_cust.add_run("BILLED TO:\n").bold = True
    p_cust.add_run(f"{invoice.billing_name}\n")
    if invoice.billing_company_name:
        p_cust.add_run(f"Company: {invoice.billing_company_name}\n").bold = True
        if invoice.billing_company_pin:
            p_cust.add_run(f"Company Tax PIN: {invoice.billing_company_pin}\n")
        if invoice.billing_company_address:
            p_cust.add_run(f"{invoice.billing_company_address}\n")
    if invoice.billing_email:
        p_cust.add_run(f"Email: {invoice.billing_email}\n")
    if invoice.billing_phone:
        p_cust.add_run(f"Phone: {invoice.billing_phone}\n")

    doc.add_paragraph()  # spacer

    # Itemized Table
    table_items = doc.add_table(rows=1, cols=6)
    table_items.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr_cells = table_items.rows[0].cells
    hdr_titles = ["#", "Description", "Qty", "Unit Price", "Tax", "Total"]
    for i, title in enumerate(hdr_titles):
        hdr_cells[i].text = title
        hdr_cells[i].paragraphs[0].runs[0].bold = True

    for idx, li in enumerate(invoice.line_items, start=1):
        row_cells = table_items.add_row().cells
        row_cells[0].text = str(idx)
        row_cells[1].text = li.description
        row_cells[2].text = f"{li.quantity:,.0f}"
        row_cells[3].text = format_kes(li.unit_price, invoice.currency)
        row_cells[4].text = format_kes(li.tax_amount, invoice.currency)
        row_cells[5].text = format_kes(li.total_amount, invoice.currency)

    doc.add_paragraph()  # spacer

    # Totals
    p_tot = doc.add_paragraph()
    p_tot.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p_tot.add_run(f"Subtotal: {format_kes(invoice.subtotal, invoice.currency)}\n")
    p_tot.add_run(f"Taxes / VAT: {format_kes(invoice.tax_total, invoice.currency)}\n")
    if invoice.discount_total > 0:
        p_tot.add_run(f"Discounts: -{format_kes(invoice.discount_total, invoice.currency)}\n")
    p_tot.add_run(f"Grand Total: {format_kes(invoice.grand_total, invoice.currency)}\n").bold = True
    p_tot.add_run(f"Amount Paid: {format_kes(invoice.amount_paid, invoice.currency)}\n")
    p_tot.add_run(f"Balance Outstanding: {format_kes(invoice.balance_due, invoice.currency)}\n").bold = True

    # Payment Instructions
    if invoice.payment_instructions:
        p_inst = doc.add_paragraph()
        p_inst.add_run("Payment Instructions:\n").bold = True
        p_inst.add_run(invoice.payment_instructions)

    if invoice.notes:
        p_notes = doc.add_paragraph()
        p_notes.add_run("Notes:\n").bold = True
        p_notes.add_run(invoice.notes)

    buffer = io.BytesIO()
    doc.save(buffer)
    docx_bytes = buffer.getvalue()
    buffer.close()

    if output_path:
        with open(output_path, "wb") as f:
            f.write(docx_bytes)

    return docx_bytes


def generate_invoice_csv(invoice: Invoice) -> str:
    """
    Generates structured CSV export of invoice line items and totals.
    """
    output = io.StringIO()
    writer = csv.writer(output)

    # Header metadata
    writer.writerow(["Ginata Property Management - Invoice Export"])
    writer.writerow(["Invoice Number", invoice.invoice_number])
    writer.writerow(["Document Type", invoice.document_type])
    writer.writerow(["Issue Date", invoice.issue_date.isoformat()])
    writer.writerow(["Due Date", invoice.due_date.isoformat()])
    writer.writerow(["Supplier", invoice.supplier_name])
    writer.writerow(["Billed To", invoice.billing_name])
    if invoice.billing_company_name:
        writer.writerow(["Company", invoice.billing_company_name])
    writer.writerow(["Currency", invoice.currency])
    writer.writerow([])

    # Table
    writer.writerow(["Position", "Description", "Quantity", "Unit Price", "Tax Amount", "Discount Amount", "Total Amount"])
    for li in invoice.line_items:
        writer.writerow([
            li.position + 1,
            li.description,
            str(li.quantity),
            str(li.unit_price),
            str(li.tax_amount),
            str(li.discount_amount),
            str(li.total_amount)
        ])

    writer.writerow([])
    writer.writerow(["Subtotal", str(invoice.subtotal)])
    writer.writerow(["Tax Total", str(invoice.tax_total)])
    writer.writerow(["Discount Total", str(invoice.discount_total)])
    writer.writerow(["Grand Total", str(invoice.grand_total)])
    writer.writerow(["Amount Paid", str(invoice.amount_paid)])
    writer.writerow(["Balance Due", str(invoice.balance_due)])

    return output.getvalue()
