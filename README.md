# T'es pressé ?

`T'es pressé ?` is a local-only macOS menu bar app for surprise French listening drills. It waits a random amount of time, speaks a French sentence, and makes you type or repeat what you heard before the alarm stops.

## Highlights

- Menu bar app with a persistent status icon.
- Control center on launch for timing, response mode, voice settings, and a local sentence-pool file.
- Random alarm timing with a configurable minimum gap.
- Bundled 198-prompt French sentence pool in plain text, with support for swapping in another file that keeps the same one-prompt-per-line format.
- Searchable in-app preview of the loaded sentence pool before prompts enter the active rotation.
- Open-source local voice stack:
  - Kokoro TTS through MLX-Audio
  - Whisper STT through MLX-Audio
- Challenge flow with typing, speech, or either as the dismissal method.
- `Snooze`, `Pause`, and `Mute` controls for temporary relief.

## Requirements

- macOS 14 or later
- Homebrew
- `tmux`
- `uv`
- `espeak-ng`
- Enough disk space for local model caches

The current speech stack is designed around MLX, so Apple Silicon is the intended path. If you plan to build from source, you also need the Swift toolchain with Swift Package Manager.

## Before you install

`T'es pressé ?` is a local-first app, not a single self-contained binary. The menu bar app talks to a local MLX-Audio server at `http://127.0.0.1:8000`, so you need both:

- the `.app`
- the local voice server running on your Mac

If you publish a GitHub Release, call out that the app bundle still needs the local voice-server setup below.

## Install From A GitHub Release

1. Download the latest release asset and move `T'es pressé ?.app` into `/Applications`.

2. Install the local runtime dependencies:

   ```bash
   brew install tmux uv python@3.11 espeak-ng
   ```

3. Create the persistent tmux session that the voice server uses:

   ```bash
   tmux new-session -d -s servers
   ```

4. Start the MLX-Audio voice server.

   If you also downloaded or cloned this repo, the easiest path is:

   ```bash
   ./scripts/start_mlx_audio_server_tmux.sh
   ```

   If you only have the `.app`, you can set up the same local server manually:

   ```bash
   mkdir -p ~/servers/tespresse-voice
   uv venv --python "$(command -v python3.11 || command -v python3.12 || command -v python3.13 || command -v python3)" ~/servers/tespresse-voice/.venv
   uv pip install --python ~/servers/tespresse-voice/.venv/bin/python \
     "setuptools<81" \
     "mlx-audio==0.4.1" \
     "misaki[en]>=0.9" \
     "fastapi>=0.115" \
     "uvicorn>=0.30" \
     "python-multipart>=0.0.9" \
     "webrtcvad>=2.0.10"
   tmux new-window -d -t servers -n tespresse-voice "PATH='$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH' '$HOME/servers/tespresse-voice/.venv/bin/python' -m uvicorn mlx_audio.server:app --host 127.0.0.1 --port 8000"
   ```

5. Confirm that the voice server is reachable:

   ```bash
   curl -s http://127.0.0.1:8000/v1/models
   ```

   An empty list is fine on first boot. Models are downloaded lazily on the first real TTS or STT request.

6. Open `/Applications/T'es pressé ?.app`.

   Microphone permissions work best from the bundled `.app`. Speech mode needs microphone access, and the first launch may trigger a macOS warning because the current build is ad-hoc signed rather than notarized. If that happens, open it from Finder with `Open` or allow it in System Settings.

## Quick Start From Source

1. Make sure the Swift toolchain is available on your machine, then install the runtime dependencies:

   ```bash
   brew install tmux uv python@3.11 espeak-ng
   ```

2. Create the tmux session once:

   ```bash
   tmux new-session -d -s servers
   ```

3. Start the local voice server:

   ```bash
   ./scripts/start_mlx_audio_server_tmux.sh
   ```

4. Run the app for development:

   ```bash
   swift run
   ```

5. Or build and open the app bundle:

   ```bash
   ./scripts/build_app.sh
   open "dist/T'es pressé ?.app"
   ```

Note: microphone permissions work best from the bundled `.app`.

## Voice server

The app talks to a local MLX-Audio server at `http://127.0.0.1:8000` by default. The launcher starts that server in your persistent tmux session named `servers`, in a window named `tespresse-voice`, and keeps its virtual environment under `~/servers/tespresse-voice`.

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

To stop the voice server later:

```bash
./scripts/stop_mlx_audio_server_tmux.sh
```

## Sentence pool

The app now loads one local plain-text sentence-pool file. The bundled default contains 198 French prompts and is included in the app bundle.

If you want to swap it out, keep the same format:

- plain text
- one prompt per line
- no extra parsing markers or section headers in the active pool

The control center preview still lets you inspect the live pool before trusting it for alarms.

## Current defaults

- Random interval: 5 to 20 minutes
- Repeat speech every 12 seconds
- Response mode: typing or speech
- Sentence pool: bundled 198-prompt plain-text file
- Voice server URL: `http://127.0.0.1:8000`
- TTS model: `mlx-community/Kokoro-82M-bf16`
- TTS voice: `ff_siwis`
- TTS language code: `f`
- STT model: `mlx-community/whisper-large-v3-turbo-asr-fp16`

## Development commands

```bash
swift build
swift test
swift run
./scripts/start_mlx_audio_server_tmux.sh
./scripts/stop_mlx_audio_server_tmux.sh
./scripts/build_app.sh
```

## Troubleshooting

- If the launcher says `tmux session 'servers' does not exist`, create it first with `tmux new-session -d -s servers`.
- If the app says MLX-Audio is unavailable, start the server and retry `curl -s http://127.0.0.1:8000/v1/models`.
- If the first prompt takes a while, the local TTS or STT models are probably still downloading.
- If macOS blocks the app on first launch, open it from Finder with `Open` or allow it in System Settings because the current build is not notarized.

## Project structure

- `Sources/TesPresse/`
  App logic, views, sentence-pool loading, alarm scheduling, and voice client.
- `Tests/TesPresseTests/`
  Unit tests for sentence-pool loading and phrase matching.
- `App/`
  Bundle metadata and permissions.
- `scripts/`
  Local helper scripts for the voice server and app bundle creation.
- `.learnings/`
  Project memory and implementation notes.

## Contributing

See `CONTRIBUTING.md` for local workflow, verification steps, and project conventions.
