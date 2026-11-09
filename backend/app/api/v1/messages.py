from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import MessageThread, Message
from backend.app.schemas.schemas import (
    MessageThreadResponse, MessageThreadCreate, MessageResponse, MessageCreate
)

router = APIRouter(prefix="/messages", tags=["Messages & Unified Inbox"])

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
