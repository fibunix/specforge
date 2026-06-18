# Learnings index

One line per learning, newest at the bottom (append-only). The full entry lives in
the named file under `.specforge/learnings/`. This index is loaded at the start of
every loop/session; agents `grep` it by area + keywords and open only the entries
relevant to the work item. See `.specforge/canon/docs/LEARNINGS.md` for the format
and when to write one.

<!-- format:  - <area> | <file>.md | <one-line finding> -->
<!-- example: - testing | tz-offset-truncates.md | SQLite stores TZ-naive datetimes; UTC assertions silently pass -->
