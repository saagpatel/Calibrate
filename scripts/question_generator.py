#!/usr/bin/env python3
"""Generate and upload Calibrate questions via Claude API.

Dependencies: pip install anthropic requests
Usage:
  Generate: python question_generator.py --category economics --count 20 --output pending_review.json
  Upload:   python question_generator.py upload --input Calibrate/Resources/seed_questions.json --days 90

Claude API key must be in macOS Keychain under service "calibrate-claude-api".
Add it once:
    security add-generic-password -s "calibrate-claude-api" -a "apikey" -w "sk-ant-..."
"""

import anthropic
import json
import argparse
import subprocess
import sys
import os
import uuid
from datetime import date, datetime, timedelta, timezone

import requests

VALID_CATEGORIES = [
    "geography",
    "science",
    "economics",
    "history",
    "popCulture",
    "currentEvents",
]

CLOUDKIT_BASE_URL = "https://api.apple-cloudkit.com/database/1/iCloud.com.calibrate.app"
CLOUDKIT_CONTAINER = "iCloud.com.calibrate.app"

SYSTEM_PROMPT = """You generate numeric estimation questions for a calibration game called Calibrate.

Rules for questions:
- Single numeric ground truth answer (no ranges, no approximations like "about 200")
- Verifiable from a publicly accessible source — include the URL
- Answerable without specialized domain expertise (general educated knowledge)
- Not trivially Googleable in under 5 seconds (avoid "What year was X founded?")
- Interesting — questions that make people think "huh, I had no idea"

Mark isEvergreen=false for values that change over time (GDP, population, box office, etc.).
isEvergreen=true for physical constants, historical facts, geographic measurements.

Return ONLY a valid JSON array. No preamble, no markdown, no explanation.

Schema for each object:
{
  "text": "Question text ending in a question mark?",
  "category": "geography|science|economics|history|popCulture|currentEvents",
  "groundTruthValue": 0.0,
  "groundTruthUnit": "unit of measurement (e.g. km, million km², trillion USD, episodes, meters)",
  "groundTruthDate": "YYYY-MM-DD (date value was verified)",
  "isEvergreen": true,
  "sourceURL": "https://...",
  "explanation": "One sentence explaining the answer and why it's interesting.",
  "estimatedDifficulty": 0.5
}"""


def get_api_key() -> str:
    result = subprocess.run(
        ["security", "find-generic-password", "-s", "calibrate-claude-api", "-w"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("ERROR: API key not found in Keychain.")
        print(
            "Add it with: security add-generic-password -s 'calibrate-claude-api' -a 'apikey' -w 'YOUR_KEY'"
        )
        sys.exit(1)
    return result.stdout.strip()


def generate_questions(category: str, count: int) -> list[dict]:
    client = anthropic.Anthropic(api_key=get_api_key())
    user_prompt = (
        f"Generate {count} estimation questions in the '{category}' category. "
        f"Vary difficulty from 0.2 to 0.9."
    )

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_prompt}],
    )

    raw = response.content[0].text.strip()
    # Strip markdown fences if present
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    return json.loads(raw.strip())


# ---------------------------------------------------------------------------
# Seeded RNG — bit-identical to Swift SeededRandomNumberGenerator + StableHash
# ---------------------------------------------------------------------------

def fnv1a(s: str) -> int:
    """FNV-1a 64-bit hash — matches Swift StableHash.fnv1a."""
    h = 14695981039346656037
    mask = (1 << 64) - 1
    for b in s.encode("utf-8"):
        h = ((h ^ b) * 1099511628211) & mask
    return h


class SeededRNG:
    """LCG matching Swift SeededRandomNumberGenerator."""

    def __init__(self, seed: int) -> None:
        self.state = seed & ((1 << 64) - 1)

    def next(self) -> int:
        self.state = (
            self.state * 6364136223846793005 + 1442695040888963407
        ) & ((1 << 64) - 1)
        return self.state


# ---------------------------------------------------------------------------
# DailySet generation
# ---------------------------------------------------------------------------

