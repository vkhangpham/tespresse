# T'es pressé ?

`T'es pressé ?` is a local-only macOS menu bar app for surprise French listening drills. It waits a random amount of time, speaks a French sentence, and makes you type or repeat what you heard before the alarm stops.

## Highlights

- Menu bar app with a persistent status icon.
- Control center on launch for timing, response mode, voice settings, and prompt sources.
- Random alarm timing with a configurable minimum gap.
- Prompt import from local PDF, DOCX, TXT, and Markdown files.
- Searchable in-app preview of imported prompts before they enter the active pool.
- Open-source local voice stack:
  - Kokoro TTS through MLX-Audio
  - Whisper STT through MLX-Audio
- Challenge flow with typing, speech, or either as the dismissal method.
- `Snooze`, `Pause`, and `Mute` controls for temporary relief.

## Requirements

- macOS
- Swift toolchain with Swift Package Manager
- `tmux`
- Homebrew
- `espeak-ng`
- Enough disk space for local model caches

The current speech stack is designed around MLX, so Apple Silicon is the intended path.

## Quick start

1. Start the local voice server:

   ```bash
   ./scripts/start_mlx_audio_server_tmux.sh
   ```

2. Run the app for development:

   ```bash
   swift run
   ```

3. Or build and open the app bundle:

   ```bash
   ./scripts/build_app.sh
   open "dist/T'es pressé ?.app"
   ```

Note: microphone permissions work best from the bundled `.app`.

## Voice server

The app talks to a local MLX-Audio server at `http://127.0.0.1:8000` by default. The launcher starts that server in your persistent tmux session named `servers`, in a window named `tespresse-voice`.

The launcher prefers Homebrew `python3.11`, seeds the virtual environment, and installs the extra Kokoro dependencies that the current French TTS path needs on macOS:

- `mlx-audio==0.4.1`
- `misaki[en]>=0.9`
- `setuptools<81`
- `fastapi`
- `uvicorn`
- `python-multipart`
- `webrtcvad`

### First-run warmup

The first request is heavier because models are downloaded lazily and cached locally:

- Kokoro TTS downloads roughly `361 MB`
- Whisper STT downloads roughly `1.6 GB`

After that, speech requests are much faster.

## Prompt sources

The app can import prompts from your own study material. Right now the defaults target local French study files on this machine:

- `~/Study/books/198 French Phrases and expressions.pdf`
- `~/Study/Francais/tcf/Expressions et Vocabulaire 1.docx`

Imported prompts are shown in the control center preview so you can inspect parsing quality before relying on them for alarms.

## Current defaults

- Random interval: 5 to 20 minutes
- Repeat speech every 12 seconds
- Response mode: typing or speech
- Voice server URL: `http://127.0.0.1:8000`
- TTS model: `mlx-community/Kokoro-82M-bf16`
- TTS voice: `ff_siwis`
- TTS language code: `f`
- STT model: `mlx-community/whisper-large-v3-turbo-asr-fp16`

## Development commands

```bash
swift build
swift run
./scripts/start_mlx_audio_server_tmux.sh
./scripts/stop_mlx_audio_server_tmux.sh
./scripts/build_app.sh
```

## Project structure

- `Sources/TesPresse/`
  App logic, views, import pipeline, alarm scheduling, and voice client.
- `App/`
  Bundle metadata and permissions.
- `scripts/`
  Local helper scripts for the voice server and app bundle creation.
- `.learnings/`
  Project memory and implementation notes.

## Contributing

See `CONTRIBUTING.md` for local workflow, verification steps, and project conventions.
