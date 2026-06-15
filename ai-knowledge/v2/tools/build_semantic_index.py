#!/usr/bin/env python3
"""Build a lightweight semantic index for ai-knowledge v2 content."""

from __future__ import annotations

import json
import math
import re
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
INDEX_PATH = ROOT / "data" / "index" / "semantic-index.json"

ALLOWED_SUFFIXES = {".md", ".json", ".yaml", ".yml", ".txt"}
STOPWORDS = {
    "the", "a", "an", "and", "or", "to", "of", "in", "for", "on", "with",
    "is", "are", "be", "as", "that", "this", "it", "from", "by", "at", "if",
    "khong", "la", "va", "cho", "trong", "mot", "cac", "khi", "duoc", "voi",
}


def tokenize(text: str) -> list[str]:
    text = text.lower()
    words = re.findall(r"[a-z0-9_]{2,}", text)
    return [w for w in words if w not in STOPWORDS]


def iter_documents() -> list[Path]:
    docs: list[Path] = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in ALLOWED_SUFFIXES:
            continue
        if "data/index" in path.as_posix():
            continue
        if "data/snapshots" in path.as_posix():
            continue
        docs.append(path)
    return sorted(docs)


def build() -> dict[str, Any]:
    docs = iter_documents()

    doc_meta: dict[str, Any] = {}
    doc_terms: dict[str, Counter[str]] = {}
    doc_lengths: dict[str, int] = {}
    df: defaultdict[str, int] = defaultdict(int)

    for path in docs:
        rel = path.relative_to(ROOT).as_posix()
        raw = path.read_text(encoding="utf-8", errors="replace")
        terms = tokenize(raw)
        counter = Counter(terms)

        if not counter:
            continue

        doc_meta[rel] = {
            "path": rel,
            "title": path.stem,
            "char_count": len(raw),
        }
        doc_terms[rel] = counter
        doc_lengths[rel] = sum(counter.values())

        for term in counter.keys():
            df[term] += 1

    total_docs = len(doc_terms)
    avg_dl = (sum(doc_lengths.values()) / total_docs) if total_docs else 0.0

    postings: dict[str, dict[str, float]] = {}
    for term, term_df in df.items():
        idf = math.log(1 + (total_docs - term_df + 0.5) / (term_df + 0.5)) if total_docs else 0.0
        postings[term] = {"idf": idf, "docs": {}}

    for doc_id, counts in doc_terms.items():
        dl = doc_lengths[doc_id]
        for term, tf in counts.items():
            postings[term]["docs"][doc_id] = tf

    return {
        "built_at": datetime.now(timezone.utc).isoformat(),
        "root": ROOT.as_posix(),
        "total_docs": total_docs,
        "avg_doc_length": avg_dl,
        "doc_meta": doc_meta,
        "doc_lengths": doc_lengths,
        "postings": postings,
    }


def main() -> int:
    index = build()
    INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    INDEX_PATH.write_text(json.dumps(index, ensure_ascii=True, indent=2), encoding="utf-8")
    print(f"[index] docs={index['total_docs']} output={INDEX_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
