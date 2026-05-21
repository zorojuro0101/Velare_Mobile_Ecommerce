"""
Backfill sentiment for product_reviews rows where sentiment IS NULL.

Reads review_text from Supabase, asks Gemini for a sentiment, and updates the
row. Run once after fixing the Gemini model name.

Usage:
    1. Set SUPABASE_URL and SUPABASE_SERVICE_KEY env vars (service role key,
       not anon - we need to write).
    2. python backfill_sentiment.py            # dry run, prints what it would do
    3. python backfill_sentiment.py --apply    # actually writes changes
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

GEMINI_API_KEY = "AIzaSyB7Wr9g8KuGYjEqP622PUOTq6phX64lFEA"
# Gemini 3.1 Flash-Lite has the highest free-tier daily quota (15 RPM /
# 500 RPD), making it ideal for batch backfill jobs.
GEMINI_MODEL = "gemini-3.1-flash-lite"
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
)

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")


def gemini_sentiment(text: str) -> str | None:
    prompt = (
        "Analyze the sentiment of the following customer review. The review "
        "can be in English, Tagalog, or Taglish. Respond strictly in JSON "
        "with a single key 'sentiment' having one of the values: 'positive', "
        f"'neutral', or 'negative'.\n\nReview:\n\"{text}\"\n\n"
        'Example Output:\n{"sentiment": "positive"}\n'
    )
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseMimeType": "application/json"},
    }).encode("utf-8")
    req = urllib.request.Request(
        GEMINI_URL,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            raw = data["candidates"][0]["content"]["parts"][0]["text"].strip()
            parsed = json.loads(raw)
            s = parsed.get("sentiment")
            if s in ("positive", "neutral", "negative"):
                return s
            return None
    except urllib.error.HTTPError as e:
        print(f"  Gemini HTTP {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}")
        return None
    except Exception as e:
        print(f"  Gemini error: {e!r}")
        return None


def supabase_request(method: str, path: str, payload=None, params=""):
    url = f"{SUPABASE_URL}/rest/v1/{path}{params}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = resp.read().decode("utf-8")
        return json.loads(body) if body else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="actually write updates")
    ap.add_argument("--limit", type=int, default=500)
    args = ap.parse_args()

    if not SUPABASE_URL or not SUPABASE_KEY:
        print(
            "ERROR: set SUPABASE_URL and SUPABASE_SERVICE_KEY env vars before running.\n"
            "Example (PowerShell):\n"
            "  $env:SUPABASE_URL='https://xxx.supabase.co'\n"
            "  $env:SUPABASE_SERVICE_KEY='eyJ...'\n",
            file=sys.stderr,
        )
        sys.exit(1)

    rows = supabase_request(
        "GET",
        "product_reviews",
        params=(
            "?select=review_id,review_text"
            "&sentiment=is.null"
            "&review_text=not.is.null"
            f"&limit={args.limit}"
        ),
    )
    print(f"Found {len(rows)} reviews with NULL sentiment.")

    updated = skipped = errored = 0
    for row in rows:
        rid = row["review_id"]
        text = (row.get("review_text") or "").strip()
        if not text:
            skipped += 1
            continue

        sentiment = gemini_sentiment(text)
        if not sentiment:
            errored += 1
            print(f"  review_id={rid}: could not classify (skipped)")
            continue

        if args.apply:
            try:
                supabase_request(
                    "PATCH",
                    "product_reviews",
                    payload={"sentiment": sentiment},
                    params=f"?review_id=eq.{rid}",
                )
                updated += 1
                print(f"  review_id={rid} -> {sentiment}")
            except Exception as e:
                errored += 1
                print(f"  review_id={rid}: PATCH failed: {e!r}")
        else:
            print(f"  [dry-run] review_id={rid} would be set to '{sentiment}'")
            updated += 1

        # Be polite with the free-tier quota
        time.sleep(0.3)

    print(
        f"\nSummary: classified={updated}, skipped={skipped}, errored={errored}, total={len(rows)}"
    )
    if not args.apply:
        print("(Dry run only - re-run with --apply to commit changes.)")


if __name__ == "__main__":
    main()
