#!/usr/bin/env bash
# transcribe.sh: turn a podcast episode link, YouTube link or audio file into a
# local Whisper transcript (transcript.txt + transcript.srt). Nothing is uploaded.
set -euo pipefail
shopt -s nocasematch

MODEL="small.en"
SRT=1
KEEP_WAV=0
OPEN=1
DRY_RUN=0
NAME=""
MODE="run"
SRC=""
OUT_ROOT="${TRANSCRIPTS_DIR:-$HOME/Downloads/transcripts}"
MODELS_DIR="${WHISPER_MODELS_DIR:-$HOME/.whisper-models}"
MODEL_BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
AUDIO_RE="https?://[^\"'<> ?]+\.(mp3|m4a)"   # "?" excluded so embedded-player links (…/?media_url=…mp3) are skipped

usage() {
  cat <<'EOF'
Usage: transcribe.sh [options] <episode-link | youtube-link | audio-file>
       transcribe.sh --check  [--model NAME]
       transcribe.sh --setup  [--model NAME]

Options:
  --model NAME     Whisper model (default small.en). Common: base.en, small.en, small, medium.en
  --fast           Same as --model base.en (about 3x quicker, less accurate)
  --any-language   Same as --model small, language detected automatically
  --name SLUG      Folder name (default: taken from the link)
  --out DIR        Parent folder (default: ~/Downloads/transcripts, or $TRANSCRIPTS_DIR)
  --no-srt         Skip the timestamped .srt
  --keep-wav       Keep the 16 kHz WAV
  --no-open        Don't open the transcript when done
  --dry-run        Find the audio and print the plan without downloading
  --check          Report which tools and models are installed
  --setup          Install ffmpeg, whisper-cpp and yt-dlp with Homebrew, then download the model
EOF
}

log() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

model_file() { printf '%s/ggml-%s.bin' "$MODELS_DIR" "$MODEL"; }

check() {
  local ok=1 t
  for t in curl ffmpeg whisper-cli; do
    if has "$t"; then log "ok        $t"; else log "missing   $t"; ok=0; fi
  done
  if has yt-dlp; then log "ok        yt-dlp"; else log "optional  yt-dlp (needed for YouTube, and pages without an .mp3 link)"; fi
  if [ -f "$(model_file)" ]; then log "ok        model $MODEL"; else log "missing   model $MODEL ($(model_file))"; ok=0; fi
  if [ "$ok" = 1 ]; then
    log "Ready."
  else
    log "Fix with: $0 --setup --model $MODEL"
    return 1
  fi
}

setup() {
  has brew || die "Homebrew is needed first: https://brew.sh"
  brew install ffmpeg whisper-cpp yt-dlp
  mkdir -p "$MODELS_DIR"
  if [ ! -f "$(model_file)" ]; then
    log "Downloading ggml-$MODEL.bin..."
    curl -fL --progress-bar -o "$(model_file).part" "$MODEL_BASE_URL/ggml-$MODEL.bin"
    mv "$(model_file).part" "$(model_file)"
  fi
  check
}

clean_name() {
  local s
  s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -c 'a-z0-9._-' '-' | tr -s '-')
  s="${s#-}"; s="${s:0:60}"; s="${s%-}"
  printf '%s' "${s:-episode}"
}

slug_from() {
  local u="$1" s
  case "$u" in
    *youtu.be/*)       s="youtube-${u#*youtu.be/}"; s="${s%%[?&#]*}" ;;
    *youtube.com/*v=*) s="youtube-${u#*v=}";        s="${s%%[&#]*}" ;;
    *)                 s="${u%%[?#]*}"; s="${s%/}"; s="${s##*/}"
                       case "$s" in *.mp3|*.m4a|*.aac|*.wav|*.ogg|*.flac|*.opus|*.aiff) s="${s%.*}" ;; esac ;;
  esac
  s=$(printf '%b' "${s//%/\\x}")   # undo %-encoding
  clean_name "$(printf '%s' "$s" | LC_ALL=C tr -c 'a-zA-Z0-9' '-')"
}

find_audio() {
  curl -sL -A "Mozilla/5.0 (Macintosh)" "$1" | sed 's#\\/#/#g' | grep -oiE "$AUDIO_RE" | head -1 || true
}

ytdlp() {
  has yt-dlp || die "yt-dlp is needed for this link. Install it with: brew install yt-dlp"
  yt-dlp -q --progress -x --audio-format mp3 -o 'audio.%(ext)s' "$SRC" \
    || die "Couldn't get audio from that link. Right-click the player's download button, copy the link, and pass that instead."
}

