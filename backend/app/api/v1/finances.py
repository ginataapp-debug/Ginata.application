from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, func

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import Expense, Property, Reservation
from backend.app.schemas.schemas import ExpenseResponse, ExpenseCreate, ExpenseUpdate
from backend.app.services.audit_service import log_audit_event

router = APIRouter(prefix="/finances", tags=["Finances & Expenses"])

@router.get("/expenses", response_model=List[ExpenseResponse])
def list_expenses(
    property_id: Optional[str] = None,
    category: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    query = select(Expense).where(Expense.organization_id == org_id)
    if property_id:
        query = query.where(Expense.property_id == property_id)
    if category:
        query = query.where(Expense.category == category)
    query = query.order_by(Expense.expense_date.desc(), Expense.created_at.desc())
    return db.execute(query).scalars().all()


@router.post("/expenses", response_model=ExpenseResponse, status_code=status.HTTP_201_CREATED)
def create_expense(
    expense_in: ExpenseCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    expense = Expense(
        organization_id=org_id,
        property_id=expense_in.property_id,
        reservation_id=expense_in.reservation_id,
        title=expense_in.title,
        category=expense_in.category,
        amount=expense_in.amount,
        currency=expense_in.currency or "KES",
        expense_date=expense_in.expense_date or date.today(),
        vendor_name=expense_in.vendor_name,
        receipt_reference=expense_in.receipt_reference,
        payment_method=expense_in.payment_method or "mpesa",
        notes=expense_in.notes
    )
    db.add(expense)
    db.flush()

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="expense",
        entity_id=expense.id,
        action="recorded_expense",
        actor_name="Host",
        details={"title": expense.title, "amount": str(expense.amount), "property_id": expense.property_id}
    )

    db.commit()
    db.refresh(expense)
    return expense


@router.patch("/expenses/{expense_id}", response_model=ExpenseResponse)
def update_expense(
    expense_id: str,
    expense_in: ExpenseUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    expense = db.execute(
        select(Expense).where(Expense.id == expense_id, Expense.organization_id == org_id)
    ).scalar_one_or_none()
    if not expense:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expense not found")

    if expense_in.property_id is not None: expense.property_id = expense_in.property_id
    if expense_in.title is not None: expense.title = expense_in.title
    if expense_in.category is not None: expense.category = expense_in.category
    if expense_in.amount is not None: expense.amount = expense_in.amount
    if expense_in.expense_date is not None: expense.expense_date = expense_in.expense_date
    if expense_in.vendor_name is not None: expense.vendor_name = expense_in.vendor_name
    if expense_in.receipt_reference is not None: expense.receipt_reference = expense_in.receipt_reference
    if expense_in.payment_method is not None: expense.payment_method = expense_in.payment_method
    if expense_in.notes is not None: expense.notes = expense_in.notes

    db.commit()
    db.refresh(expense)
    return expense


@router.delete("/expenses/{expense_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_expense(
    expense_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    expense = db.execute(
        select(Expense).where(Expense.id == expense_id, Expense.organization_id == org_id)
    ).scalar_one_or_none()
    if not expense:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expense not found")

    db.delete(expense)
    db.commit()
    return None


@router.get("/summary")
def get_financial_summary(
    property_id: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    """Provides high-level revenue, expenses, agent commissions, and net profit per house."""
    # Reservations revenue
    res_query = select(
        func.coalesce(func.sum(Reservation.total_amount), 0).label("gross_revenue"),
        func.coalesce(func.sum(Reservation.amount_paid), 0).label("collected_revenue"),
        func.coalesce(func.sum(Reservation.balance_due), 0).label("pending_balance"),
        func.coalesce(func.sum(Reservation.agent_commission_amount), 0).label("total_agent_commissions"),
        func.coalesce(func.sum(Reservation.net_host_amount), 0).label("net_revenue_after_agent"),
    ).where(
        Reservation.organization_id == org_id,
        Reservation.reservation_status != "cancelled"
    )
    if property_id:
        res_query = res_query.where(Reservation.property_id == property_id)

    res_res = db.execute(res_query).one()

    # Expenses
    exp_query = select(
        func.coalesce(func.sum(Expense.amount), 0).label("total_expenses")
    ).where(Expense.organization_id == org_id)
    if property_id:
        exp_query = exp_query.where(Expense.property_id == property_id)

    exp_res = db.execute(exp_query).scalar_one()

    gross_rev = float(res_res.gross_revenue)
    collected = float(res_res.collected_revenue)
    pending = float(res_res.pending_balance)
    agent_comm = float(res_res.total_agent_commissions)
    total_exp = float(exp_res)
    net_operating_profit = gross_rev - agent_comm - total_exp

    return {
        "currency": "KES",
        "gross_revenue": gross_rev,
        "collected_revenue": collected,
        "pending_balance": pending,
        "total_agent_commissions": agent_comm,
        "total_expenses": total_exp,
        "net_operating_profit": net_operating_profit,
    }


@router.get("/expenses/export")
def export_expenses_csv(
    property_id: Optional[str] = None,
    category: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    """Exports expenses ledger as CSV spreadsheet file."""
    import io
    import csv
    from fastapi.responses import Response

    query = select(Expense, Property.name.label("property_name")).outerjoin(
        Property, Expense.property_id == Property.id
    ).where(Expense.organization_id == org_id)

    if property_id:
        query = query.where(Expense.property_id == property_id)
    if category:
        query = query.where(Expense.category == category)
    query = query.order_by(Expense.expense_date.desc())

    records = db.execute(query).all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Expense ID", "Date", "Property", "Category", "Title / Description",
        "Amount (KES)", "Vendor / Fundi", "Receipt / Reference", "Payment Method", "Notes"
    ])

    for row in records:
        exp = row[0]
        prop_name = row[1] or "General"
        writer.writerow([
            exp.id,
            str(exp.expense_date),
            prop_name,
            exp.category,
            exp.title,
            f"{float(exp.amount):.2f}",
            exp.vendor_name or "",
            exp.receipt_reference or "",
            exp.payment_method or "",
            exp.notes or ""
        ])

    csv_data = output.getvalue()
    return Response(
        content=csv_data,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=ginata_expenses_{date.today().isoformat()}.csv"}
    )
