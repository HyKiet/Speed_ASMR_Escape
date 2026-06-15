#!/usr/bin/env python3
"""Run lightweight static quality gates for Luau task profiles."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PROFILE_PATH = ROOT / "08-quality-gates" / "task-profiles.json"
REPORT_PATH = ROOT / "data" / "verification" / "last-report.json"
BASELINE_DIR = ROOT / "data" / "verification" / "baselines"
SRC_ROOT = ROOT.parents[1] / "src"


@dataclass
class Finding:
    level: str
    file: str
    rule: str
    detail: str

    def fingerprint(self) -> str:
        return f"{self.level}|{self.file}|{self.rule}|{self.detail}"


def load_profiles() -> dict[str, Any]:
    raw = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
    return raw["profiles"]


def collect_files(paths: list[str]) -> list[Path]:
    if paths:
        out = [Path(p).resolve() for p in paths]
        return [p for p in out if p.exists() and p.suffix in {".lua", ".luau"}]

    return sorted([p for p in SRC_ROOT.rglob("*.lua")] + [p for p in SRC_ROOT.rglob("*.luau")])


def run_profile(profile: dict[str, Any], files: list[Path]) -> list[Finding]:
    findings: list[Finding] = []

    forbidden = [re.compile(pat, flags=re.IGNORECASE | re.MULTILINE) for pat in profile.get("forbidden_patterns", [])]
    required = [re.compile(re.escape(hint), flags=re.IGNORECASE) for hint in profile.get("required_hints", [])]

    for file in files:
        text = file.read_text(encoding="utf-8", errors="replace")
        rel = file.relative_to(ROOT.parents[1]).as_posix()

        for idx, pat in enumerate(forbidden, start=1):
            if pat.search(text):
                findings.append(Finding(
                    level="fail",
                    file=rel,
                    rule=f"forbidden_{idx}",
                    detail=f"Matched forbidden pattern: {pat.pattern}",
                ))

        for idx, pat in enumerate(required, start=1):
            if not pat.search(text):
                findings.append(Finding(
                    level="warn",
                    file=rel,
                    rule=f"required_hint_{idx}",
                    detail=f"Missing expected hint: {pat.pattern}",
                ))

    return findings


def summarize(findings: list[Finding]) -> dict[str, Any]:
    fail_count = sum(1 for f in findings if f.level == "fail")
    warn_count = sum(1 for f in findings if f.level == "warn")
    status = "pass" if fail_count == 0 else "fail"
    return {
        "status": status,
        "fail_count": fail_count,
        "warn_count": warn_count,
        "findings": [f.__dict__ for f in findings],
    }


def baseline_path(profile: str) -> Path:
    return BASELINE_DIR / f"{profile}.json"


def load_baseline(profile: str) -> set[str]:
    path = baseline_path(profile)
    if not path.exists():
        return set()
    raw = json.loads(path.read_text(encoding="utf-8"))
    return set(raw.get("fingerprints", []))


def save_baseline(profile: str, findings: list[Finding]) -> None:
    BASELINE_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "profile": profile,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "fingerprints": sorted({f.fingerprint() for f in findings}),
    }
    baseline_path(profile).write_text(json.dumps(payload, indent=2, ensure_ascii=True), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run quality harness for a task profile")
    parser.add_argument("--profile", required=True, help="Profile name: ability|networking|ui|data")
    parser.add_argument("--files", nargs="*", default=[], help="Optional explicit file list")
    parser.add_argument("--update-baseline", action="store_true", help="Store current findings as baseline")
    args = parser.parse_args()

    profiles = load_profiles()
    if args.profile not in profiles:
        print(f"Unknown profile: {args.profile}")
        print(f"Available: {', '.join(sorted(profiles.keys()))}")
        return 2

    files = collect_files(args.files)
    profile = profiles[args.profile]
    findings = run_profile(profile, files)

    if args.update_baseline:
        save_baseline(args.profile, findings)
        print(f"[verify] baseline updated: {baseline_path(args.profile)}")

    baseline = load_baseline(args.profile)
    new_findings: list[Finding] = []
    known_findings: list[Finding] = []

    for finding in findings:
        if finding.fingerprint() in baseline:
            known_findings.append(finding)
        else:
            new_findings.append(finding)

    summary = summarize(new_findings)

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "profile": args.profile,
        "checked_files": [f.relative_to(ROOT.parents[1]).as_posix() for f in files],
        "baseline_size": len(baseline),
        "known_findings": [f.__dict__ for f in known_findings],
        "known_count": len(known_findings),
        **summary,
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=True), encoding="utf-8")

    print(
        f"[verify] profile={args.profile} status={payload['status']} "
        f"new_fail={payload['fail_count']} new_warn={payload['warn_count']} known={payload['known_count']}"
    )
    print(f"[verify] report={REPORT_PATH}")

    if payload["fail_count"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
