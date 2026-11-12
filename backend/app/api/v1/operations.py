from datetime import date, datetime
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from pydantic import BaseModel, Field, EmailStr
from sqlalchemy import select, or_
from sqlalchemy.orm import Session
from backend.app.api.deps import get_current_org_id
from backend.app.core.database import get_db
from backend.app.models.models import Guest, Property, Reservation, OperationalTask
from backend.app.schemas.schemas import ReservationResponse
from backend.app.services.audit_service import log_audit_event

router = APIRouter(tags=["Guests and Operations"])


def owned(db, model, record_id, org_id):
    record = db.scalar(select(model).where(model.id == record_id, model.organization_id == org_id))
    if record is None:
        raise HTTPException(404, "Record not found")
    return record


def task_response(db, task):
    data = {column.name: getattr(task, column.name) for column in OperationalTask.__table__.columns if column.name != "organization_id"}
    prop = db.get(Property, task.property_id) if task.property_id else None
    data["property_name"] = prop.name if prop else None
    return data


class TaskCreate(BaseModel):
    property_id: str | None = None
    reservation_id: str | None = None
    kind: Literal["cleaning", "maintenance", "inspection", "restock", "other"] = "other"
    title: str = Field(min_length=1, max_length=255, pattern=r"\S")
    notes: str | None = Field(default=None, max_length=10000)
    priority: Literal["low", "normal", "high"] = "normal"
    status: Literal["open", "in_progress", "done"] = "open"
    due_date: date | None = None
    assignee: str | None = Field(default=None, max_length=200)


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255, pattern=r"\S")
    notes: str | None = Field(default=None, max_length=10000)
    priority: Literal["low", "normal", "high"] | None = None
    status: Literal["open", "in_progress", "done"] | None = None
    due_date: date | None = None
    assignee: str | None = Field(default=None, max_length=200)
    kind: Literal["cleaning", "maintenance", "inspection", "restock", "other"] | None = None


