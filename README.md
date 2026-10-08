# Podcast Transcriber

Paste a podcast episode link, get a transcript. It runs locally on your Mac with [whisper.cpp](https://github.com/ggml-org/whisper.cpp), so nothing is uploaded anywhere.

It works with:
- **An episode web page.** It finds the `.mp3` the page's player uses.
- **A direct audio link** (`.mp3`, `.m4a`…).
- **A YouTube link**, via `yt-dlp`.
- **An audio file** on your Mac.

You get `transcript.txt` and a timestamped `transcript.srt` in `~/Downloads/transcripts/<episode>/`.

It's a [Claude Code](https://claude.com/claude-code) skill, and the script also works on its own from Terminal.

## Install

```bash
git clone https://github.com/SYDROUXBA5/podcast-transcriber ~/.claude/skills/podcast-transcriber
```

First-time setup installs `ffmpeg`, `whisper-cpp` and `yt-dlp` with [Homebrew](https://brew.sh) and downloads the default model (466 MB):

```bash
~/.claude/skills/podcast-transcriber/scripts/transcribe.sh --setup
```

## Use

**In Claude Code:** paste a link and ask for a transcript, or type `/podcast-transcriber`. Claude checks your setup and finds the audio. Then it either runs the transcription or hands you the command, and it offers notes when the transcript is ready.

**From Terminal:**

```bash
~/.claude/skills/podcast-transcriber/scripts/transcribe.sh 'https://example-show.com/episode-42/'
```

| Flag | Effect |
|---|---|
| `--dry-run` | show the audio link it found and where files will go, without downloading |
| `--fast` | `base.en` model, about 3× quicker, a few more misheard words |
| `--any-language` | multilingual model with automatic language detection |
| `--model NAME` | any whisper.cpp model, e.g. `medium.en` (run `--setup --model NAME` first) |
| `--name SLUG` / `--out DIR` | choose the folder name / parent folder |
| `--no-srt` / `--keep-wav` / `--no-open` | skip the .srt / keep the WAV / don't open the result |
| `--check` | list what's installed |

## How long it takes

A 1 h 44 min episode on an Apple-silicon Mac with the default `small.en` model:

| Step | Time |
|---|---|
| Download (119 MB) | 23 s |
| Convert | 4 s |
| Transcribe | 3 min 9 s |

## When it doesn't work

- **The page has no `.mp3` link and yt-dlp can't find audio.** Right-click the player's download button, copy the link, and pass that link instead.
- **Spotify episodes.** They're DRM-locked. Use the show's own site or Apple Podcasts.
- **Members-only episodes.** Anything behind a login won't download.
- **Proper names.** Whisper spells by sound, so check names against the show notes.

## Fair use

Transcripts of other people's shows are for your own study, search and note-taking. The episode is still the show's copyrighted work, so don't republish the text. If you need a public transcript, ask the show.

## License

MIT
