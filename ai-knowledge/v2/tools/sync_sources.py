#!/usr/bin/env python3
"""Sync authoritative/source pages into local snapshots for ai-knowledge v2."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from html import unescape
from pathlib import Path
from typing import Any
from urllib.error import URLError, HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
SNAPSHOT_DIR = DATA_DIR / "snapshots"
REPORT_PATH = DATA_DIR / "sync-report.json"
STATE_PATH = DATA_DIR / "sync-state.json"
SOURCES_PATH = Path(__file__).with_name("sources.json")

USER_AGENT = "BrainrotRNG-AIKnowledgeSync/2.0"


@dataclass
class Source:
    id: str
    tier: str
    url: str
    description: str


def load_sources() -> list[Source]:
    raw = json.loads(SOURCES_PATH.read_text(encoding="utf-8"))
    return [Source(**item) for item in raw["sources"]]


def fetch_html(url: str, timeout: int = 30) -> str:
    req = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(req, timeout=timeout) as res:
        content = res.read()
    return content.decode("utf-8", errors="replace")


def html_to_text(html: str) -> str:
    stripped = re.sub(r"<script[\\s\\S]*?</script>", " ", html, flags=re.IGNORECASE)
    stripped = re.sub(r"<style[\\s\\S]*?</style>", " ", stripped, flags=re.IGNORECASE)
    stripped = re.sub(r"<[^>]+>", " ", stripped)
    stripped = unescape(stripped)
    stripped = re.sub(r"\\s+", " ", stripped).strip()
    return stripped


def content_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_state() -> dict[str, Any]:
    if not STATE_PATH.exists():
        return {}
    return json.loads(STATE_PATH.read_text(encoding="utf-8"))


def save_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=True), encoding="utf-8")


def snapshot_path(source_id: str) -> Path:
    return SNAPSHOT_DIR / f"{source_id}.json"


def run_sync(max_chars: int) -> int:
    now = datetime.now(timezone.utc).isoformat()
    sources = load_sources()
    prev_state = load_state()

    results: list[dict[str, Any]] = []
    changed = 0

    for source in sources:
        entry: dict[str, Any] = {
            "id": source.id,
            "tier": source.tier,
            "url": source.url,
            "description": source.description,
            "synced_at": now,
            "status": "ok",
        }
        try:
            html = fetch_html(source.url)
            text = html_to_text(html)
            text = text[:max_chars]
            digest = content_hash(text)
            old_digest = prev_state.get(source.id, {}).get("hash")
            is_changed = digest != old_digest
            if is_changed:
                changed += 1

            snapshot_payload = {
                "id": source.id,
                "tier": source.tier,
                "url": source.url,
                "description": source.description,
                "synced_at": now,
                "hash": digest,
                "excerpt": text,
                "char_count": len(text),
            }
            save_json(snapshot_path(source.id), snapshot_payload)

            entry["hash"] = digest
            entry["changed"] = is_changed
            entry["char_count"] = len(text)
        except (HTTPError, URLError, TimeoutError) as exc:
            entry["status"] = "error"
            entry["error"] = str(exc)
            entry["changed"] = False
        except Exception as exc:  # noqa: BLE001
            entry["status"] = "error"
            entry["error"] = f"unexpected: {exc}"
            entry["changed"] = False

        results.append(entry)

    new_state = {
        item["id"]: {
            "hash": item.get("hash"),
            "last_synced": item["synced_at"],
            "status": item["status"],
        }
        for item in results
    }
    save_json(STATE_PATH, new_state)

    report = {
        "synced_at": now,
        "total_sources": len(sources),
        "changed_sources": changed,
        "results": results,
    }
    save_json(REPORT_PATH, report)

    print(f"[sync] total={len(sources)} changed={changed} report={REPORT_PATH}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sync external docs snapshots for ai-knowledge")
    parser.add_argument("--max-chars", type=int, default=120000, help="Max normalized chars per source")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    raise SystemExit(run_sync(max_chars=args.max_chars))
