import re
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import MessageThread, Message, MessageTemplate
from backend.app.schemas.schemas import (
    MessageThreadResponse, MessageThreadCreate, MessageResponse, MessageCreate,
    MessageTemplateResponse, MessageTemplateCreate, MessageTemplateUpdate
)

router = APIRouter(prefix="/messages", tags=["Messages & Unified Inbox"])

_VARIABLE_RE = re.compile(r"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}")


def _extract_variables(body: str) -> List[str]:
    seen: List[str] = []
    for match in _VARIABLE_RE.findall(body or ""):
        key = match.strip()
        if key and key not in seen:
            seen.append(key)
    return seen


# Curated starter library seeded for a brand-new host. Written the way an
# experienced Airbnb host would phrase them, with {{placeholders}} the app can
# fill or the host can hand-edit after pasting.
DEFAULT_TEMPLATES: List[dict] = [
    {
        "title": "Booking Confirmation & Welcome",
        "category": "airbnb",
        "body": (
            "Hi {{guest_name}}! Thank you for booking {{property}}. We're thrilled to host you.\n\n"
            "Your stay is confirmed for {{check_in}} to {{check_out}} ({{nights}} nights, {{guests}} guests). "
            "Check-in is from {{check_in_time}} and check-out by {{check_out_time}}.\n\n"
            "I'll send full check-in instructions and the door code 2 days before arrival. "
            "If you have any questions in the meantime, just reply here. Safe travels!\n\n— {{host_name}}"
        ),
    },
    {
        "title": "Check-in Instructions & Door Code",
        "category": "airbnb",
        "body": (
            "Hello {{guest_name}}, we can't wait to welcome you to {{property}}!\n\n"
            "📍 Address: {{address}}\n"
            "🔑 Door code: {{door_code}}\n"
            "🕒 Check-in: any time after {{check_in_time}} on {{check_in}}\n\n"
            "Park in the marked bay, then let yourself in with the code above. "
            "The WiFi and house guide are on the fridge. Message me anytime — I'm a quick reply away.\n\n— {{host_name}}"
        ),
    },
    {
        "title": "WiFi & House Essentials",
        "category": "general",
        "body": (
            "Hi {{guest_name}}, here are the essentials for {{property}}:\n\n"
            "📶 WiFi network: {{wifi_name}}\n"
            "🔒 Password: {{wifi_password}}\n"
            "💧 Hot water & heating are pre-set — tell me if you'd like them adjusted.\n"
            "🗑 Bins go out on {{bin_day}}.\n\n"
            "Settle in and enjoy your stay!"
        ),
    },
    {
        "title": "House Rules Reminder",
        "category": "general",
        "body": (
            "Hi {{guest_name}}, a few friendly reminders for {{property}}:\n\n"
            "• No smoking indoors\n"
            "• No parties or unregistered visitors\n"
            "• Quiet hours 10pm–7am\n"
            "• Pets: {{pets_allowed}}\n\n"
            "Thanks for helping us keep the place lovely for everyone. Enjoy your stay!"
        ),
    },
    {
        "title": "Check-out Instructions",
        "category": "airbnb",
        "body": (
            "Good morning {{guest_name}}! We hope you had a wonderful stay at {{property}}.\n\n"
            "Check-out is by {{check_out_time}} today. Before you go:\n"
            "• Strip the beds & leave towels in the bathroom\n"
            "• Start the dishwasher / take out the trash\n"
            "• Turn off lights & A/C, and lock the door (code stays the same)\n\n"
            "Safe travels, and we'd love to host you again!"
        ),
    },
    {
        "title": "5-Star Review Request",
        "category": "airbnb",
        "body": (
            "Hi {{guest_name}}, thank you so much for staying at {{property}} — it was a pleasure hosting you!\n\n"
            "If you enjoyed your stay, a quick review really helps our small listing. "
            "I've left you a 5-star review too. 🌟\n\n"
            "You're always welcome back. Safe travels!\n\n— {{host_name}}"
        ),
    },
    {
        "title": "Arrival Time / ETA Request",
        "category": "booking_com",
        "body": (
            "Dear {{guest_name}}, thank you for your reservation at {{property}}.\n\n"
            "To make your arrival smooth, could you let us know your estimated arrival time? "
            "Standard check-in is from {{check_in_time}}. If you'll arrive late, just tell us and we'll leave instructions.\n\n"
            "Kind regards,\n{{host_name}}"
        ),
    },
    {
        "title": "Payment / Balance Reminder",
        "category": "whatsapp",
        "body": (
            "Hi {{guest_name}}, a friendly reminder that the balance of {{balance_due}} for your stay at {{property}} "
            "is due by {{due_date}}.\n\n"
            "You can pay via M-Pesa to {{mpesa_number}} ({{host_name}}). Once sent, reply with the transaction code "
            "and I'll issue your receipt right away. Thank you!"
        ),
    },
]


