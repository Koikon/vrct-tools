---
tags: [vrct, setup, linux, vrchat]
updated: 2026-09-26
---
# VRCT Setup (Linux)

How VRCT (the VRChat translator) runs on this PC (Omarchy, RTX 4070, i7-13700F). VRCT is Windows-only, so it runs through umu/Proton. See [[VRCT Chinese-English]] for the translation side and [[Translation Router]] for the relay.

## Install
- VRCT's installer fails under Proton, so VRCT.zip (from huggingface.co/ms-software/VRCT) is unpacked straight into the umu prefix:
  `~/Games/umu/vrct/drive_c/users/steamuser/AppData/Local/VRCT`
- Launch with `vrct` (`~/.local/bin/vrct`) or the app launcher entry.
- The launcher:
  - refuses to start a second copy
  - repairs broken model tokenizer files (see below)
  - waits for the old Wine session to finish shutting down
  - retries once if VRCT quits right after "startup began"
- VRCT needs `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--no-sandbox --disable-gpu"`, or it exits silently. The launcher sets this.

## Current settings
Recommended for this PC, applied 2026-09-27. VRCT only offers the CPU under Wine, and RAM is the bottleneck: 15 GB, heavily swapping while VRChat runs.

| Setting | Value | Why |
|---|---|---|
| Translation engine (preset 1) | OpenAI Compatible → the [[Translation Router|relay]] (`http://127.0.0.1:8765/v1`, model `vrct-relay`) | Gemini with the [[Translator Brain]], DeepL as backup, language detection |
| Languages (preset 1) | English ↔ Chinese Simplified + Japanese | Two targets make Whisper auto-detect the language instead of forcing one |
| Speech recognition (`WHISPER_WEIGHT_TYPE`) | small, int8 | Much better than base for Chinese/Japanese, still fast on the i7-13700F |
| Offline translation fallback | nllb-200-distilled-600M, int8 | Only used if the relay is down. int8 instead of float32 saves about 2 GB of RAM |
| Record / phrase timeout | 2 s / 2 s | Whole sentences translate better than 1 s fragments |
| `AVG_LOGPROB` / `NO_SPEECH_PROB` | -1.0 / 0.4 (mic and speaker) | Drops text Whisper invents from silence and noise (`vrct-tune preset`) |
| Speaker device | Speakers (VRChat Voices) [Loopback] | Fed by the voice filter below. Auto speaker select must be off |

Backup of the settings before this change: `config.json.before-recommended`.

## Voice filter (friends' voices only)
`vrct-voice-filter` (systemd user service `vrct-voice-filter`) feeds the silent "VRChat Voices" sink, which VRCT listens to.
- **ON:** only VRChat's audio passes, through a loudness gate. Only voices within about the set radius get through, and Spotify and other apps are ignored.
- **OFF:** all desktop audio, ungated.
- **Radius:** follows VRChat's Earmuff Mode radius when earmuffs are on. This lags in-game changes by about 30 s, because Wine saves the registry that often.
- **Toggle:** **Super+Alt+V**.
- **Commands:** `vrct-voice-filter status | radius <m> | calibrate <m> | level | earmuffs on|off`.
- **Watchdog (added 2026-09-26):** `pw-cat` could stop taking audio without exiting, and VRCT then heard nothing from friends. The service now restarts the pipeline if audio stops moving for about 6 s.

## Language favorites
**Super+Alt+L** (`vrct-fav`) opens a picker of saved language pairs from `~/.config/vrct/favorites`. Picking one restarts VRCT, because VRCT can't take commands while running.

## Restarting VRCT safely
1. Close VRCT, or kill the process named `main` (VRCT.exe shows up under that name).
2. Wait for `VRCT-sidecar.exe` to exit. If it's still there after about 30 s, kill it by PID.
3. Run `vrct`.

> [!warning] Don't use `pkill -f` with VRCT paths
> It also matches the shell running the command and kills it. Kill by exact PID instead.

- **Translation toggle:** the Translation and mic toggles reset to off on every restart. Turn them back on.
- **Editing settings:** only edit `config.json` while VRCT is closed, or VRCT overwrites it.

## Known problems
- **Broken tokenizer files:** Wine can't create the symlinks in the Hugging Face model cache. It leaves 0-byte placeholder files instead, which break the NLLB tokenizer. `vrct-repair-tokenizers` replaces them, and the launcher runs it automatically.
- **"RuntimeError: Already borrowed":** a VRCT bug that happens when mic and speaker translations run at the same moment. Restarting VRCT fixes it.
- **Phrases glued together** ("tomorrowYes"): VRCT joins phrase pieces without a space. The fix is inside VRCT's compiled program and isn't patched.
- **Harmless shutdown noise:** `_writeStdoutLine OSError 22` lines in `error.log` come from an instance that's shutting down. Ignore them.

## VRChat side
- **OSC:** already on.
- **Steam launch option:** `~/.local/bin/vrchat-launch %command%` (use the full path, Steam does not expand `~`). It stops VRChat hanging at startup when the WiVRn server is running but the Quest isn't connected.
- **VR mode:** connect the Quest in WiVRn **before** launching VRChat.