def build_daily_sets(questions: list[dict], start_date: date, days: int) -> list[dict]:
    """Return a list of DailySet dicts for `days` consecutive dates starting from start_date."""
    approved = [q for q in questions if q.get("isApproved", True)]
    sorted_questions = sorted(approved, key=lambda q: q.get("id", "").lower())

    if len(sorted_questions) < 5:
        print(f"ERROR: Only {len(sorted_questions)} approved questions — need at least 5.")
        sys.exit(1)

    daily_sets = []
    for day_offset in range(days):
        target_date = start_date + timedelta(days=day_offset)
        date_str = target_date.isoformat()

        seed = fnv1a(date_str)
        rng = SeededRNG(seed)

        pool = list(sorted_questions)
        n = len(pool)
        for i in range(n - 1, 0, -1):
            swap_idx = rng.next() % (i + 1)
            pool[i], pool[int(swap_idx)] = pool[int(swap_idx)], pool[i]

        selected = pool[:5]
        question_ids = [q["id"] for q in selected]

        daily_sets.append({
            "date": date_str,
            "questionIDs": question_ids,
        })

    return daily_sets


# ---------------------------------------------------------------------------
# CloudKit REST upload
# ---------------------------------------------------------------------------

BATCH_SIZE = 200


def cloudkit_modify_records(
    records: list[dict],
    ck_token: str,
    environment: str,
    record_type: str,
) -> dict:
    url = (
        f"{CLOUDKIT_BASE_URL}/{environment}/public/records/modify"
        f"?ckAPIToken={ck_token}"
    )
    operations = [
        {"operationType": "forceReplace", "record": r}
        for r in records
    ]
    payload = {"operations": operations}
    resp = requests.post(url, json=payload, timeout=30)
    resp.raise_for_status()
    return resp.json()


def make_question_record(q: dict) -> dict:
    """Build a CloudKit record dict for a Question."""
    record_name = q.get("id") or str(uuid.uuid4())
    fields: dict = {}

    def add(key: str, value: object, field_type: str = "STRING") -> None:
        if value is not None:
            fields[key] = {"value": value, "type": field_type}

    add("questionID", record_name)
    add("text", q.get("text"))
    add("category", q.get("category"))
    add("groundTruthValue", q.get("groundTruthValue"), "DOUBLE")
    add("groundTruthUnit", q.get("groundTruthUnit"))
    add("groundTruthDate", q.get("groundTruthDate"))
    add("isEvergreen", 1 if q.get("isEvergreen", True) else 0, "INT64")
    add("sourceURL", q.get("sourceURL"))
    add("explanation", q.get("explanation"))
    add("difficulty", q.get("estimatedDifficulty"), "DOUBLE")
    add("isApproved", 1 if q.get("isApproved", True) else 0, "INT64")

    return {
        "recordName": record_name,
        "recordType": "Question",
        "fields": fields,
    }


def make_daily_set_record(ds: dict) -> dict:
    """Build a CloudKit record dict for a DailySet."""
    date_str: str = ds["date"]
    fields: dict = {
        "utcDate": {"value": date_str, "type": "STRING"},
        "questionIDs": {"value": ds["questionIDs"], "type": "LIST"},
        "publishedAt": {
            "value": int(datetime.now(timezone.utc).timestamp() * 1000),
            "type": "TIMESTAMP",
        },
    }
    return {
        "recordName": f"DailySet-{date_str}",
        "recordType": "DailySet",
        "fields": fields,
    }


def upload_in_batches(
    records: list[dict],
    ck_token: str,
    environment: str,
    label: str,
) -> int:
    total = len(records)
    uploaded = 0
    for start in range(0, total, BATCH_SIZE):
        batch = records[start : start + BATCH_SIZE]
        end = min(start + BATCH_SIZE, total)
        print(f"  Uploading {label} records {start + 1}–{end} of {total}...", end=" ")
        try:
            cloudkit_modify_records(batch, ck_token, environment, label)
            uploaded += len(batch)
            print("OK")
        except requests.HTTPError as exc:
            print(f"FAILED — {exc}")
            print(f"  Response: {exc.response.text[:500]}")
            sys.exit(1)
    return uploaded


