---
name: worktree-cleanup
description: Review and clean up this repo's git worktrees — inventory every linked worktree, auto-remove ones whose branch is long-merged, and surface only the judgement calls (stale/dirty/orphaned) as batched, recommended-first multiple-choice questions with pre-gathered context. Repo-agnostic; remembers per-worktree keep/snooze decisions so it never re-asks. Invoke with /worktree-cleanup, or when asked to tidy, prune, or clean up worktrees. For stale local branches with no worktree, use the sibling `branch-cleanup` skill.
allowed-tools: Read, Write, Edit, AskUserQuestion, Agent, Bash(git worktree:*), Bash(git branch:*), Bash(git push:*), Bash(git for-each-ref:*), Bash(git rev-parse:*), Bash(git fetch:*), Bash(git log:*), Bash(git status:*), Bash(git show-ref:*), Bash(gh pr list:*), Bash(jq:*), Bash(date:*), Bash(mkdir:*), Bash(du:*), Bash(basename:*), Bash(cat:*)
---

Clean up git worktrees with the least interaction that's still safe. A deterministic engine (`scripts/worktree-plan.sh`) does all inventory + classification; you only reason about the handful of judgement calls, and you surface those to Harry as clear multiple-choice questions — he may not have read the raw output, so each option must stand on its own.

