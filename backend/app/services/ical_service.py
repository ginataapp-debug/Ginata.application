import http.client
import ipaddress
import socket
import ssl
from datetime import date, datetime, timedelta
from urllib.parse import urlsplit

from sqlalchemy import select, delete, or_
from backend.app.models.models import ExternalCalendarBlock, Property
from backend.app.services.subscription_service import get_subscription, PLANS

MAX_FEED_BYTES = 2 * 1024 * 1024


def validate_feed_url(url):
    parsed = urlsplit(url)
    host = (parsed.hostname or "").lower()
    if parsed.scheme != "https" or parsed.username or parsed.password or parsed.fragment or parsed.port not in (None, 443):
        raise ValueError("Calendar feeds must use HTTPS without credentials")
    if not any(host == domain or host.endswith("." + domain) for domain in ("airbnb.com", "booking.com", "calendar.google.com")):
        raise ValueError("Use a calendar export URL from Airbnb, Booking.com or Google Calendar")
    return parsed


def download_feed(url):
    parsed = validate_feed_url(url)
    addresses = list(dict.fromkeys(info[4][0] for info in socket.getaddrinfo(parsed.hostname, 443, type=socket.SOCK_STREAM)))
    if not addresses or any(not ipaddress.ip_address(ip).is_global for ip in addresses):
        raise ValueError("Calendar host must resolve to a public address")
    connection = http.client.HTTPSConnection(parsed.hostname, timeout=20, context=ssl.create_default_context())
    try:
        sock = socket.create_connection((addresses[0], 443), timeout=20)
        try:
            connection.sock = connection._context.wrap_socket(sock, server_hostname=parsed.hostname)
        except Exception:
            sock.close()
            raise
        connection.request("GET", (parsed.path or "/") + ("?" + parsed.query if parsed.query else ""), headers={"Accept": "text/calendar", "User-Agent": "Ginata Calendar Sync"})
        response = connection.getresponse()
        if response.status != 200:
            raise ValueError(f"Calendar provider returned HTTP {response.status}")
        data = response.read(MAX_FEED_BYTES + 1)
        if len(data) > MAX_FEED_BYTES:
            raise ValueError("Calendar feed exceeds 2MB")
        return data
    finally:
        connection.close()


def parse_feed(data):
    from icalendar import Calendar
    if b"BEGIN:VCALENDAR" not in data or b"END:VCALENDAR" not in data:
        raise ValueError("Provider did not return an iCalendar feed")
    calendar = Calendar.from_ical(data)
    events = {}
    for event in calendar.walk("VEVENT"):
        if str(event.get("STATUS", "")).upper() == "CANCELLED":
            continue
        if event.get("RRULE") or event.get("RDATE"):
            raise ValueError("Recurring calendar events are not supported. Use a booking export feed.")
        uid = str(event.get("UID", ""))
        if not uid or len(uid) > 500 or not event.get("DTSTART"):
            raise ValueError("Calendar event is missing a valid UID or start date")
        start = event.decoded("DTSTART")
        end = event.decoded("DTEND") if event.get("DTEND") else start + timedelta(days=1)
        if isinstance(start, datetime):
            start = start.date()
        if isinstance(end, datetime):
            end = end.date()
        if not isinstance(start, date) or not isinstance(end, date) or end <= start:
            raise ValueError("Calendar event dates are invalid")
        events[uid] = (start, end, str(event.get("SUMMARY", "Reserved"))[:255])
        if len(events) > 5000:
            raise ValueError("Calendar contains too many events")
    return events


def block_response(block):
    return {name: getattr(block, name) for name in ("id", "property_id", "source", "start_date", "end_date", "summary")}


def sync_property(db, prop):
    result = {"success": True, "imported": 0, "updated": 0, "removed": 0, "errors": [], "last_synced_at": prop.last_synced_at}
    for source, url in (("airbnb", prop.airbnb_ical_url), ("booking_com", prop.booking_com_ical_url)):
        current = {b.uid: b for b in db.scalars(select(ExternalCalendarBlock).where(ExternalCalendarBlock.organization_id == prop.organization_id, ExternalCalendarBlock.property_id == prop.id, ExternalCalendarBlock.source == source))}
        try:
            events = parse_feed(download_feed(url)) if url else {}
        except (ValueError, OSError, http.client.HTTPException) as exc:
            result["success"] = False
            result["errors"].append({"source": source, "message": str(exc) if isinstance(exc, ValueError) else "Calendar provider could not be reached"})
            continue
        for uid, (start, end, summary) in events.items():
            block = current.pop(uid, None)
            if block is None:
                db.add(ExternalCalendarBlock(organization_id=prop.organization_id, property_id=prop.id, source=source, uid=uid, start_date=start, end_date=end, summary=summary))
                result["imported"] += 1
            elif (block.start_date, block.end_date, block.summary) != (start, end, summary):
                block.start_date, block.end_date, block.summary = start, end, summary
                result["updated"] += 1
        for block in current.values():
            db.delete(block)
            result["removed"] += 1
    if result["success"]:
        prop.last_synced_at = datetime.utcnow()
        result["last_synced_at"] = prop.last_synced_at
    db.commit()
    return result


def run_due_calendar_syncs(factory):
    with factory() as db:
        due = db.scalars(select(Property).where(or_(Property.airbnb_ical_url.is_not(None), Property.booking_com_ical_url.is_not(None)), or_(Property.last_synced_at.is_(None), Property.last_synced_at < datetime.utcnow() - timedelta(minutes=15)))).all()
        for prop in due:
            _, plan = get_subscription(db, prop.organization_id)
            if PLANS[plan]["ical_sync"]:
                sync_property(db, prop)
