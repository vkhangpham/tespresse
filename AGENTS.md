# AGENTS.md

## Project Snapshot

- This repo is a local-only macOS menu bar app for surprise French listening drills.
- The app is built with Swift Package Manager and targets macOS 14 via Swift tools 6.2.
- Keep the product local-first. Do not add cloud services or remote dependencies for core alarm, prompt, TTS, or STT flows unless the task explicitly requires it.

## Start Here

Before substantial work, read these files in order:

1. `README.md` for product behavior, environment requirements, and developer commands.
2. `CONTRIBUTING.md` for repo conventions and manual verification expectations.
3. `.learnings/` for durable project memory.

To review pending or high-priority learnings quickly, run:

```bash
rg -n "Priority\\*\\*: (high|critical)|Status\\*\\*: pending" .learnings
```

The seeded templates in `.learnings/` also contain example `pending` and `high` lines, so skim past template sections before treating a match as active work.

## Repo Map

- `Sources/TesPresse/TesPresseApp.swift`: app entry point and menu bar bootstrap.
- `Sources/TesPresse/AlarmManager.swift`: main state machine for alarms, suppression, imports, and voice status.
- `Sources/TesPresse/SentenceImportService.swift`: prompt import pipeline for PDF, DOCX, TXT, and Markdown sources.
- `Sources/TesPresse/VoiceServiceClient.swift`: local MLX-Audio HTTP client for TTS, STT, and loaded-model checks.
- `App/Info.plist`: bundle metadata and permissions.
- `scripts/start_mlx_audio_server_tmux.sh`: launches the local voice server in tmux.
- `scripts/stop_mlx_audio_server_tmux.sh`: stops the tmux-hosted voice server.
- `scripts/build_app.sh`: builds the release binary and bundles the app into `dist/`.
- `.learnings/`: project memory, recurring failures, and feature requests.

## Working Rules

- Preserve the core user flow: configure -> wait -> trigger -> answer -> dismiss.
- Keep changes focused. Avoid broad refactors unless they directly support the requested task.
- Default to ASCII in new edits unless a file already depends on Unicode or an exact runtime string needs it.
- Do not commit build artifacts such as `.build/`, `dist/`, or macOS editor state.
- Keep defaults aligned with the current local MLX-Audio stack unless the task is explicitly about changing the voice setup.
- Treat prompt import changes carefully. The repo already learned that parsing is much easier to validate through the in-app preview than through raw shell output alone.

## Environment Notes

- Apple Silicon is the intended path.
- The local voice server defaults to `http://127.0.0.1:8000`.
- The launcher prefers Homebrew `python3.11` when available and manages its own virtualenv.
- `tmux`, Homebrew, and `espeak-ng` are required for the current voice workflow.

## Common Commands

```bash
swift build
swift run
./scripts/start_mlx_audio_server_tmux.sh
./scripts/stop_mlx_audio_server_tmux.sh
./scripts/build_app.sh
curl -s http://127.0.0.1:8000/v1/models
```

## Validation

- There is no dedicated `Tests/` target right now, so `swift build` and targeted manual checks are the main safety net.
- For most code changes, run `swift build`.
- For packaging, app-launch, or permission-sensitive changes, run `./scripts/build_app.sh`.
- For voice stack changes, start the local server, confirm `curl -s http://127.0.0.1:8000/v1/models` works, and exercise one synthesis plus one transcription path if possible.
- For prompt import or parsing changes, verify the result in the control center's imported-prompt preview against a representative source file.

## Project Memory

- Log durable workflow rules, corrections, and knowledge gaps in `.learnings/LEARNINGS.md`.
- Log command or runtime failures in `.learnings/ERRORS.md`.
- Log missing capabilities in `.learnings/FEATURE_REQUESTS.md`.
- When a learning becomes a standing rule for future sessions, promote it into this file instead of leaving it buried in chat history.

## Beads Workflow

Use Beads for backlog items that need follow-up, prioritization, or dependency tracking beyond the current session.

```bash
bd status
bd ready --plain
bd update <id> --claim
bd close <id> --reason "Completed"
```

If `bd status` reports that no database exists and the task really needs persistent tracking, initialize it in stealth mode:

```bash
bd init --stealth --skip-agents --skip-hooks -p fr
```
