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
