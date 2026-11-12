import os
import tempfile
import uuid
from pathlib import Path

_test_database = Path(tempfile.gettempdir()) / f"ginata-tests-{uuid.uuid4().hex}.db"
os.environ["DATABASE_URL"] = f"sqlite:///{_test_database.as_posix()}"


def pytest_sessionfinish(session, exitstatus):
    from backend.app.core.database import engine

    engine.dispose()
    for suffix in ("", "-shm", "-wal"):
        path = Path(f"{_test_database}{suffix}")
        if path.exists():
            path.unlink()
