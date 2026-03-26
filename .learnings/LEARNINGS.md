# Learnings

Capture corrections, knowledge gaps, and best practices discovered during work.

**Categories**: correction | knowledge_gap | best_practice | insight
**Areas**: frontend | backend | infra | tests | docs | config | general
**Statuses**: pending | in_progress | resolved | wont_fix | promoted | promoted_to_skill

## Entry Template

```markdown
## [LRN-YYYYMMDD-001] best_practice

**Logged**: 2026-03-24T09:00:00Z
**Priority**: medium
**Status**: pending
**Area**: general

### Summary
One-line description of the learning

### Details
What happened, what was wrong, and what is now understood

### Suggested Action
Concrete prevention rule or improvement to apply next time

### Metadata
- Source: conversation | error | user_feedback | docs
- Related Files: path/to/file.ext
- Tags: tag1, tag2
- See Also: LRN-YYYYMMDD-000
- Pattern-Key: simplify.dead-code
- Recurrence-Count: 1
- First-Seen: 2026-03-24
- Last-Seen: 2026-03-24

---
```

## Resolution Block

Add after `Metadata` when the issue is fixed or promoted:

```markdown
### Resolution
- **Resolved**: 2026-03-24T10:00:00Z
- **Commit/PR**: abc123 or #42
- **Notes**: Brief description of what changed
```

## Promotion Block

Use when the learning becomes durable agent guidance:

```markdown
**Status**: promoted
**Promoted**: AGENTS.md
```

Use when extracting a reusable skill:

```markdown
**Status**: promoted_to_skill
**Skill-Path**: /absolute/path/to/skill
```

## [LRN-20260326-001] best_practice

**Logged**: 2026-03-26T11:28:00Z
**Priority**: medium
**Status**: promoted
**Promoted**: AGENTS.md
**Area**: general

### Summary
Expose an in-app preview for imported prompt sources before trusting PDF/DOCX parsing

### Details
The app began importing French prompts from a bilingual PDF and a study DOCX, but checking parser quality only through shell extraction output made it hard to verify what the live app would actually use. Adding a searchable preview tied directly to `importedSentences` made it much easier to inspect parsing quality, spot wrapped-line issues, and validate source-specific extraction rules.

### Suggested Action
When a feature imports or transforms user-owned content, add a lightweight preview surface in the app or tool UI early so parsing changes can be validated against the real runtime data instead of only raw command output.

### Metadata
- Source: conversation
- Related Files: Sources/TesPresse/ControlCenterWindowController.swift, Sources/TesPresse/SentenceImportService.swift
- Tags: import, parser, preview, pdf, docx
- Pattern-Key: imports.prompt-preview
- Recurrence-Count: 1
- First-Seen: 2026-03-26
- Last-Seen: 2026-03-26

### Resolution
- **Resolved**: 2026-03-26T11:28:00Z
- **Commit/PR**: local workspace
- **Notes**: Added a searchable imported-prompt preview panel to the control center and used it to support parser iteration.

---

## [LRN-20260326-002] best_practice

**Logged**: 2026-03-26T13:40:00Z
**Priority**: medium
**Status**: promoted
**Promoted**: AGENTS.md
**Area**: backend

### Summary
Keep the default sentence pool in a plain-text one-line-per-prompt file instead of parsing study documents at app startup

### Details
The original alarm flow parsed PDF and DOCX study material on launch, which added extra runtime complexity, made startup behavior depend on external files and parser heuristics, and left old saved source paths vulnerable to breakage. Switching the default pool to a bundled text file with 198 prompts keeps the app local and fast, while still letting the user swap in another file as long as it keeps the same format.

### Suggested Action
When prompt content is intended to be stable and user-editable, prefer a simple text resource with one prompt per line over runtime extraction from richer document formats. Keep the in-app preview so file changes are visible before they affect live alarms.

### Metadata
- Source: conversation
- Related Files: Sources/TesPresse/SentenceImportService.swift, Sources/TesPresse/Resources/default_sentence_pool.txt, AGENTS.md
- Tags: sentence-pool, startup, parser, reliability
- Pattern-Key: prompts.plain-text-pool
- Recurrence-Count: 1
- First-Seen: 2026-03-26
- Last-Seen: 2026-03-26

### Resolution
- **Resolved**: 2026-03-26T13:40:00Z
- **Commit/PR**: local workspace
- **Notes**: Replaced runtime PDF/DOCX importing with a bundled plain-text sentence pool and updated the UI and agent guidance to match.

---

## [LRN-20260326-003] best_practice

**Logged**: 2026-03-26T15:05:00Z
**Priority**: medium
**Status**: pending
**Area**: tests

### Summary
Use the `swift-testing` package for SwiftPM unit tests on this CLT-only machine instead of relying on system test frameworks

### Details
The local setup builds the app with Apple Command Line Tools rather than full Xcode. In that environment, `swift test` did not have a usable built-in XCTest path and the CLT-hosted Testing framework was incomplete for package-native compilation without extra internal modules and runtime search-path workarounds. Adding the official `swift-testing` package as a test-only dependency produced stable package-native tests with `swift test`.

### Suggested Action
When adding or repairing SwiftPM tests in this repo, prefer the package dependency on `swift-testing` over custom runners or assumptions about built-in test frameworks being present.

### Metadata
- Source: conversation
- Related Files: Package.swift, Tests/TesPresseTests/SentenceImportServiceTests.swift, Tests/TesPresseTests/SentenceMatcherTests.swift
- Tags: swiftpm, testing, clt, macos
- Pattern-Key: swiftpm.clt-testing
- Recurrence-Count: 1
- First-Seen: 2026-03-26
- Last-Seen: 2026-03-26

---
