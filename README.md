# vrct-tools

Tools for [VRCT](https://github.com/misyaguziya/VRCT), the VRChat translator, tuned for Chinese and Japanese ↔ English voice chat. Made for Linux (VRCT through Proton), with the relay and tuning also on **Windows** and the relay on **macOS**.

| | Linux | Windows | macOS |
|---|---|---|---|
| `vrct-relay` + Obsidian brain | ✅ `systemd/` | ✅ `windows/Install relay.bat` | ✅ `macos/install-relay.sh` |
| Tuning (preset, models) | ✅ `vrct-tune` | ✅ `windows/VRCT Tune.bat` | – |
| Voice filter (VRChat voices only) | ✅ PipeWire | – | – |
| Launcher, favorites, tokenizer repair | ✅ | – (VRCT is native) | – |

VRCT and VRChat don't run on macOS, so a Mac acts as the relay for VRCT on other PCs in the same network.

- **`vrct-relay`**: a translation router that VRCT uses as its "OpenAI Compatible" engine. It can also serve friends on the same home network.
- **Voice filter**: VRCT only hears VRChat voices near you, not music or other apps.
- **Launcher and helpers**: start VRCT reliably under Wine, apply a tuned preset, and switch language pairs quickly.
- **Obsidian notes**: the relay's knowledge base (style rules, corrections, and a Chinese slang dictionary with about 270 terms).

## How the relay works

Obsidian is the **brain**, the relay is the **middle man**, and Gemini is the **bot**.

1. **Language.** The real language of each line is detected from its script (kana → Japanese, hangul → Korean, Han → Chinese or Japanese, ASCII → English). VRCT's label is often wrong, so it isn't trusted.
2. **Direction.** Each line goes to the opposite language of VRCT's pair: Chinese heard becomes English, and English heard becomes Chinese. A language outside the preset is left as it is.
3. **Brain.** A line that is a known term or correction is answered instantly from the notes, with no network call.
4. **Bot.** Everything else goes to Gemini, with a brief that includes the Style rules, Names, and any slang found in the line. DeepL is the backup.
5. **Check.** Every answer is checked for untranslated leftovers, echoes of the input, explanations, and junk text. A rejected answer goes to the other bot.

The relay also has a cache, merges identical lines that are already being translated, pauses a failing upstream for a while, and races the backup when the first bot is slow. See `obsidian/VRCT Chinese-English/Translation Router.md`.

## Requirements

- Linux with PipeWire, `python3` (3.10+), `jq`, `curl`, `notify-send`
- [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) and GE-Proton
- VRCT unpacked (not installed) into a umu prefix at `~/Games/umu/vrct/drive_c/users/steamuser/AppData/Local/VRCT`. VRCT's installer fails under Proton, so use `VRCT.zip` from [huggingface.co/ms-software/VRCT](https://huggingface.co/ms-software/VRCT).
- For the relay: a Gemini and/or DeepL API key, entered in VRCT's own settings. The relay reads them from VRCT's `config.json`.
- `vrct-fav` uses `omarchy-menu-select` ([Omarchy](https://omarchy.org)). Swap in any dmenu-style picker if you don't use Omarchy.

## Install (Linux)

```sh
install -Dm755 bin/* -t ~/.local/bin/
install -Dm644 lib/vrct-voice-filter/*.py -t ~/.local/lib/vrct-voice-filter/
install -Dm644 systemd/*.service -t ~/.config/systemd/user/
install -Dm644 pipewire/vrchat-voices.conf -t ~/.config/pipewire/pipewire.conf.d/
systemctl --user restart pipewire
systemctl --user daemon-reload
systemctl --user enable --now vrct-relay vrct-voice-filter
```

Copy `obsidian/VRCT Chinese-English` into your Obsidian vault. Then point the relay at it: `systemctl --user edit vrct-relay`, and add

```ini
[Service]
Environment=VRCT_BRAIN_DIR=%h/path/to/vault/VRCT Chinese-English
```

## Install (Windows)

Needs [Python 3.8+](https://www.python.org/downloads/) (tick "Add python.exe to PATH") and VRCT installed normally.

1. Download this repo (Code → Download ZIP) and unzip it.
2. Double-click **`windows/Install relay.bat`**. It copies the relay and the notes (to `Documents\VRCT Brain`), adds the relay to startup (no admin needed), starts it, and prints what to enter in VRCT. Keys are read from VRCT's own settings; if there are none, it asks for them.
3. In VRCT → Settings → Translation, choose **OpenAI Compatible** with the printed URL, key and model.
4. Optional: double-click **`windows/VRCT Tune.bat`** for the tuning menu. It sets up the preset, uses an NVIDIA card for speech-to-text with VRCT's CUDA edition, and picks models that fit the PC.

To remove it: `powershell -ExecutionPolicy Bypass -File windows\install-relay.ps1 -Uninstall`.

## Install (macOS)

```sh
git clone https://github.com/Koikon/vrct-tools.git
cd vrct-tools
./macos/install-relay.sh
```

It asks for a Gemini and/or DeepL key (saved to `~/Library/Application Support/vrct-relay/keys.json`, readable only by you), copies the notes to `~/Documents/VRCT Brain`, and runs the relay as a LaunchAgent at login (log: `~/Library/Logs/vrct-relay.log`). On the Windows or Linux PCs running VRCT, set **OpenAI Compatible** to the URL it prints. `./macos/install-relay.sh uninstall` removes it.

## Using it

| Command | What it does |
|---|---|
| `vrct` | Launch VRCT. Won't start a second copy, repairs broken tokenizer files, and retries once if VRCT quits on startup |
| `vrct-relay info` | The URL, key and model to enter in VRCT → Settings → Translation → OpenAI Compatible |
| `vrct-relay stats` | How many lines took each path (brain, skip, cache, gemini, deepl…) and how fast |
| `vrct-tune preset` | Apply the tuned transcription preset (hallucination filter, 2 s chunks) |
| `vrct-voice-filter toggle` | VRChat voices only (on) or all desktop audio (off). Also `radius`, `calibrate`, `earmuffs` |
| `vrct-fav` | Pick a saved language pair; `vrct-fav add` saves the current one |

In VRCT, set the speaker device to **Speakers (VRChat Voices) [Loopback]** and turn auto speaker select off. Enable more than one target language (e.g. Chinese + Japanese): with a single target, VRCT forces Whisper to hear everything as that language.

### Teaching the brain

Edit `Translator Brain.md`. The relay picks up changes within 30 seconds and drops old cached translations.

- **Style**: bullets telling the bot how to sound.
- **Names**: never translated.
- **Corrections**: a `| Heard | Say instead |` table. A whole-line match is answered instantly; inside a longer line it's a hint to the bot.

Any note in `Dictionary/` works too. A table only needs a term column (`Chinese`, `Japanese`, `Korean`, `Heard` or `Term`) and a meaning column (`Natural English`, `Say instead`, `English` or `Meaning`).

## Notes

- The relay only answers private and loopback addresses and needs its password (`~/.config/vrct-relay/password`, created on first run). Friends share 30 network calls per minute; your own VRCT isn't limited.
- If the relay is unreachable, VRCT switches to its offline engine for the rest of the session. Don't restart the relay mid-session.
- **Content warning:** the dictionary documents Chinese profanity and insults, each marked mild, rude or offensive.
- The paths assume the umu prefix location above. `vrchat-launch` and the WiVRn notes mentioned in `VRCT Setup (Linux).md` aren't part of this repo.

## License

MIT. See [LICENSE](LICENSE).
