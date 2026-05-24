"""
One-time migration: convert any plain-text passwords in the `users` table
to bcrypt hashes.

Run from the project root:

    python -m utils.migrate_passwords_to_bcrypt          # dry run (default)
    python -m utils.migrate_passwords_to_bcrypt --apply  # actually write

Notes
-----
- Idempotent. Rows already containing a bcrypt hash ($2a$ / $2b$ / $2y$) are
  skipped, so re-running is safe.
- The login endpoint will also auto-upgrade legacy rows on the next successful
  login, so this script is mainly for unused accounts (admins, test users)
  that may not log in soon.
- Reads SUPABASE_URL / SUPABASE_KEY from the project's .env (same as the app).
"""

import argparse
import os
import sys

# Allow running as a script from the project root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database.db_config import get_supabase_client
from utils.password_utils import hash_password, is_hashed


def main(apply: bool) -> int:
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Could not connect to Supabase. Check SUPABASE_URL / SUPABASE_KEY in .env.")
        return 1

    print("🔍 Fetching all users…")
    response = supabase.table('users').select('user_id, email, password').execute()
    users = response.data or []
    print(f"   Found {len(users)} user(s).")

    legacy = [u for u in users if not is_hashed(u.get('password'))]
    already = len(users) - len(legacy)

    print(f"   Already hashed: {already}")
    print(f"   Plain-text legacy: {len(legacy)}")

    if not legacy:
        print("✅ Nothing to do. All passwords already hashed.")
        return 0

    print()
    if not apply:
        print("DRY RUN — no rows will be modified. Add --apply to commit.")
        for u in legacy:
            print(f"   would hash user_id={u['user_id']} email={u['email']}")
        return 0

    print("⚠️ Writing hashed passwords…")
    upgraded = 0
    failed = 0
    for u in legacy:
        try:
            new_hash = hash_password(u['password'])
            supabase.table('users').update(
                {'password': new_hash}
            ).eq('user_id', u['user_id']).execute()
            print(f"   ✅ user_id={u['user_id']} email={u['email']}")
            upgraded += 1
        except Exception as e:
            print(f"   ❌ user_id={u['user_id']} email={u['email']} → {e}")
            failed += 1

    print()
    print(f"Done. Upgraded: {upgraded}, Failed: {failed}.")
    return 0 if failed == 0 else 2


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--apply', action='store_true',
        help='Write the new hashes. Without this flag the script just shows what would change.',
    )
    args = parser.parse_args()
    sys.exit(main(apply=args.apply))
