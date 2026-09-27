---
tags: [vrct, translation, relay, brain]
updated: 2026-09-27
---
# Translator Brain

What the translation bot knows about how people talk. [[Translation Router|vrct-relay]] rereads this note within 30 seconds of a save, and old cached translations are dropped so the new rules apply straight away. It works for every language: Chinese, Japanese, English and the rest.

How the three parts work together:
1. **Brain (this note + the [[VRCT Chinese-English|Dictionary]])**: the knowledge.
2. **Middle man (vrct-relay)**: detects the real language, answers from the brain when it can, and otherwise briefs the bot with the rules below plus any slang it finds in the line. It then checks the answer: untranslated leftovers, added explanations, quotes, or an echo of the input all get rejected, and the backup bot (DeepL) is asked instead.
3. **Bot (Gemini)**: turns the line into natural modern speech, following the brief.

## Note format
The relay reads this note and every note in `Dictionary/`. Any table can hold terms if its header has:
- a **term column**: `Chinese`, `Japanese` or `Korean` (applies only to lines in that language), or `Heard` / `Term` (applies to any language)
- a **meaning column**: `Natural English`, `Say instead`, `English` or `Meaning`

Other columns are ignored. `A / B` in a term cell means two spellings, and the text before ` / ` in a meaning is the one used. Normal Obsidian markdown works: frontmatter, `[[links|aliases]]`, **bold**, `\|` inside cells, and tables inside callouts. When a term appears twice, this note wins over the Dictionary. So a Japanese dictionary is just a new note in `Dictionary/` with a `| Japanese | ... | Natural English |` table.

## Style
- Sound like a friend talking in VRChat voice chat: casual, modern, short.
- Keep the speaker's tone: jokes, teasing, swearing and excitement stay as strong as in the original, never stronger. Don't add swearing that isn't there.
- Use the natural equivalent in slang (lol, bro, no way, let's go) instead of a word-for-word translation.
- Never add explanations, notes, quotes, romanization or alternatives. Only the line.
- If the line is only a filler sound (嗯, 啊, 哦, えっと, あの), output a short filler like "hmm", "uh" or "oh".
- Keep usernames, world names and avatar names as they are.

## Names
Never translated. Separate with commas or put one per line.
- YourFriendName

## Corrections
Whole-line match: the answer is given instantly, with no bot involved. Inside a longer line it's a hint to the bot. Use it for anything the bot keeps getting wrong, in any language.

| Heard | Say instead |
|---|---|
| よろしく | hi, nice to meet you |
| よろしくお願いします | nice to meet you |
| お疲れ様 | good work, thanks |
| お疲れ様です | good work, thanks |
| やばい | that's crazy |
| マジで | for real? |
| なるほど | I see |
| 嗯嗯 | mhm |
