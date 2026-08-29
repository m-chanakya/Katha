#!/usr/bin/env python3
"""Content quality gates -- STRATEGY.md section 9.

Run: python3 scripts/validate_content.py content/bundle.json

Exit code 0 = pass (warnings allowed), 1 = fail (blocking errors).
Two severities on purpose: some checks are genuinely blocking today
(a broken id reference is always a bug); others are known content debt
from the Phase A structural migration (register audit, sentence
tokenization) and are WARNINGS until that audit happens, so CI doesn't
red-line on a stale-but-honest content set. See CLAUDE.md.
"""
import json
import sys
from pathlib import Path
from collections import defaultdict

def main():
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "content/bundle.json")
    bundle = json.loads(path.read_text(encoding="utf-8"))

    errors = []
    warnings = []

    lexemes = bundle.get("lexemes", [])
    forms = bundle.get("forms", [])
    concepts = bundle.get("concepts", [])
    sentences = bundle.get("sentences", [])
    scenarios = bundle.get("scenarios", [])
    units = bundle.get("units", [])

    lexeme_ids = {l["id"] for l in lexemes}
    concept_ids = {c["id"] for c in concepts}
    unit_ids = {u["id"] for u in units}
    sentence_ids = {s["id"] for s in sentences}
    scenario_ids = {sc["id"] for sc in scenarios}

    # --- required fields ---
    for l in lexemes:
        for req in ("id", "translit", "gloss", "pos"):
            if not l.get(req):
                errors.append(f"lexeme missing required field '{req}': {l.get('id')}")

    # --- duplicate ids ---
    def check_dupes(items, label):
        seen = defaultdict(int)
        for it in items:
            seen[it["id"]] += 1
        for k, v in seen.items():
            if v > 1:
                errors.append(f"duplicate {label} id '{k}' ({v} times)")
    check_dupes(lexemes, "lexeme")
    check_dupes(concepts, "concept")
    check_dupes(units, "unit")
    check_dupes(sentences, "sentence")

    # --- reference resolution ---
    for s in sentences:
        for lid in s.get("lexemeIds", []):
            if lid not in lexeme_ids:
                errors.append(f"sentence {s['id']} references unknown lexeme '{lid}'")
        if s.get("scenarioId") and s["scenarioId"] not in scenario_ids:
            errors.append(f"sentence {s['id']} references unknown scenario '{s['scenarioId']}'")

    for f in forms:
        if f.get("lexemeId") not in lexeme_ids:
            errors.append(f"form {f.get('id')} references unknown lexeme '{f.get('lexemeId')}'")

    for u in units:
        for lid in u.get("lexemeIds", []):
            if lid not in lexeme_ids:
                errors.append(f"unit {u['id']} references unknown lexeme '{lid}'")
        for cid in u.get("conceptIds", []):
            if cid not in concept_ids:
                errors.append(f"unit {u['id']} references unknown concept '{cid}'")
        for pid in u.get("prerequisiteUnitIds", []):
            if pid not in unit_ids:
                errors.append(f"unit {u['id']} references unknown prerequisite unit '{pid}'")

    for c in concepts:
        for pid in c.get("prerequisiteConceptIds", []):
            if pid not in concept_ids:
                errors.append(f"concept {c['id']} references unknown prerequisite concept '{pid}'")

    # --- prerequisite graph walk: no cycles (units) ---
    def has_cycle(nodes, edges_of):
        WHITE, GRAY, BLACK = 0, 1, 2
        color = {n: WHITE for n in nodes}

        def visit(n, stack):
            color[n] = GRAY
            for m in edges_of(n):
                if m not in color:
                    continue
                if color[m] == GRAY:
                    errors.append(f"prerequisite cycle: {' -> '.join(stack + [n, m])}")
                    return True
                if color[m] == WHITE and visit(m, stack + [n]):
                    return True
            color[n] = BLACK
            return False

        for n in nodes:
            if color[n] == WHITE:
                if visit(n, []):
                    return True
        return False

    has_cycle(unit_ids, lambda n: next((u["prerequisiteUnitIds"] for u in units if u["id"] == n), []))
    has_cycle(concept_ids, lambda n: next((c.get("prerequisiteConceptIds", []) for c in concepts if c["id"] == n), []))

    # --- orphan check: lexeme in no unit and no sentence ---
    referenced = set()
    for u in units:
        referenced.update(u.get("lexemeIds", []))
    for s in sentences:
        referenced.update(s.get("lexemeIds", []))
    orphans = lexeme_ids - referenced
    if orphans:
        warnings.append(f"{len(orphans)} orphan lexeme(s) (in no unit or sentence): {sorted(orphans)[:10]}{'...' if len(orphans) > 10 else ''}")

    # --- register completeness (WARN -- audit not done yet, see STRATEGY sec 9) ---
    unaudited = [l["id"] for l in lexemes if l.get("register") is None]
    if unaudited:
        warnings.append(f"{len(unaudited)}/{len(lexemes)} lexemes have no register/formality tag yet (native-speaker audit pending)")

    # --- sentence tokenization (WARN -- not implemented yet, sentences are untokenized translit strings) ---
    untokenized = [s["id"] for s in sentences if "tokens" not in s]
    if untokenized:
        warnings.append(f"{len(untokenized)}/{len(sentences)} sentences are untokenized (no per-word Form linkage yet)")

    # --- transliteration scheme conformance ---
    # STRATEGY sec 13 open question #1: does the scheme mark retroflexion?
    # Not resolved yet, so this is a WARN reporting inconsistency, not an
    # enforced rule -- flip to a real check once the scheme is locked.
    has_caps = [l["id"] for l in lexemes if l.get("translit") and any(c.isupper() for c in l["translit"][1:])]
    if has_caps:
        warnings.append(f"{len(has_caps)} lexeme(s) use mid-word capitals (possible retroflex marking, scheme unresolved -- STRATEGY sec 13 Q1): {has_caps[:5]}{'...' if len(has_caps) > 5 else ''}")

    print(f"Checked {len(lexemes)} lexemes, {len(concepts)} concepts, {len(sentences)} sentences, {len(units)} units.")
    if warnings:
        print(f"\n{len(warnings)} warning(s):")
        for w in warnings:
            print(f"  WARN: {w}")
    if errors:
        print(f"\n{len(errors)} error(s):")
        for e in errors:
            print(f"  ERROR: {e}")
        print("\nFAILED")
        sys.exit(1)
    print("\nPASSED" + (" (with warnings)" if warnings else ""))

if __name__ == "__main__":
    main()
