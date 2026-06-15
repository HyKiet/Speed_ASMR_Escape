#!/usr/bin/env python3
"""Query ai-knowledge semantic index with BM25-like scoring."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
INDEX_PATH = ROOT / "data" / "index" / "semantic-index.json"

STOPWORDS = {
    "the", "a", "an", "and", "or", "to", "of", "in", "for", "on", "with",
    "is", "are", "be", "as", "that", "this", "it", "from", "by", "at", "if",
    "khong", "la", "va", "cho", "trong", "mot", "cac", "khi", "duoc", "voi",
}


def tokenize(text: str) -> list[str]:
    words = re.findall(r"[a-z0-9_]{2,}", text.lower())
    return [w for w in words if w not in STOPWORDS]


def load_index() -> dict[str, Any]:
    if not INDEX_PATH.exists():
        raise FileNotFoundError(f"Semantic index not found: {INDEX_PATH}")
    return json.loads(INDEX_PATH.read_text(encoding="utf-8"))


def search(index: dict[str, Any], query: str, top_k: int = 8) -> list[tuple[str, float]]:
    terms = tokenize(query)
    if not terms:
        return []

    postings = index["postings"]
    doc_lengths = index["doc_lengths"]
    avg_dl = max(float(index["avg_doc_length"]), 1.0)

    k1 = 1.2
    b = 0.75

    scores: dict[str, float] = {}
    for term in terms:
        posting = postings.get(term)
        if not posting:
            continue
        idf = float(posting["idf"])
        for doc_id, tf in posting["docs"].items():
            dl = max(float(doc_lengths.get(doc_id, 0)), 1.0)
            tf = float(tf)
            denom = tf + k1 * (1 - b + b * (dl / avg_dl))
            score = idf * ((tf * (k1 + 1)) / denom)
            scores[doc_id] = scores.get(doc_id, 0.0) + score

    ranked = sorted(scores.items(), key=lambda item: item[1], reverse=True)
    return ranked[:top_k]


def main() -> int:
    parser = argparse.ArgumentParser(description="Query ai-knowledge semantic index")
    parser.add_argument("query", help="Natural language query")
    parser.add_argument("--top", type=int, default=8, help="Top results")
    args = parser.parse_args()

    index = load_index()
    results = search(index, args.query, top_k=args.top)

    if not results:
        print("No results")
        return 0

    meta = index["doc_meta"]
    for rank, (doc_id, score) in enumerate(results, start=1):
        title = meta.get(doc_id, {}).get("title", doc_id)
        print(f"{rank:02d}. {doc_id} | score={score:.4f} | title={title}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
