---
tags: [vrct, chinese, index]
updated: 2026-09-26
---
# VRCT Chinese-English

Home note for getting better Chinese→English out of VRCT (VRChat translator), and a dictionary of what Chinese voice chat actually means when the machine translation gets it wrong.

## Setup
- [[VRCT Setup (Linux)]]: how VRCT runs on this PC, current settings, voice filter, restarting safely, known problems.

- [[Translator Brain]]: the style rules, names and corrections the translation bot follows. Edit it to change how translations sound.

## Research
- [[Translation Engines]]: which engine translates Chinese best without touching the GPU. **Short answer:** Gemini first, DeepL as fallback, HY-MT1.5-1.8B for offline, NLLB only as a last resort.
- [[VRCT Integration]]: how a dictionary can feed into VRCT (the Gemini prompt file), plus real mistranslations from the log.

## Dictionary (222 entries)
| Note | What's in it |
|---|---|
| [[Internet Slang]] | yyds, 破防, 摸鱼, 躺平, 笑死, awsl, 蚌埠住了… |
| [[Exclamations & Swearing]] | 卧槽, 牛逼, 草, 淦… each marked mild / rude / offensive |
| [[Gaming & VRChat]] | 大佬, 萌新, 开黑, 闭麦, 全身追踪, 老六… |
| [[People & Address]] | 老铁, 家人们, 宝子, 小姐姐… |
| [[Everyday Chat Phrases]] | 在吗, 干嘛呢, 随便, 加油, 辛苦了… |
| [[Number & Letter Codes]] | 666, 233, 88, 520, xswl, u1s1… |

> [!note] Less certain entries
> 老六 (two meanings in use), xs, nmsl, 兄dei, 集美, 宝宝, 妹子, and the VRChat room/world/controller words were not confirmed by a source. The "machine translates it as…" examples are predictions and weren't tested in NLLB.

## Adding to the dictionary
When VRCT mistranslates something, add a row to the matching note: Chinese | Pinyin | Literal | Natural English | Notes. Terms that matter most can also go into the Gemini prompt (see [[VRCT Integration]]).
