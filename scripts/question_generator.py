#!/usr/bin/env python3
"""Generate Calibrate questions via Claude API.

Dependencies: pip install anthropic
Usage: python question_generator.py --category economics --count 20 --output pending_review.json

Claude API key must be in macOS Keychain under service "calibrate-claude-api".
Add it once:
    security add-generic-password -s "calibrate-claude-api" -a "apikey" -w "sk-ant-..."
"""

import anthropic
import json
import argparse
import subprocess
import sys
from datetime import datetime, timezone

VALID_CATEGORIES = [
    "geography",
    "science",
    "economics",
    "history",
    "popCulture",
    "currentEvents",
]

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


def main():
    parser = argparse.ArgumentParser(
        description="Generate Calibrate questions via Claude API"
    )
    parser.add_argument("--category", choices=VALID_CATEGORIES, required=True)
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--output", default="pending_review.json")
    args = parser.parse_args()

    print(f"Generating {args.count} {args.category} questions...")
    questions = generate_questions(args.category, args.count)

    # Add metadata
    for q in questions:
        q["isApproved"] = False
        q["generatedAt"] = datetime.now(timezone.utc).isoformat()

    # Merge with existing file if it exists
    existing = []
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