@router.get("/threads", response_model=List[MessageThreadResponse])
def list_message_threads(
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    threads = db.execute(
        select(MessageThread).where(
            MessageThread.organization_id == org_id
        ).order_by(MessageThread.last_message_at.desc())
    ).scalars().all()
    return threads


@router.post("/threads", response_model=MessageThreadResponse, status_code=status.HTTP_201_CREATED)
def create_message_thread(
    thread_in: MessageThreadCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    thread = MessageThread(
        organization_id=org_id,
        property_id=thread_in.property_id,
        reservation_id=thread_in.reservation_id,
        channel=thread_in.channel or "whatsapp",
        participant_name=thread_in.participant_name,
        participant_contact=thread_in.participant_contact,
        status="active"
    )
    db.add(thread)
    db.flush()

    if thread_in.initial_message:
        msg = Message(
            thread_id=thread.id,
            sender_type="host",
            sender_name="Host",
            content=thread_in.initial_message,
            is_read=True
        )
        db.add(msg)

    db.commit()
    db.refresh(thread)
    return thread


@router.get("/threads/{thread_id}/messages", response_model=List[MessageResponse])
def list_messages_in_thread(
    thread_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    thread = db.execute(
        select(MessageThread).where(
            MessageThread.id == thread_id,
            MessageThread.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not thread:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Thread not found")

    messages = db.execute(
        select(Message).where(Message.thread_id == thread_id).order_by(Message.created_at.asc())
    ).scalars().all()
    return messages


@router.post("/threads/{thread_id}/messages", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def send_message(
    thread_id: str,
    msg_in: MessageCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    thread = db.execute(
        select(MessageThread).where(
            MessageThread.id == thread_id,
            MessageThread.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not thread:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Thread not found")

    msg = Message(
        thread_id=thread.id,
        sender_type=msg_in.sender_type or "host",
        sender_name=msg_in.sender_name or "Host",
        content=msg_in.content,
        is_read=True
    )
    db.add(msg)
    thread.last_message_at = datetime.now(timezone.utc).replace(tzinfo=None)

    db.commit()
    db.refresh(msg)
    return msg


# ---------------------------------------------------------------------------
# Pre-built Message Templates (create / edit / copy / manage)
# ---------------------------------------------------------------------------
@router.get("/templates", response_model=List[MessageTemplateResponse])
def list_message_templates(
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    templates = db.execute(
        select(MessageTemplate).where(
            MessageTemplate.organization_id == org_id
        ).order_by(MessageTemplate.created_at.asc())
    ).scalars().all()
    return templates


@router.post("/templates/seed", response_model=List[MessageTemplateResponse])
def seed_message_templates(
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    """Seed the curated starter library. Only inserts when the org has none, so
    it is safe to call on every cold load and never clobbers host edits."""
    existing = db.execute(
        select(MessageTemplate.id).where(MessageTemplate.organization_id == org_id).limit(1)
    ).first()
    if existing is not None:
        return list_message_templates(db=db, org_id=org_id)

    for tpl in DEFAULT_TEMPLATES:
        db.add(MessageTemplate(
            organization_id=org_id,
            title=tpl["title"],
            category=tpl["category"],
            body=tpl["body"],
            variables=_extract_variables(tpl["body"]),
            is_active=True,
            use_count=0,
        ))
    db.commit()
    return list_message_templates(db=db, org_id=org_id)


@router.post("/templates", response_model=MessageTemplateResponse, status_code=status.HTTP_201_CREATED)
def create_message_template(
    tpl_in: MessageTemplateCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    template = MessageTemplate(
        organization_id=org_id,
        title=tpl_in.title.strip(),
        category=(tpl_in.category or "general").lower(),
        body=tpl_in.body,
        variables=tpl_in.variables if tpl_in.variables is not None else _extract_variables(tpl_in.body),
        is_active=tpl_in.is_active,
        use_count=0,
    )
    db.add(template)
    db.commit()
    db.refresh(template)
    return template


@router.put("/templates/{template_id}", response_model=MessageTemplateResponse)
def update_message_template(
    template_id: str,
    tpl_in: MessageTemplateUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    template = db.execute(
        select(MessageTemplate).where(
            MessageTemplate.id == template_id,
            MessageTemplate.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not template:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")

    if tpl_in.title is not None:
        template.title = tpl_in.title.strip()
    if tpl_in.category is not None:
        template.category = tpl_in.category.lower()
    if tpl_in.body is not None:
        template.body = tpl_in.body
        template.variables = _extract_variables(tpl_in.body)
    if tpl_in.variables is not None and tpl_in.body is None:
        template.variables = tpl_in.variables
    if tpl_in.is_active is not None:
        template.is_active = tpl_in.is_active

    db.commit()
    db.refresh(template)
    return template


@router.post("/templates/{template_id}/use", response_model=MessageTemplateResponse)
def mark_template_used(
    template_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    template = db.execute(
        select(MessageTemplate).where(
            MessageTemplate.id == template_id,
            MessageTemplate.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not template:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")

    template.use_count = (template.use_count or 0) + 1
    db.commit()
    db.refresh(template)
    return template


@router.delete("/templates/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_message_template(
    template_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    template = db.execute(
        select(MessageTemplate).where(
            MessageTemplate.id == template_id,
            MessageTemplate.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not template:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")

    db.delete(template)
    db.commit()
    return None
