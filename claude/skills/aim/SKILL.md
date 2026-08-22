---
name: aim
description: Turn a rough intent into a well-formed `/goal` condition for the repo at hand, ready to paste. Use when starting substantial work that should run turn after turn without handing control back. Not for exploratory or conversational work — say so and stop instead.
---

The `/goal` evaluator is a small fast model reading the transcript. It runs no
commands and reads no files, so a condition is judgeable only if Claude's own
output demonstrates it. Everything below follows from that.

## First decide whether a goal fits at all

A goal needs one verifiable end state. A migration, a failing suite, a backlog
to empty, a design doc's acceptance criteria — yes. "Look into X", "what do you
think about Y", open-ended research — no: the condition would never be met and
the loop would just run to its bound, burning turns.

When it doesn't fit, say so plainly and stop. Don't emit a goal you don't
believe in. `--append-system-prompt` with the autonomy block is the lever for
that kind of session.

## Then build the condition

Establish by looking, not guessing, how *this* repo proves work is finished —
its test command, its build, `rebuild` switching cleanly, `git status`. Compose
four parts:

1. **The end state**, measurable — a test result, an exit code, an empty queue.
2. **The proof**, named as a command, plus an instruction to show its output.
   The evaluator judges only what reached the screen.
3. **Constraints** that must hold on the way — what must not change.
4. **A bound** sized to the work: `or stop after N turns`.

## Then hand it over

Print the finished `/goal …` line as a fenced code block on its own, nothing
else in it — Claude Code makes a code block one click to copy. Claude Code
exposes no tool that sets a goal, so pasting it is Harry's job; leave him
nothing else to do.
