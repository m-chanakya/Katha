#!/usr/bin/env python3
"""Content build: app/lib/data/word_bank.dart (flat Word/Category model)
+ content/concepts.json (hand-authored grammar) -> content/bundle.json
(six-entity model per STRATEGY.md section 5).

Idempotent -- safe to re-run. Lexemes/sentences/units are regenerated from
word_bank.dart every time; concepts are merged in from concepts.json, which
is the one hand-authored input. Never hand-edit content/bundle.json: it is
a build artifact and this script overwrites it.

This is a STRUCTURAL migration only. Register/formality/dialect tags are
left null ("unaudited": true) wherever the source data doesn't already
encode them -- STRATEGY.md section 9 makes that a native-speaker review
job, not something to guess here. See CLAUDE.md "Content debt" section.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "app" / "lib" / "data" / "word_bank.dart"
CONCEPTS = ROOT / "content" / "concepts.json"
OUT = ROOT / "content" / "bundle.json"

text = SRC.read_text(encoding="utf-8")

# --- categories -> units (one legacy unit per category, flat/no prereqs) ---
cat_re = re.compile(
    r"Category\(id:\s*'([^']*)',\s*label:\s*'([^']*)',\s*emoji:\s*'([^']*)'\)"
)
categories = [
    {"id": m.group(1), "label": m.group(2), "emoji": m.group(3)}
    for m in cat_re.finditer(text)
]
if not categories:
    sys.exit("No categories found -- source format changed, check regex.")

# --- words -> lexemes + sentences ---
words_start = text.index("static const List<Word> words")
words_text = text[words_start:]

# Each entry starts at "    Word(\n      id: '" -- split on that boundary.
entry_re = re.compile(r"\n    Word\(\n(.*?)\n    \),", re.DOTALL)

def field(pattern, block, default=None):
    m = re.search(pattern, block, re.DOTALL)
    return m.group(1) if m else default

def qfield(name, block, default=None):
    """Field whose value may be single- or double-quoted (some source
    strings use double quotes because they contain an apostrophe)."""
    m = re.search(name + r":\s*(['\"])((?:(?!\1).)*)\1", block, re.DOTALL)
    return m.group(2) if m else default

lexemes = []
sentences = []
sentence_seq = 0

for block in entry_re.findall(words_text):
    wid = field(r"id:\s*'([^']*)'", block)
    telugu = qfield("telugu", block)
    script = field(r"scriptForTts:\s*'((?:[^'\\]|\\.)*)'", block)
    english = qfield("english", block)
    category_id = field(r"categoryId:\s*'([^']*)'", block)
    pos = field(r"partOfSpeech:\s*'([^']*)'", block)
    tip = qfield("pronunciationTip", block)
    audio = field(r"audioAsset:\s*'([^']*)'", block)

    lexemes.append({
        "id": wid,
        "translit": telugu,
        "script": script,
        "gloss": english,
        "pos": pos,
        "legacyCategoryId": category_id,
        "register": None,
        "formalityLevel": None,
        "dialect": "standard",
        "pronunciationTip": tip,
        "audioVariants": {"default": audio} if audio else {"default": "tts"},
        "frequencyRank": None,
        "confusionLexemeIds": [],
        "unaudited": True,
    })

    # ExampleSentence(telugu: '...', english: "...")  -- quotes may be ' or "
    ex_re = re.compile(
        r"ExampleSentence\(\s*telugu:\s*(['\"])((?:(?!\1).)*)\1\s*,\s*english:\s*(['\"])((?:(?!\3).)*)\3\s*\)"
    )
    for em in ex_re.finditer(block):
        sentence_seq += 1
        sentences.append({
            "id": f"s_{wid}_{sentence_seq}",
            "translit": em.group(2),
            "translation": em.group(4),
            "lexemeIds": [wid],
            "characterId": None,
            "register": None,
            "scenarioId": None,
            "unaudited": True,
        })

if len(lexemes) < 50:
    sys.exit(f"Only parsed {len(lexemes)} lexemes -- expected ~85, check regex against source format.")

units = [{
    "id": f"legacy_{c['id']}",
    "title": c["label"],
    "emoji": c["emoji"],
    "sectionId": "legacy",
    "lexemeIds": [l["id"] for l in lexemes if l["legacyCategoryId"] == c["id"]],
    "conceptIds": [],
    "prerequisiteUnitIds": [],
} for c in categories]

# --- merge hand-authored concepts (content/concepts.json) ---
# Lexemes and sentences are DERIVED from word_bank.dart and get rebuilt on
# every run; concepts are AUTHORED and have no upstream source, so they
# live in their own file and are merged in here. That keeps this script
# idempotent -- rerunning it can't destroy authored content -- and keeps
# content/bundle.json a pure build artifact nobody should hand-edit.
concepts = []
if CONCEPTS.exists():
    authored = json.loads(CONCEPTS.read_text(encoding="utf-8"))
    units_by_id = {u["id"]: u for u in units}
    sentence_ids = {s["id"] for s in sentences}
    for c in authored.get("concepts", []):
        unit_id = c.pop("unitId", None)
        missing = [sid for sid in c.get("exampleSentenceIds", []) if sid not in sentence_ids]
        if missing:
            sys.exit(
                f"concept '{c['id']}' references example sentence(s) not in the bundle: {missing}\n"
                "Sentence ids are generated from word_bank.dart order, so they can shift when "
                "that file changes -- fix content/concepts.json rather than editing bundle.json."
            )
        c.setdefault("prerequisiteConceptIds", [])
        c.setdefault("bridge", {})
        c.setdefault("unaudited", True)
        concepts.append(c)
        if unit_id:
            if unit_id not in units_by_id:
                sys.exit(f"concept '{c['id']}' attaches to unknown unit '{unit_id}'")
            units_by_id[unit_id]["conceptIds"].append(c["id"])

bundle = {
    "schemaVersion": 1,
    "contentVersion": "2026.08.29-migration",
    "lexemes": lexemes,
    "forms": [],
    "concepts": concepts,
    "sentences": sentences,
    "scenarios": [],
    "units": units,
}

OUT.parent.mkdir(exist_ok=True)
OUT.write_text(json.dumps(bundle, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Migrated {len(lexemes)} lexemes, {len(sentences)} sentences, {len(units)} units, "
      f"{len(concepts)} authored concepts -> {OUT}")
