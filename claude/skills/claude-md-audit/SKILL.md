---
name: claude-md-audit
description: Audits a CLAUDE.md or AGENTS.md against the repo it describes — verifies every factual claim with subagents, strips what reading the repo would reveal, removes diary/status drift — then rewrites it. Use when a context file feels stale or bloated, or after a large refactor. Invoked with /claude-md-audit [path].
---

Audit the target context file claim by claim, then rewrite it.

1. Inventory the claims: every checkable factual statement — paths,
   commands, aliases, wiring, layout, invariants. Stances and preferences
   are not claims; set them aside for step 4.
2. Verify the claims against the repo and system, batched by theme across
   read-only subagents instructed to refute rather than confirm. Every
   verdict needs cited evidence.
3. Triage each confirmed claim for derivability: if reading a couple of
   files — imports, headers, a directory listing — would reveal it,
   strip it. Keep what reading won't tell you: gotchas, cross-file
   couplings, warnings about other actors, the why behind a decision.
4. Sweep for diary drift: status, progress notes, completed-work records,
   and dated facts move to commits or docs, or get deleted.
5. Sweep for contradictions, within the file and across the loaded
   hierarchy (user, project, nested, rules files): conflicting rules make
   the model pick one arbitrarily per run — resolve or remove.
6. Rewrite under the prompt-rules skill: confirmed facts stay, refuted
   ones are corrected, partials either name their exception or go. Place
   the rules that matter most first or last in the file, never mid-file.
7. Report: counts of verified / refuted / stripped, each judgment call
   the owner might veto, and any refuted claim that suggests the repo —
   not the doc — is what's wrong.
