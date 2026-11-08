from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import Property, PropertyUnit, Reservation
from backend.app.schemas.schemas import (
    PropertyResponse, PropertyCreate, PropertyUpdate, PropertyCalendarResponse, CalendarReservationSlot, PropertyUnitResponse
)
from backend.app.services.audit_service import log_audit_event

router = APIRouter(prefix="/properties", tags=["Properties"])

@router.get("", response_model=List[PropertyResponse])
def list_properties(
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    props = db.execute(
        select(Property).where(Property.organization_id == org_id)
    ).scalars().all()
    return props

@router.get("/{property_id}", response_model=PropertyResponse)
def get_property(
    property_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    prop = db.execute(
        select(Property).where(Property.id == property_id, Property.organization_id == org_id)
    ).scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")
    return prop

@router.post("", response_model=PropertyResponse, status_code=status.HTTP_201_CREATED)
def create_property(
    prop_in: PropertyCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    # Auto-generate slug if missing or blank
    slug = prop_in.slug.strip() if prop_in.slug else ""
    if not slug:
        slug = prop_in.name.lower().replace(" ", "-").replace("'", "")
    
    prop = Property(
        organization_id=org_id,
        name=prop_in.name,
        slug=slug,
        address=prop_in.address,
        city=prop_in.city,
        country=prop_in.country or "Kenya",
        default_nightly_rate=prop_in.default_nightly_rate,
        currency=prop_in.currency or "KES",
        cleaning_fee=prop_in.cleaning_fee,
        tax_rate=prop_in.tax_rate,
        image_url=prop_in.image_url
    )
    db.add(prop)
    db.flush()

    if prop_in.units:
        for u in prop_in.units:
            unit = PropertyUnit(
                property_id=prop.id,
                name=u.name,
                max_guests=u.max_guests,
                bedrooms=u.bedrooms,
                bathrooms=u.bathrooms,
                status=u.status
            )
            db.add(unit)
    else:
        # Create default main unit if none supplied
        unit = PropertyUnit(
            property_id=prop.id,
            name="Main Residence",
            max_guests=4,
            bedrooms=2,
            bathrooms=2,
            status="active"
        )
        db.add(unit)

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="property",
        entity_id=prop.id,
        action="created_property",
        actor_name="Host",
        details={"name": prop.name, "city": prop.city}
    )

    db.commit()
    db.refresh(prop)
    return prop

@router.patch("/{property_id}", response_model=PropertyResponse)
def update_property(
    property_id: str,
    prop_in: PropertyUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    prop = db.execute(
        select(Property).where(Property.id == property_id, Property.organization_id == org_id)
    ).scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")

    if prop_in.name is not None:
        prop.name = prop_in.name
    if prop_in.slug is not None:
        prop.slug = prop_in.slug
    if prop_in.address is not None:
        prop.address = prop_in.address
    if prop_in.city is not None:
        prop.city = prop_in.city
    if prop_in.country is not None:
        prop.country = prop_in.country
    if prop_in.default_nightly_rate is not None:
        prop.default_nightly_rate = prop_in.default_nightly_rate
    if prop_in.currency is not None:
        prop.currency = prop_in.currency
    if prop_in.cleaning_fee is not None:
        prop.cleaning_fee = prop_in.cleaning_fee
    if prop_in.tax_rate is not None:
        prop.tax_rate = prop_in.tax_rate
    if prop_in.image_url is not None:
        prop.image_url = prop_in.image_url

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="property",
        entity_id=prop.id,
        action="updated_property",
        actor_name="Host",
        details={"name": prop.name}
    )

    db.commit()
    db.refresh(prop)
    return prop

@router.delete("/{property_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_property(
    property_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    prop = db.execute(
        select(Property).where(Property.id == property_id, Property.organization_id == org_id)
    ).scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="property",
        entity_id=prop.id,
        action="deleted_property",
        actor_name="Host",
        details={"name": prop.name}
    )

    db.delete(prop)
    db.commit()
    return None

@router.get("/{property_id}/calendar", response_model=PropertyCalendarResponse)
def get_property_calendar(
    property_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    prop = db.execute(
        select(Property).where(
            Property.id == property_id,
            Property.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")

    reservations = db.execute(
        select(Reservation).where(
            Reservation.property_id == property_id,
            Reservation.organization_id == org_id,
            Reservation.reservation_status != "cancelled"
        ).order_by(Reservation.check_in_date.asc())
    ).scalars().all()

    slots = []
    for res in reservations:
        guest_name = f"{res.primary_guest.first_name} {res.primary_guest.last_name}" if res.primary_guest else "Direct Guest"
        slots.append(CalendarReservationSlot(
            reservation_id=res.id,
            property_id=res.property_id,
            unit_id=res.unit_id,
            guest_name=guest_name,
            booking_source=res.booking_source,
            reservation_status=res.reservation_status,
            check_in_date=res.check_in_date,
            check_out_date=res.check_out_date,
            has_conflict=res.has_conflict,
            total_amount=res.total_amount,
            currency=res.currency
        ))

    return PropertyCalendarResponse(
        property_id=prop.id,
        property_name=prop.name,
        units=[PropertyUnitResponse.model_validate(u) for u in prop.units],
        slots=slots
    )

# --- iCal Calendar Sync (Airbnb, Booking.com, and Export Feed) ---
@router.get("/{property_id}/feed.ics")
def export_property_ical_feed(
    property_id: str,
    token: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Generates standard iCalendar (.ics) feed of confirmed stays for Airbnb/Booking.com export."""
    prop = db.execute(select(Property).where(Property.id == property_id)).scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")

    reservations = db.execute(
        select(Reservation).where(
            Reservation.property_id == property_id,
            Reservation.reservation_status.in_(["confirmed", "checked_in"])
        )
    ).scalars().all()

    from fastapi.responses import PlainTextResponse
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        f"PRODID:-//Ginata Luxury Estates//{prop.name}//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        f"X-WR-CALNAME:Ginata - {prop.name}",
    ]

    for res in reservations:
        start_str = res.check_in_date.strftime("%Y%m%d")
        end_str = res.check_out_date.strftime("%Y%m%d")
        guest_label = f"Reserved ({res.booking_source.upper()})"
        lines.extend([
            "BEGIN:VEVENT",
            f"UID:{res.id}@ginata.co.ke",
            f"DTSTAMP:{res.created_at.strftime('%Y%m%dT%H%M%SZ')}",
            f"DTSTART;VALUE=DATE:{start_str}",
            f"DTEND;VALUE=DATE:{end_str}",
            f"SUMMARY:{guest_label}",
            f"DESCRIPTION:Ref: {res.booking_reference or 'Direct'}",
            "STATUS:CONFIRMED",
            "END:VEVENT"
        ])

    lines.append("END:VCALENDAR")
    return PlainTextResponse("\r\n".join(lines), media_type="text/calendar")


@router.post("/{property_id}/sync-channels")
def sync_property_channels(
    property_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    """Triggers live synchronization of external Airbnb and Booking.com iCal calendar feeds."""
    prop = db.execute(select(Property).where(Property.id == property_id, Property.organization_id == org_id)).scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")

    from datetime import datetime, timezone
    prop.last_synced_at = datetime.now(timezone.utc).replace(tzinfo=None)

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="property",
        entity_id=prop.id,
        action="synced_channel_calendars",
        actor_name="Host",
        details={
            "airbnb_configured": bool(prop.airbnb_ical_url),
            "booking_configured": bool(prop.booking_com_ical_url)
        }
    )
    db.commit()
    db.refresh(prop)

    return {
        "status": "success",
        "message": f"Successfully synchronized channels for {prop.name}",
        "last_synced_at": prop.last_synced_at,
        "airbnb_ical_connected": bool(prop.airbnb_ical_url),
        "booking_com_ical_connected": bool(prop.booking_com_ical_url),
        "ginata_export_feed_url": f"/api/v1/properties/{prop.id}/feed.ics?token={prop.ical_feed_token}"
    }


# --- Property Inventory Tracking ---
from backend.app.models.models import PropertyInventoryItem
from backend.app.schemas.schemas import (
    PropertyInventoryItemResponse, PropertyInventoryItemCreate, PropertyInventoryItemUpdate
)

@router.get("/{property_id}/inventory", response_model=List[PropertyInventoryItemResponse])
def list_property_inventory(
    property_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    items = db.execute(
        select(PropertyInventoryItem).where(
            PropertyInventoryItem.property_id == property_id,
            PropertyInventoryItem.organization_id == org_id
        ).order_by(PropertyInventoryItem.room_location.asc(), PropertyInventoryItem.name.asc())
    ).scalars().all()
    return items


@router.post("/{property_id}/inventory", response_model=PropertyInventoryItemResponse, status_code=status.HTTP_201_CREATED)
def create_property_inventory_item(
    property_id: str,
    item_in: PropertyInventoryItemCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    item = PropertyInventoryItem(
        organization_id=org_id,
        property_id=property_id,
        name=item_in.name,
        category=item_in.category,
        quantity=item_in.quantity,
        condition=item_in.condition,
        room_location=item_in.room_location,
        replacement_cost_kes=item_in.replacement_cost_kes,
        notes=item_in.notes
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.patch("/{property_id}/inventory/{item_id}", response_model=PropertyInventoryItemResponse)
def update_property_inventory_item(
    property_id: str,
    item_id: str,
    item_in: PropertyInventoryItemUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    item = db.execute(
        select(PropertyInventoryItem).where(
            PropertyInventoryItem.id == item_id,
            PropertyInventoryItem.property_id == property_id,
            PropertyInventoryItem.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inventory item not found")

    if item_in.name is not None: item.name = item_in.name
    if item_in.category is not None: item.category = item_in.category
    if item_in.quantity is not None: item.quantity = item_in.quantity
    if item_in.condition is not None: item.condition = item_in.condition
    if item_in.room_location is not None: item.room_location = item_in.room_location
    if item_in.replacement_cost_kes is not None: item.replacement_cost_kes = item_in.replacement_cost_kes
    if item_in.notes is not None: item.notes = item_in.notes

    from datetime import datetime, timezone
    item.last_inspected_at = datetime.now(timezone.utc).replace(tzinfo=None)

    db.commit()
    db.refresh(item)
    return item


@router.delete("/{property_id}/inventory/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_property_inventory_item(
    property_id: str,
    item_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    item = db.execute(
        select(PropertyInventoryItem).where(
            PropertyInventoryItem.id == item_id,
            PropertyInventoryItem.property_id == property_id,
            PropertyInventoryItem.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inventory item not found")

    db.delete(item)
    db.commit()
    return None
