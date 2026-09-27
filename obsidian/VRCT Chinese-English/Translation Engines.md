---
tags: [vrct, chinese, translation, research]
updated: 2026-09-26
---
# Translation Engines (Chinese → English)

Which VRCT translation engine gives the best Chinese→English, without using the GPU (VRChat needs it) or much RAM (16 GB PC, already swapping). Researched 2026-09-26. See [[VRCT Chinese-English]] for the overview and [[VRCT Integration]] for how a dictionary could plug in.

## Ranked for this PC (RTX 4070, 16 GB RAM)
1. **Gemini Flash-Lite** (already has a key in VRCT): the best slang handling of these options, and it uses no local GPU or RAM. VRCT's LLM engines also get recent conversation history as context. Free tier is about 500–1,000 requests/day at 5–15/min, and Google changes these limits without notice.
2. **DeepL** (already has a key) as the fallback: 500,000 characters/month free, fast, never explains itself. Weaker on slang than an LLM.
3. **Tencent HY-MT1.5-1.8B** (Q4_K_M, about 1.1 GB) in Ollama or LM Studio, **forced onto the CPU**: the best offline upgrade over NLLB that fits in RAM.
4. **NLLB 1.3B** (current): keep only as the last resort. Don't move to 3.3B.

## For friends (Windows, RTX 2060 6 GB)
1. DeepL or Gemini: zero VRAM.
2. HY-MT1.5-1.8B on CPU (0 GPU layers).
3. VRCT's built-in CTranslate2 → NLLB 1.3B, device set to **CPU**.

## Evidence
### NLLB and M2M100 (VRCT's built-in offline models)
FLORES-200 chrF++, from Meta's metrics:

| Direction | 600M | 1.3B | 3.3B |
|---|---|---|---|
| Simplified → English | 52.9 | 55.3 | 56.2 |
| Traditional → English | 49.7 | 52.4 | 53.1 |

- 3.3B gains only about +0.9 over 1.3B for about 2.5× the RAM (one user measured 13–16 GB and 17–34 s per job). Not worth it on 16 GB.
- M2M100 scores below NLLB, so there's no reason to switch.
- **Slang is NLLB's weak spot.** It translates literally; a 2026 Chinese social-media benchmark shows LLMs doing clearly better on slang.
- VRCT's CTranslate2 model list is hard-coded, so you can't add your own models.

### Cloud
- Google Translate scored lowest on the FLORES Chinese benchmark (XCOMET 0.76 vs 0.88 for Hunyuan-MT-7B).

### Small local LLMs
| Model | Size (Q4) | Verdict |
|---|---|---|
| HY-MT1.5-1.8B | ~1.1 GB | ✅ Best fit. Tencent claims ~1 GB of memory and 0.18 s per short line, but that's their own number and probably measured on a GPU. |
| HY-MT1.5-7B / Hunyuan-MT-7B | ~4.5 GB | Top quality (beats Gemini-2.5-Pro on FLORES Chinese), but too big and slow on a PC that's already swapping |
| Seed-X-PPO-7B | ~4.5 GB | Lower than Hunyuan on Chinese, so skip |
| Qwen3 1.7B / 4B | small | General models, weaker at slang than a model tuned for translation |
| opus-mt-zh-en | tiny | Below NLLB, and VRCT can't use it anyway |

HY-MT prompt: `将以下文本翻译为English，注意只需要输出翻译后的结果，不要额外解释：{text}`

> [!warning] GPU safety
> Ollama and LM Studio use the GPU by default. Force CPU: in Ollama set `num_gpu 0` (or run with `CUDA_VISIBLE_DEVICES=""`); in LM Studio set GPU offload to 0 layers.

### Transcription is part of the problem
Bad transcription leads to bad translation. Whisper large-v3 gets about 12.6% character errors on Chinese, and turbo is probably slightly worse (OpenAI notes turbo drops more on some languages). SenseVoice-Small gets about 10.8%, but VRCT doesn't offer it. LLM translators recover from messy transcription better than NLLB does.

## Sources
- NLLB metrics: https://dl.fbaipublicfiles.com/large_objects/nllb/models/nllb_200_dense_3b/metrics.csv (also `nllb_200_dense_distill_1b`, `nllb_200_dense_distill_600m`)
- NLLB paper: https://arxiv.org/pdf/2207.04672
- NLLB-3.3B RAM/latency: https://whynothugo.nl/journal/2025/11/02/translation-models-between-english-and-chinese/
- Chinese social-media slang benchmark: https://arxiv.org/html/2601.22931
- VRCT engines: https://deepwiki.com/misyaguziya/VRCT/3.2.2-local-translation-engines
- DeepL Free: https://support.deepl.com/hc/en-us/articles/360021200939-DeepL-API-plans
- Gemini limits: https://ai.google.dev/gemini-api/docs/rate-limits
- Hunyuan-MT report: https://arxiv.org/html/2509.05209v1
- HY-MT1.5-1.8B: https://huggingface.co/tencent/HY-MT1.5-1.8B-GGUF , https://www.marktechpost.com/2026/01/04/tencent-researchers-release-tencent-hy-mt1-5-a-new-translation-models-featuring-1-8b-and-7b-models-designed-for-seamless-on-device-and-cloud-deployment/
- opus-mt: https://huggingface.co/Helsinki-NLP/opus-mt-zh-en
- Whisper turbo: https://github.com/openai/whisper/discussions/2363
- SenseVoice CER: https://arxiv.org/abs/2407.04051