@router.get("/tasks/today")
def today_operations(db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    today = date.today()
    reservations = db.scalars(select(Reservation).where(Reservation.organization_id == org_id, Reservation.reservation_status.in_(["confirmed", "checked_in"]))).all()
    def encode(items):
        return [ReservationResponse.model_validate(item) for item in items]
    tasks = db.scalars(select(OperationalTask).where(OperationalTask.organization_id == org_id, OperationalTask.status != "done", or_(OperationalTask.due_date <= today, OperationalTask.due_date.is_(None))).order_by(OperationalTask.due_date, OperationalTask.created_at)).all()
    return {"date": today, "arrivals": encode([r for r in reservations if r.check_in_date == today]), "departures": encode([r for r in reservations if r.check_out_date == today]), "in_house": encode([r for r in reservations if r.reservation_status == "checked_in" or r.check_in_date <= today < r.check_out_date]), "tasks": [task_response(db, t) for t in tasks]}


@router.get("/tasks")
def list_tasks(status: str | None = None, kind: str | None = None, property_id: str | None = None, db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    query = select(OperationalTask).where(OperationalTask.organization_id == org_id)
    for name, value in (("status", status), ("kind", kind), ("property_id", property_id)):
        if value:
            query = query.where(getattr(OperationalTask, name) == value)
    return [task_response(db, t) for t in db.scalars(query.order_by(OperationalTask.due_date, OperationalTask.created_at.desc()))]


@router.post("/tasks", status_code=201)
def create_task(req: TaskCreate, db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    if req.property_id:
        owned(db, Property, req.property_id, org_id)
    if req.reservation_id:
        res = owned(db, Reservation, req.reservation_id, org_id)
        if req.property_id and req.property_id != res.property_id:
            raise HTTPException(400, "Reservation belongs to another property")
    task = OperationalTask(organization_id=org_id, **req.model_dump(), completed_at=datetime.utcnow() if req.status == "done" else None)
    db.add(task)
    db.commit()
    return task_response(db, task)


@router.patch("/tasks/{task_id}")
def update_task(task_id: str, req: TaskUpdate, db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    task = owned(db, OperationalTask, task_id, org_id)
    for name, value in req.model_dump(exclude_unset=True).items():
        if value is None and name in ("title", "priority", "status", "kind"):
            raise HTTPException(400, "Task fields cannot be cleared")
        setattr(task, name, value)
    if "status" in req.model_fields_set:
        task.completed_at = datetime.utcnow() if task.status == "done" else None
    db.commit()
    return task_response(db, task)


@router.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: str, db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    db.delete(owned(db, OperationalTask, task_id, org_id))
    db.commit()
    return Response(status_code=204)


@router.post("/reservations/{reservation_id}/check-in", response_model=ReservationResponse)
def check_in(reservation_id: str, db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    res = db.scalar(select(Reservation).where(Reservation.id == reservation_id, Reservation.organization_id == org_id).with_for_update())
    if not res:
        raise HTTPException(404, "Reservation not found")
    if res.reservation_status != "confirmed":
        raise HTTPException(409, "Only a confirmed reservation can be checked in")
    res.reservation_status, res.checked_in_at = "checked_in", datetime.utcnow()
    log_audit_event(db, org_id, "reservation", res.id, "checked_in", "Host", {})
    db.commit()
    return res


@router.post("/reservations/{reservation_id}/check-out", response_model=ReservationResponse)
def check_out(reservation_id: str, db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    res = db.scalar(select(Reservation).where(Reservation.id == reservation_id, Reservation.organization_id == org_id).with_for_update())
    if not res:
        raise HTTPException(404, "Reservation not found")
    if res.reservation_status not in ("confirmed", "checked_in"):
        raise HTTPException(409, "Only a confirmed or checked-in reservation can be checked out")
    res.reservation_status, res.checked_out_at = "checked_out", datetime.utcnow()
    existing = db.scalar(select(OperationalTask).where(OperationalTask.organization_id == org_id, OperationalTask.reservation_id == res.id, OperationalTask.source == "checkout"))
    if not existing:
        db.add(OperationalTask(organization_id=org_id, property_id=res.property_id, reservation_id=res.id, title=f"Clean {res.property.name}"[:255], kind="cleaning", source="checkout", due_date=date.today()))
    log_audit_event(db, org_id, "reservation", res.id, "checked_out", "Host", {})
    db.commit()
    return res


def guest_response(guest):
    active = [r for r in guest.reservations if r.reservation_status != "cancelled"]
    today = date.today()
    past = [r.check_in_date for r in active if r.check_in_date <= today]
    upcoming = [r.check_in_date for r in active if r.check_in_date > today]
    return {"id": guest.id, "full_name": f"{guest.first_name} {guest.last_name}".strip(), "email": guest.email, "phone": guest.phone, "stays_count": len(active), "last_stay_date": max(past) if past else None, "upcoming_stay_date": min(upcoming) if upcoming else None, "total_spent": sum(r.amount_paid for r in active)}


@router.get("/guests")
def list_guests(search: str = "", limit: int = Query(default=100, ge=1, le=500), db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    query = select(Guest).where(Guest.organization_id == org_id)
    if search:
        search = "%" + search[:200] + "%"
        query = query.where(or_(Guest.first_name.ilike(search), Guest.last_name.ilike(search), Guest.email.ilike(search), Guest.phone.ilike(search)))
    return [guest_response(g) for g in db.scalars(query.order_by(Guest.first_name, Guest.last_name).limit(limit))]


def guest_detail(guest):
    return {**guest_response(guest), "notes": guest.notes, "reservations": [{"id": r.id, "property_name": r.property.name, "check_in_date": r.check_in_date, "check_out_date": r.check_out_date, "reservation_status": r.reservation_status, "total_amount": r.total_amount, "booking_reference": r.booking_reference} for r in guest.reservations]}


@router.get("/guests/{guest_id}")
def get_guest(guest_id: str, db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    return guest_detail(owned(db, Guest, guest_id, org_id))


class GuestUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=200, pattern=r"\S")
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=50)
    notes: str | None = Field(default=None, max_length=10000)


@router.patch("/guests/{guest_id}")
def update_guest(guest_id: str, req: GuestUpdate, db: Session = Depends(get_db), org_id: str = Depends(get_current_org_id)):
    guest = owned(db, Guest, guest_id, org_id)
    for name, value in req.model_dump(exclude_unset=True).items():
        if name == "full_name" and value:
            parts = value.strip().split(" ", 1)
            guest.first_name, guest.last_name = parts[0], parts[1] if len(parts) > 1 else ""
        elif name != "full_name":
            setattr(guest, name, str(value) if value is not None else None)
    db.commit()
    return guest_detail(guest)
