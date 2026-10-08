---
name: podcast-transcriber
description: Transcribe a podcast episode, YouTube video or audio file locally on a Mac with whisper.cpp. Takes an episode web page (it finds the .mp3 the player uses), a direct audio link, a YouTube link or a local file, and writes transcript.txt plus a timestamped transcript.srt. Nothing is uploaded. Use when the user asks to transcribe a podcast, an episode link or a recording ("transcribe this episode", "get me a transcript of this podcast", "turn this audio into text", "/podcast-transcriber"), or wants notes from an episode that has no published transcript.
---

# Podcast Transcriber

The work is done by `scripts/transcribe.sh` in this skill's folder (normally `~/.claude/skills/podcast-transcriber/scripts/transcribe.sh`). Always call it by its absolute path.

It runs four steps:
1. Gets the audio. For an episode page it reads the HTML and takes the first `.mp3`/`.m4a` link, which is the file the web player streams. Embedded-player links (`…/?media_url=…`) are skipped. If there's no link, or the source is YouTube, it uses `yt-dlp`.
2. Converts the audio to 16 kHz mono WAV with `ffmpeg`.
3. Transcribes with `whisper-cli` and writes `transcript.txt`, plus `transcript.srt` unless `--no-srt` is set.
4. Deletes the WAV and opens the transcript.

Output goes to `~/Downloads/transcripts/<slug>/`.

## Workflow

1. **Check the tools.** Run `transcribe.sh --check`. If anything is missing, show the user `transcribe.sh --setup` and ask before running it. It installs Homebrew packages and downloads a model of 142–466 MB.
2. **Dry run.** Run `transcribe.sh --dry-run '<link>'`. It prints the type, the audio link it found and the output folder, and downloads nothing. If no audio link is found and the source isn't YouTube, read the troubleshooting section below before going further.
3. **Decide who runs the full command.**
   - **The user's own audio** (their show, their recording, a call they made) **or openly licensed audio** (public domain, Creative Commons): run it yourself in the background. Redirect output to a log (`> transcribe.log 2>&1`) and read only its `tail`, because Whisper prints every line it hears.
   - **Someone else's show:** give the user the one-line command to run in their own Terminal. The transcript is their personal study copy of a copyrighted work. Don't paste it into the chat, don't put the full text into files or pages you create, and never publish it.
4. **Offer notes.** Once `transcript.txt` exists, offer a summary, a section outline with timestamps taken from the `.srt`, the key claims and figures, and at most a few short quotes of under 15 words each.
   - Long episodes run to 15–20k words. Read them in chunks or hand the summarising to a cheaper sub-agent.
   - **Verify before presenting.** Grep the `.srt` for every number, name and quote in the notes. Summarisers drift: they invent quotes, add claims the speakers never made, and get timestamps wrong by up to 15 minutes. Remove or correct anything you can't find.

## Options

| Flag | Effect |
|---|---|
| `--fast` | `base.en` model, about 3× quicker, more misheard words |
| `--any-language` | multilingual `small` model with automatic language detection (French, Spanish…) |
| `--model NAME` | any whisper.cpp ggml model, e.g. `medium.en` (needs `--setup --model NAME` first) |
| `--name SLUG` | folder name instead of the one taken from the link |
| `--out DIR` | parent folder (default `~/Downloads/transcripts`, or `$TRANSCRIPTS_DIR`) |
| `--no-srt` / `--keep-wav` / `--no-open` | skip the .srt / keep the WAV / don't open the result |

Models live in `~/.whisper-models` (or `$WHISPER_MODELS_DIR`).

## Troubleshooting

- **No `.mp3` link on the page and yt-dlp fails.** Ask the user to right-click the player's download button, choose Copy Link, and pass that link instead.
- **Spotify.** The script refuses Spotify links because the episodes are DRM-locked. Find the same episode on the show's website or on Apple Podcasts.
- **Login or member-only episodes.** These won't download this way.
- **"isn't playable audio".** The download was an HTML page. Use a direct audio link.
- **Misheard names.** Whisper spells by sound (for example, Furton becomes "Ferton"). Flag likely mishearings with [?] in notes and check them against the show notes.

## Timing

For reference, a 1 h 44 min episode (119 MB) on an Apple-silicon Mac with `small.en` took 23 s to download, 4 s to convert and 3 min 9 s to transcribe. A CPU-only run (in a sandbox without the GPU) took about 17× longer.