Scope: **worktrees only.** Stale local branches with no worktree are the sibling `branch-cleanup` skill's job — they share this repo's registry but run independently (worktrees are often clean while branches aren't). If Harry wants "clean up everything," run this, then hand off to `branch-cleanup`.

## Safety invariants (never violate)

1. **Removing a worktree ≠ deleting its branch.** `git worktree remove` keeps the branch ref. This is why merged/pushed worktrees are safe to remove — the work survives.
2. **Only ever delete a branch with `git branch -d`** (never `-D` unless Harry explicitly says discard). `-d` refuses to delete anything not merged, so it's a built-in guardrail. Never delete an *unmerged* branch.
3. **Orphans** (detached HEAD whose commits are in no branch/remote — `orphan: true`) are the only real data-loss risk: always offer *save-to-branch* or *push* BEFORE removal, never discard silently.
4. **Never remove the primary worktree** (`isMain: true`) or the worktree you're currently `cd`'d into.
5. Auto-tier actions still get **one batched confirmation** — nothing is deleted before Harry approves the batch.

## 1. Locate registry + run the engine

```bash
git fetch --all --prune                      # accurate merge/pushed status
MAIN=$(git worktree list --porcelain | sed -n 's/^worktree //p' | head -1)
SLUG=$(basename "$MAIN")
REG="${XDG_STATE_HOME:-$HOME/.local/state}/git-cleanup/$SLUG.json"   # shared with branch-cleanup
mkdir -p "$(dirname "$REG")"
SKILL_DIR="${CLAUDE_SKILL_DIR:-$HOME/.claude/skills/worktree-cleanup}"
"$SKILL_DIR/scripts/worktree-plan.sh" --registry "$REG" > /tmp/wt-plan.json
jq '{repo,trunk,defaults, counts:(.worktrees|group_by(.verdict)|map({(.[0].verdict):length})|add)}' /tmp/wt-plan.json
```

(The engine includes worktree sizes by default, which is the slow part; pass `--no-size` for a fast dry read.)

The plan JSON gives every worktree a `verdict`: `AUTO_REMOVE`, `ASK`, or `KEEP`, plus facts (`merged`, `pushed`, `orphan`, `dirty`, `ageDays`, `ahead`, `sizeMb`, `note`) and a `kind`/`reason`. Trust these verdicts — the thresholds live in `defaults` (and the registry overrides them). Don't re-derive merge status yourself.

## 2. Report the silent tiers, don't ask about them

- **KEEP**: state the count and one-line why (primary / active / pinned / snoozed / merged-young / in-progress). Don't enumerate unless asked.
- **AUTO_REMOVE**: list each (name, `reason`, `sizeMb`) — these go into the confirm batch in step 4, they are not silently deleted.

## 3. Enrich ASK items with context (parallel, Sonnet)

Only if there are `ASK` worktrees. For each, spawn ONE subagent **in parallel, `model: "sonnet"`** to produce a 2–3 sentence situation Harry can act on without digging:

> Worktree `<path>` on branch `<branch>`. Report, in 2–3 sentences: what this branch was for (infer from `git -C <path> log --oneline -15` and the branch name); whether an open PR exists (`gh pr list --head <branch> --state open` if `gh` is available); and what removing the worktree would and wouldn't lose (branch is `pushed:<bool>`, `merged:<bool>`, `dirty:<n>`). **If `dirty:>0`, for each uncommitted path check whether the change already exists on the trunk (`git -C <path> diff <file>` vs `git -C <path> show <trunk>:<file>`) and state redundant-vs-novel** — a dirty change already landed on trunk is safe to discard; only novel work needs preserving. Be concrete. Return only the summary.

Never leave `model` unset on this fan-out (it would inherit the session's Opus and overpay — this is single-source summarization, Sonnet's floor). Cap at ~8; if more, batch.

## 4. Surface judgement calls via AskUserQuestion

Batch ASK items into one `AskUserQuestion` call (≤4 questions per call; multiple calls if needed). Each question's text = the enriched situation. **Lead every question with the recommended option and append `(Recommended)` to its label** (the `AskUserQuestion` convention) — the first option in each template below is that default. Name the recommendation in the question text too, so Harry can one-tap it. Tailor options to `kind`:

- **`merged-dirty`** (merged, safe, but has uncommitted paths): _Remove & discard the stray changes (Recommended)_ · _Show me the diff first_ · _Keep this worktree_ · _Snooze 30d_.
- **`stale-unmerged`** (idle, `pushed:true` → branch safe on origin; `pushed:false` → **local-only, branch stays but tell Harry**): _Remove worktree (keep branch) (Recommended)_ · _Remove worktree + delete branch_ (offer ONLY if `pushed:true`) · _Keep_ · _Snooze 30d_.
- **`orphan`**: _Save to a branch, then remove (Recommended)_ · _Push to origin, then remove_ · _Keep as-is_ · _Discard (lose the commits)_ — the save option is the default.
- Always include a **"Keep always (stop asking)"** path for anything Harry considers permanent.

Options must be self-contained (size reclaimed, what's lost, what's preserved) — assume Harry hasn't read the agent output.

## 5. Execute

Run from the primary worktree (never from inside a target). After removals: `git worktree prune`.

| Decision | Commands |
|---|---|
| Remove (merged, clean) | `git worktree remove "<path>"` → if `deleteMergedBranches` & branch merged: `git branch -d "<branch>"` |
| Remove & discard (dirty) | `git worktree remove --force "<path>"` → `git branch -d "<branch>"` if merged |
| Remove worktree, keep branch | `git worktree remove "<path>"` (no branch delete) |
| Remove + delete branch (unmerged but pushed) | `git worktree remove "<path>"` → `git branch -D "<branch>"` (only with explicit approval; branch is on origin) |
| Orphan → save first | `git branch "<name>" <HEAD-sha>` (then optionally `git push -u origin "<name>"`) → `git worktree remove "<path>"` |

If `git worktree remove` refuses (submodule/lock), report it — don't blindly `--force`.

## 6. Record decisions in the registry

After acting, update `$REG` so nothing re-surfaces. Use `date +%F` for today and compute snooze dates with `date -d "+30 days" +%F`.

- **Keep always** → `worktrees[<name>].keep = "always"` + a `note`.
- **Snooze N days** → `worktrees[<name>].keep = { "until": "<YYYY-MM-DD>" }` + `note`.
- **Removed** → drop the entry (or leave a dated `note` if it might reappear).
- Never store a permanent `keep:"always"` to represent a *transient* reason like "active build" — recency already protects those; snooze or just a `note` is correct. Reserve `always` for genuinely permanent worktrees.

Edit the JSON with `jq` (read → modify → write to temp → move) or Write. Seed the file on first run if absent:

```json
{
  "trunk": "develop",
  "defaults": { "mergedAgeDays": 14, "staleUnmergedDays": 21, "recencyGuardDays": 2, "deleteMergedBranches": true },
  "worktrees": {}
}
```

## Registry schema

- `trunk` — merge-target branch (auto-detected: develop → origin/HEAD → main/master; set here to pin).
- `defaults` — threshold knobs (above).
- `worktrees[<dir-basename>]`:
  - `note` — context string, always shown when the worktree is surfaced.
  - `keep` — omit (normal rules) · `"always"` (never surfaced/removed) · `{ "until": "YYYY-MM-DD" }` (skip until date, then re-evaluate).

The same registry file also holds a `branches[<name>]` section owned by the sibling `branch-cleanup` skill; leave it untouched here.

## Branches

Local branches with no worktree are handled by the separate **`branch-cleanup`** skill (shared registry, same recommended-first style). Don't delete branches from this skill beyond the merged-branch cleanup tied to a worktree removal in step 5.
