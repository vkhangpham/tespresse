# Contributing

`T'es pressé ?` is a local-first macOS app for French listening drills. The project is small, but a few conventions make changes much easier to review and keep working.

## Goals

- Keep the app local-only and simple to run on one machine.
- Prefer open-source speech tooling for TTS and STT.
- Make sentence-pool behavior easy to inspect in the UI before trusting pool changes.
- Preserve the menu bar flow: configure, wait, trigger, answer, dismiss.

## Local setup

1. Start the local voice server:

   ```bash
   ./scripts/start_mlx_audio_server_tmux.sh
   ```

2. Run the app in development:

   ```bash
   swift run
   ```

3. Or build the bundled app:

   ```bash
   ./scripts/build_app.sh
   open "dist/T'es pressé ?.app"
   ```

The voice server defaults to the persistent tmux session named `servers` and creates a window named `tespresse-voice`.

## Project layout

- `Sources/TesPresse/`
  Swift source for the menu bar app, challenge UI, sentence-pool loading, and voice client.
- `App/Info.plist`
  App bundle metadata and permissions.
- `scripts/`
  Helper scripts for running the voice server and building the `.app`.
- `.learnings/`
  Project memory and lessons captured during development.

## Development guidelines

- Keep changes ASCII unless a file already relies on Unicode.
- Prefer small, focused UI changes that preserve the existing local-first workflow.
- Treat the sentence-pool format carefully. If you change loading rules, verify the result in the in-app pool preview.
- Keep defaults aligned with the local MLX-Audio stack unless there is a strong reason to change them.
- Avoid committing build artifacts such as `.build/` or `dist/`.

## Voice stack notes

- TTS uses `mlx-community/Kokoro-82M-bf16` with the French voice `ff_siwis`.
- STT uses `mlx-community/whisper-large-v3-turbo-asr-fp16`.
- The first TTS/STT request is intentionally heavier because models are downloaded and cached locally.
- The launcher prefers Homebrew `python3.11` because the current MLX-Audio dependency stack is more reliable there than on newer Python versions.

## Before committing

Run the checks that match your change:

```bash
swift build
swift test
./scripts/build_app.sh
curl -s http://127.0.0.1:8000/v1/models
```

If your change touches speech behavior, also test one synthesis and one transcription request against the local server.

## Commit style

- Use short imperative commit messages.
- Keep one logical change per commit when practical.
- Mention the user-facing effect in the commit body when the change spans UI and infrastructure.
