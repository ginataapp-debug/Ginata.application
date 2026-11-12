import time
from collections import defaultdict, deque
from threading import Lock

from fastapi import Request, HTTPException
from backend.app.core.config import settings

_requests = defaultdict(deque)
_lock = Lock()


def limit_auth_requests(request: Request):
    if not settings.RATE_LIMIT_ENABLED:
        return
    key = (request.client.host if request.client else "unknown", request.url.path)
    now = time.monotonic()
    with _lock:
        expired = [k for k, queue in _requests.items() if not queue or queue[-1] <= now - 60]
        for k in expired:
            del _requests[k]
        queue = _requests[key]
        while queue and queue[0] <= now - 60:
            queue.popleft()
        if len(queue) >= 20:
            raise HTTPException(429, "Too many requests. Try again in a minute.", headers={"Retry-After": "60"})
        queue.append(now)