need_val() { [ "$2" -ge 2 ] || die "$1 needs a value (see --help)"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --model)        need_val "$1" $#; MODEL="$2"; shift 2 ;;
    --fast)         MODEL="base.en"; shift ;;
    --any-language) MODEL="small"; shift ;;
    --name)         need_val "$1" $#; NAME="$2"; shift 2 ;;
    --out)          need_val "$1" $#; OUT_ROOT="$2"; shift 2 ;;
    --no-srt)       SRT=0; shift ;;
    --keep-wav)     KEEP_WAV=1; shift ;;
    --no-open)      OPEN=0; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --check)        MODE="check"; shift ;;
    --setup)        MODE="setup"; shift ;;
    -h|--help)      usage; exit 0 ;;
    -*)             die "Unknown option $1 (see --help)" ;;
    *)              SRC="$1"; shift ;;
  esac
done

case "$MODE" in
  check) check; exit $? ;;
  setup) setup; exit $? ;;
esac

[ -n "$SRC" ] || { usage; exit 1; }

# What kind of source is it?
if [ -f "$SRC" ]; then
  KIND="file"
  SRC="$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")"
else
  case "$SRC" in
    http://*|https://*|file://*) ;;
    *) die "Not a link or an existing file: $SRC" ;;
  esac
  case "$SRC" in
    *youtube.com/*|*youtu.be/*) KIND="youtube" ;;
    *spotify.com/*) die "Spotify episodes are locked and can't be downloaded. Use the show's own episode page or Apple Podcasts instead." ;;
    *) case "${SRC%%[?#]*}" in
         *.mp3|*.m4a|*.aac|*.wav|*.ogg|*.flac|*.opus) KIND="audio" ;;
         *) KIND="page" ;;
       esac ;;
  esac
fi

if [ -n "$NAME" ]; then NAME=$(clean_name "$NAME"); else NAME=$(slug_from "$SRC"); fi
DIR="$OUT_ROOT/$NAME"
AUDIO=""
[ "$KIND" = "page" ] && AUDIO=$(find_audio "$SRC")

log "Source:  $SRC"
log "Type:    $KIND"
if [ "$KIND" = "page" ]; then log "Audio:   ${AUDIO:-no .mp3 link on the page, will try yt-dlp}"; fi
log "Model:   $MODEL"
log "Folder:  $DIR"
[ "$DRY_RUN" = 1 ] && exit 0

for t in curl ffmpeg whisper-cli; do
  has "$t" || die "$t is missing. Run: $0 --setup"
done
[ -f "$(model_file)" ] || die "Model $MODEL is missing. Run: $0 --setup --model $MODEL"

THREADS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
[ "$THREADS" -gt 8 ] && THREADS=8

mkdir -p "$DIR"
cd "$DIR"

log "1/4 Getting the audio..."
case "$KIND" in
  file)    IN="$SRC" ;;
  audio)   EXT="${SRC%%[?#]*}"; EXT="${EXT##*.}"; IN="audio.$EXT"
           curl -fL --progress-bar -o "$IN" "$SRC" ;;
  page)    if [ -n "$AUDIO" ]; then
             IN="audio.${AUDIO##*.}"
             curl -fL --progress-bar -o "$IN" "$AUDIO"
           else
             ytdlp; IN="audio.mp3"
           fi ;;
  youtube) ytdlp; IN="audio.mp3" ;;
esac

log "2/4 Converting to 16 kHz mono WAV..."
ffmpeg -loglevel error -y -i "$IN" -ar 16000 -ac 1 -c:a pcm_s16le audio.wav \
  || die "The download isn't playable audio (often a login page or a web player). Try the direct .mp3 link."

log "3/4 Transcribing with $MODEL..."
OUT_ARGS=(-otxt)
if [ "$SRT" = 1 ]; then OUT_ARGS+=(-osrt); fi
LANG_ARGS=()
case "$MODEL" in *.en) ;; *) LANG_ARGS=(-l auto) ;; esac
whisper-cli -np -m "$(model_file)" -f audio.wav -t "$THREADS" ${LANG_ARGS[@]+"${LANG_ARGS[@]}"} "${OUT_ARGS[@]}" -of transcript

if [ "$KEEP_WAV" = 0 ]; then rm -f audio.wav; fi

log "4/4 Done. $(wc -w < transcript.txt | tr -d ' ') words."
log "  $DIR/transcript.txt"
if [ "$SRT" = 1 ]; then log "  $DIR/transcript.srt"; fi
if [ "$OPEN" = 1 ] && has open; then open transcript.txt; fi
