---
tags: [vrct, chinese, translation, research]
updated: 2026-09-26
---
# VRCT Integration: how a dictionary can reach VRCT

Checked against VRCT v3.5.1 (the installed build), the `develop` branch, and the local install. See [[VRCT Chinese-English]] and [[Translation Engines]].

## What VRCT has
- **No glossary or term-replacement feature.**
- `USE_EXCLUDE_WORDS` only affects **typed** messages. It protects `![text]` from translation and never touches mic or speaker transcription.
- The word filter (`MIC_WORD_FILTER`) **drops whole messages**; it can't replace a word. It applies to mic and speaker, and it matches whole words anywhere in a sentence, so short common words like "you" can't go in it.
- Plugins (v3.5.1) are UI-only React components and can't change translations. The plugin system looks removed in `develop`.

## The hook that works: LLM prompt files
Each LLM engine reads its system prompt from a YAML file:
`~/Games/umu/vrct/drive_c/users/steamuser/AppData/Local/VRCT/_internal/translation_settings/prompt/translation_{gemini,ollama,lmstudio,openai_compatible,…}.yml`

- Add dictionary entries under `system_prompt:`, e.g. `Glossary (always use): 牛逼 = awesome; 666 = nice!; 破防 = that got to me`.
- Write literal `{` `}` as `{{` `}}` (the prompt goes through `.format()`).
- Also add: "input is noisy speech-to-text; infer the intended meaning".
- Restart VRCT after editing. **A VRCT update overwrites these files**, so keep a copy.
- It **only works with an LLM engine** (Gemini, OpenAI-compatible, Ollama…), **not CTranslate2/NLLB**, which has no hook. Gemini is already set up and valid (`gemini-2.5-flash`) and runs in the cloud: no GPU, and it frees NLLB's RAM.

## Other hooks (worse)
| Hook | Verdict |
|---|---|
| Local OpenAI-compatible proxy (find/replace, then forward to Gemini or DeepL) | Works, ~1–2 h of work, ~30 MB RAM. Only needed for strict find-and-replace. |
| WebSocket (port 2231) | Outbound only, and fires after the chatbox is already sent. Can't fix what VRChat receives. |
| OSC relay | Doable but fiddly; bad translations already reach the chatbox. |
| Local Ollama / LM Studio | Needs RAM or GPU, and this PC is already swapping. |

## Real mistakes from VRCT's log (Sep 26)
**Chinese → English (received):**
| Chinese | VRCT said | Better |
|---|---|---|
| 第一个闪音讲话这样他就能听懂 | "The first flash speaks so he can hear." | Guess: "Speak first so he can understand." (听懂 = understand; 闪音 looks like a transcription error) |
| 我让我押击点 | "I let myself bet." | Garbled transcription, so no dictionary can fix it |
| 温馨Talking to you | "Talking to you" | 温馨 ("warm/cozy") was dropped |
| 感谢观看 | "Thank you for watching." | Whisper hallucination: now in the filter |

**English → Chinese (sent), worth knowing:**
| You said | VRCT sent | Problem |
|---|---|---|
| No, I have safety | 没有,我有**安全套** | ⚠️ means "I have a **condom**" |
| Yeah I break mine | 打破了我的 | "physically smashed it" |
| Let me breathe up there in a minute | 让我在一分钟内呼吸 | Too literal |
| My CPU is running at 55% | 我的CPU正在55%运行 | Better: 我的CPU占用率55% |

## Recommendation
1. Switch the translation engine to **Gemini** (at least for received Chinese; ideally both directions).
2. Put the key terms from the [[Internet Slang]], [[Exclamations & Swearing]] and [[Number & Letter Codes]] notes, plus the "noisy speech-to-text" hint, into `translation_gemini.yml`.
3. Keep **DeepL** as the fallback when Gemini hits its per-minute limit.

## Sources
- https://github.com/misyaguziya/VRCT (master v3.5.1: `src-python/controller.py:762-768, 3226-3262, 398, 578, 1725-1731`; `model.py:988-992, 1492-1494`; `models/translation/translation_utils.py:170-183`; `translation_gemini.py:115`; `translation_openai_compatible.py:18-58`; `translation_translator.py:467-486`)
- https://misyaguziya.github.io/VRCT-Docs/
- Plugins: https://github.com/ShiinaSakamoto/vrct_plugins_list , https://github.com/ShiinaSakamoto/vrct_plugin_subtitles
