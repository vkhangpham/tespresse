# Errors

Capture command failures, tool failures, and unexpected runtime problems that future sessions should avoid repeating.

**Areas**: frontend | backend | infra | tests | docs | config | general
**Statuses**: pending | in_progress | resolved | wont_fix | promoted

## Entry Template

````markdown
## [ERR-YYYYMMDD-001] command-or-tool-name

**Logged**: 2026-03-24T09:00:00Z
**Priority**: high
**Status**: pending
**Area**: general

### Summary
Short description of what failed

### Error
```text
Paste the most useful error text here
```

### Context
- Command or operation attempted
- Inputs or parameters used
- Environment details if they mattered

### Suggested Fix
Best next step, workaround, or prevention rule

### Metadata
- Reproducible: yes | no | unknown
- Related Files: path/to/file.ext
- See Also: ERR-YYYYMMDD-000

---
````

## Resolution Block

```markdown
### Resolution
- **Resolved**: 2026-03-24T10:00:00Z
- **Commit/PR**: abc123 or #42
- **Notes**: Brief description of what changed
```