def cmd_upload(args: argparse.Namespace) -> None:
    ck_token = args.ck_token or os.environ.get("CLOUDKIT_WEB_TOKEN", "")
    if not ck_token:
        print("ERROR: CloudKit token required. Pass --ck-token or set CLOUDKIT_WEB_TOKEN env var.")
        sys.exit(1)

    input_path = args.input
    try:
        with open(input_path) as f:
            questions = json.load(f)
    except FileNotFoundError:
        print(f"ERROR: Input file not found: {input_path}")
        sys.exit(1)
    except json.JSONDecodeError as exc:
        print(f"ERROR: Invalid JSON in {input_path}: {exc}")
        sys.exit(1)

    # Assign stable IDs to any question missing one (deterministic from text)
    for q in questions:
        if not q.get("id"):
            q["id"] = str(uuid.UUID(int=fnv1a(q.get("text", "") + q.get("category", "")) % (1 << 128)))

    approved = [q for q in questions if q.get("isApproved", True)]
    print(f"Loaded {len(questions)} questions ({len(approved)} approved) from {input_path}")

    # Build records
    question_records = [make_question_record(q) for q in approved]

    start_date = date.today()
    daily_sets = build_daily_sets(questions, start_date, args.days)
    daily_set_records = [make_daily_set_record(ds) for ds in daily_sets]

    print(f"\nUploading to CloudKit ({args.environment})...")

    q_uploaded = upload_in_batches(question_records, ck_token, args.environment, "Question")
    ds_uploaded = upload_in_batches(daily_set_records, ck_token, args.environment, "DailySet")

    print(f"\nDone.")
    print(f"  Questions uploaded:  {q_uploaded}")
    print(f"  Daily sets uploaded: {ds_uploaded}  ({start_date} → {start_date + timedelta(days=args.days - 1)})")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate and upload Calibrate questions"
    )
    subparsers = parser.add_subparsers(dest="subcommand")

    # --- upload subcommand ---
    upload_parser = subparsers.add_parser("upload", help="Upload approved questions and daily sets to CloudKit")
    upload_parser.add_argument(
        "--input",
        default="Calibrate/Resources/seed_questions.json",
        help="Path to approved questions JSON (default: Calibrate/Resources/seed_questions.json)",
    )
    upload_parser.add_argument(
        "--days",
        type=int,
        default=90,
        help="Number of daily sets to generate (default: 90)",
    )
    upload_parser.add_argument(
        "--ck-token",
        default=None,
        help="CloudKit Web Services API token (or set CLOUDKIT_WEB_TOKEN env var)",
    )
    upload_parser.add_argument(
        "--environment",
        default="development",
        choices=["development", "production"],
        help="CloudKit environment (default: development)",
    )

    # --- generate args (top-level, backward compat) ---
    parser.add_argument("--category", choices=VALID_CATEGORIES)
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--output", default="pending_review.json")

    args = parser.parse_args()

    if args.subcommand == "upload":
        cmd_upload(args)
        return

    # Default: generate behavior (backward compat)
    if not args.category:
        parser.error("--category is required when not using a subcommand")

    print(f"Generating {args.count} {args.category} questions...")
    questions = generate_questions(args.category, args.count)

    # Add metadata
    for q in questions:
        q["isApproved"] = False
        q["generatedAt"] = datetime.now(timezone.utc).isoformat()

    # Merge with existing file if it exists
    existing: list = []
    try:
        with open(args.output) as f:
            existing = json.loads(f.read())
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    merged = existing + questions

    with open(args.output, "w") as f:
        json.dump(merged, f, indent=2)

    print(f"  {len(questions)} questions generated.")
    print(f"  {len(merged)} total questions in {args.output}")
    print("Open AdminQuestionView in the app to review and approve.")


if __name__ == "__main__":
    main()
