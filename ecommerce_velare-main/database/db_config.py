import os
import threading
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Cached singleton Supabase client. Building a Supabase client is expensive
# because it sets up an httpx session, auth handlers, etc. Re-creating one on
# every call (e.g. inside route handlers, helpers, before_request hooks) was
# adding 5-20+ client constructions to a single page request and was the
# largest source of tab-switch latency. We build it lazily once per process
# and protect creation with a lock so it stays thread-safe under gunicorn.
_supabase_client = None
_supabase_lock = threading.Lock()


def _build_client():
    """Construct a fresh Supabase client. Returns None on misconfiguration."""
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_KEY')

    if not url or not key:
        print("❌ Supabase credentials not found in .env file")
        return None

    return create_client(url, key)


def get_supabase_client():
    """Return a process-wide cached Supabase client.

    The client is created on first use and reused for every subsequent call.
    This preserves the previous public API exactly: callers still receive a
    valid `Client` (or `None` on misconfiguration) and the result can be used
    with `if not supabase: ...` guards just like before.
    """
    global _supabase_client

    # Fast path: client already cached.
    if _supabase_client is not None:
        return _supabase_client

    # Slow path: build under a lock so concurrent first-requests don't race.
    with _supabase_lock:
        if _supabase_client is None:
            try:
                _supabase_client = _build_client()
            except Exception as e:
                print(f"❌ Error connecting to Supabase: {e}")
                _supabase_client = None

    return _supabase_client


def reset_supabase_client():
    """Drop the cached Supabase client. Intended for tests / credential rotation."""
    global _supabase_client
    with _supabase_lock:
        _supabase_client = None


# Legacy functions for backward compatibility (no-op)
def get_db_connection():
    """Legacy function - returns None. Use get_supabase_client() instead."""
    print("⚠️ Warning: get_db_connection() is deprecated. Use get_supabase_client() instead.")
    return None


def close_db_connection(connection, cursor=None):
    """Legacy function - no-op. Supabase connections are managed automatically."""
    pass
