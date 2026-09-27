---
tags: [vrct, translation, relay]
updated: 2026-09-27
---
# Translation Router (vrct-relay)

The relay on this PC (`~/.local/bin/vrct-relay`, service `vrct-relay`) answers VRCT translation requests for this PC and for friends on the home network. For each line it takes the cheapest path that gives a good answer. It uses about 20 MB of RAM (capped at 300 MB).

## Three parts
- **Brain:** [[Translator Brain]] (style rules, names, corrections for any language) plus the Dictionary. Edits apply within 30 seconds, and the cache is cleared so they take effect.
- **Middle man:** this relay. It detects the language, answers from the brain when it can, and otherwise briefs the bot. It checks every answer and rejects untranslated leftovers, echoes, explanations, junk Latin text in Chinese/Japanese output, and quotes or "Translation:" prefixes (these get stripped). A rejected answer goes to the other bot. If nothing better comes back, the best rejected answer is used, because an error would make VRCT switch to its offline engine.
- **Bot:** Gemini, briefed with the brain. DeepL is the backup (it can't follow the brief, so it's ranked 3× slower than it really is).

## Language detection and direction
The relay doesn't trust the language VRCT puts on a line. It reads each line's script: kana means **Japanese** (even when mixed with kanji), hangul means **Korean**, Han-only text means Chinese or Japanese (whichever the preset uses), and plain ASCII means **English**.

Every line goes to the **opposite language** of the pair VRCT set (your language ↔ target language):
- Target language heard (Chinese/Japanese) → your language (English).
- Your language heard (English) → the target language.
- A language that isn't in the preset (e.g. Korean on English ↔ Chinese) is left as it is.

For this PC's own VRCT, the relay also reads the selected preset from VRCT's config. Any enabled target language then counts, which matters because VRCT labels Japanese lines "Chinese" when both are enabled. Friends' requests only have the pair from their prompt.

## Paths (first match wins)
1. **Brain:** the whole line is a term in [[Translator Brain]] or the [[VRCT Chinese-English|Dictionary]] (Dictionary terms apply to Chinese lines only), answered instantly and offline. Note edits are picked up within about 30 seconds.
2. **Skip:** the line isn't in any of the preset's languages, so it's returned as-is.
3. **Cache:** the same line was translated recently. It remembers 5,000 lines and survives restarts. Width, case, spaces and punctuation at the ends are ignored when matching.
4. **Coalesce:** the same line is already being translated (friends hearing the same speaker), so it shares that one request.
5. **Network:** the healthiest upstream first.
   - Tracks each upstream's average speed and error rate.
   - A `429` or 3 failures in a row pause that upstream (for Retry-After, or 30 seconds).
   - If the first upstream is slower than usual (2× its average, 1.2–4 s), the next one is raced against it and the first answer wins.
   - Terms found inside the line are sent to Gemini as hints, with the brain's style rules and names.

Upstreams: **Gemini** (`gemini-flash-lite-latest`) and **DeepL** (backup). Friends together get 30 network calls per minute; dictionary, skip and cache hits don't count toward that.

## Measured (2026-09-26)
| Path | Time |
|---|---|
| dictionary / skip / cache | 1–17 ms |
| Gemini | ~600–900 ms |
| 4 friends, same line | 1 Gemini call |

## Commands
- `vrct-relay info`: what friends type into VRCT
- `vrct-relay stats`: how many lines took each path, and how fast
- `systemctl --user restart vrct-relay`: after editing the script
