import logging

from sqlalchemy import inspect, text
from backend.app.core.database import Base

logger = logging.getLogger("uvicorn.error")

ADDITIONS = {
    "host_users": ["supabase_user_id", "google_email", "avatar_url", "reset_code_hash", "reset_code_salt", "reset_expires_at", "reset_attempts"],
    "properties": ["description", "amenities", "gallery_urls", "bedrooms", "bathrooms", "max_guests"],
    "guests": ["notes"],
    "reservations": ["checked_in_at", "checked_out_at"],
}


def run_migrations(engine):
    from sqlalchemy.schema import CreateColumn

    with engine.begin() as conn:
        inspector = inspect(conn)
        quote = conn.dialect.identifier_preparer.quote
        for table_name, names in ADDITIONS.items():
            existing = {column["name"] for column in inspector.get_columns(table_name)}
            table = Base.metadata.tables[table_name]
            for name in names:
                if name not in existing:
                    definition = str(CreateColumn(table.c[name]).compile(dialect=conn.dialect))
                    conn.execute(text(f"ALTER TABLE {quote(table_name)} ADD COLUMN {definition}"))
            if table_name == "host_users":
                conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS uq_host_supabase_id ON host_users (supabase_user_id)"))
    if engine.dialect.name != "postgresql":
        return
    with engine.begin() as conn:
        tables = conn.execute(text("SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tableowner = current_user")).scalars().all()
        roles = conn.execute(text("SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated')")).scalars().all()
        quote = conn.dialect.identifier_preparer.quote
        for name in tables:
            if name not in Base.metadata.tables:
                continue
            conn.execute(text(f"ALTER TABLE public.{quote(name)} ENABLE ROW LEVEL SECURITY"))
            for role in roles:
                conn.execute(text(f"REVOKE ALL ON TABLE public.{quote(name)} FROM {quote(role)}"))
    logger.info("Ginata additive migrations and database access lockdown completed")
