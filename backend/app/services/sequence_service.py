from datetime import timezone, datetime
from sqlalchemy.orm import Session
from sqlalchemy import select
from backend.app.models.models import OrgSequence

def get_next_sequence_number(
    db: Session,
    organization_id: str,
    series_key: str
) -> str:
    """
    Concurrency-safe sequence number generator per organization, series, and year.
    Returns formatted string: GIN-{SERIES}-{YEAR}-{SEQ:04d}
    """
    year = datetime.now(timezone.utc).replace(tzinfo=None).year
    series_upper = series_key.upper()

    # Query with lock if dialect supports it
    seq_row = db.execute(
        select(OrgSequence).where(
            OrgSequence.organization_id == organization_id,
            OrgSequence.series_key == series_upper,
            OrgSequence.year == year
        ).with_for_update() if not db.bind.url.drivername.startswith("sqlite") else
        select(OrgSequence).where(
            OrgSequence.organization_id == organization_id,
            OrgSequence.series_key == series_upper,
            OrgSequence.year == year
        )
    ).scalar_one_or_none()

    if seq_row is None:
        seq_row = OrgSequence(
            organization_id=organization_id,
            series_key=series_upper,
            year=year,
            current_val=1
        )
        db.add(seq_row)
        db.flush()
        next_val = 1
    else:
        seq_row.current_val += 1
        db.flush()
        next_val = seq_row.current_val

    return f"GIN-{series_upper}-{year}-{next_val:04d}"
