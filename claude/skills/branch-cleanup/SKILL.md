---
name: branch-cleanup
description: Review and clean up this repo's stale LOCAL git branches that have no worktree — the refs that pile up after PRs merge. A deterministic engine auto-deletes long-merged branches and surfaces only the judgement calls (squash-merged, upstream-gone, local-only) as batched, recommended-first multiple-choice questions with pre-gathered context (merged-PR lookup). Repo-agnostic; shares a per-repo registry with the worktree-cleanup skill so keep/snooze pins are honored and never re-asked. Invoke with /branch-cleanup, or when asked to prune, tidy, or clean up branches. Supersedes clean_gone.
allowed-tools: Read, Write, Edit, AskUserQuestion, Agent, Bash(git branch:*), Bash(git for-each-ref:*), Bash(git rev-parse:*), Bash(git fetch:*), Bash(git log:*), Bash(git merge-base:*), Bash(git show-ref:*), Bash(git worktree list:*), Bash(gh pr list:*), Bash(jq:*), Bash(date:*), Bash(mkdir:*), Bash(basename:*), Bash(cat:*)
---

Clean up **local branches that own no worktree** with the least interaction that's still safe — the dangling refs left behind after PRs merge. A deterministic engine (`scripts/branch-plan.sh`) inventories + classifies; you only reason about the judgement calls and surface them to Harry as clear multiple-choice questions (he may not have read the raw output, so each option stands alone).

Runs independently of `worktree-cleanup` (worktrees are often clean while branches aren't) but shares the same per-repo registry, so a `keep: always` pin set in either is honored by both.

## Safety invariants (never violate)

1. **`git branch -d` is the guardrail** — it refuses to delete a branch not merged into HEAD/upstream. Prefer it. Only use `-D` (force) when Harry explicitly approves, or when a **merged PR was confirmed** for a squash-merged branch (git can't see the squash, but the content is on trunk).
2. **Never delete a branch with unconfirmed unmerged local commits**, and never delete a `local-only` (`pushed:false`) unmerged branch without explicit approval — that's the one real data-loss path (a pushed branch is recoverable from origin; a local-only one is not).
3. **Never touch trunk, `main`/`master`, or a branch checked out in a worktree** — the engine already excludes these.
4. Auto-tier deletions still get **one batched confirmation** — nothing is deleted before Harry approves the batch. Long-lived personal/integration branches (`harry`, `release/*`) that qualify for auto-delete are surfaced for a **keep-always pin**, not deleted on autopilot.

## 1. Locate registry + run the engine

```bash
git fetch --all --prune                      # accurate merge/pushed/[gone] status
MAIN=$(git worktree list --porcelain | sed -n 's/^worktree //p' | head -1)
SLUG=$(basename "$MAIN")
REG="${XDG_STATE_HOME:-$HOME/.local/state}/git-cleanup/$SLUG.json"   # shared with worktree-cleanup
mkdir -p "$(dirname "$REG")"
SKILL_DIR="${CLAUDE_SKILL_DIR:-$HOME/.claude/skills/branch-cleanup}"
"$SKILL_DIR/scripts/branch-plan.sh" --registry "$REG" > /tmp/br-plan.json
jq '{repo,trunk,defaults, counts:(.branches|group_by(.verdict)|map({(.[0].verdict):length})|add)}' /tmp/br-plan.json
```

Each branch gets a `verdict` (`AUTO_DELETE`/`ASK`/`KEEP`), a `kind`, a `reason`, and facts (`merged`, `pushed`, `gone`, `ahead`, `ageDays`, `note`). Trust the verdicts; thresholds live in `defaults` (registry-overridable). The engine already excludes trunk, `main`/`master`, and worktree branches.

## 2. Report the silent tiers

- **KEEP**: count + one-line why (pinned / snoozed / active / merged-young / in-progress). Don't enumerate unless asked.
- **AUTO_DELETE**: list each (name, `reason`) — these enter the confirm batch in step 4, never silent.

## 3. Enrich ASK — the squash-merge disambiguation (parallel, Sonnet)

Only if there are `ASK` branches. ASK branches are mostly `stale-pushed`/`gone-unmerged` with a **high `ahead` count** — the fingerprint of a squash-merge (original commits replaced by one commit on trunk, so ancestry reads "unmerged" though the content landed). For each, spawn ONE subagent **in parallel, `model: "sonnet"`** (never leave `model` unset — this is single-lookup work, Sonnet's floor):

> Branch `<branch>` (ahead `<ahead>` of `<trunk>`, `pushed:<bool>`, `gone:<bool>`). Run `gh pr list --head <branch> --state merged --json number,title,mergedAt` (if `gh` available) and `git log --oneline -8 <branch>`. In 2–3 sentences report: was this branch's work merged (PR number + date if so), or is it genuinely unmerged/abandoned, and what deleting it would lose. Return only the summary.

Reclassify from the result:
- **Merged PR found** → `confirmed-landed`: content is on trunk, safe to delete. Collapse all of these into ONE batch confirm, not N questions.
- **No merged PR, unmerged** → genuine `stale`/`gone-unmerged` ASK.
- **`stale-local`** (unmerged, `pushed:false`) → individual ASK; deleting loses commits.

## 4. Surface judgement calls via AskUserQuestion

Batch into `AskUserQuestion` (≤4 questions/call). **Lead every question with the recommended option and append `(Recommended)` to its label**; name the recommendation in the question text so Harry can one-tap. Options must be self-contained (what's on origin, what's lost). By kind:

- **`confirmed-landed`** → one batch question: _Delete all N (landed on `<trunk>` via PR) (Recommended)_ · _Let me pick_ · _Keep all_.
- **`gone-unmerged` / `stale-pushed`** (no merged PR) → _Delete branch — recoverable from origin (Recommended)_ · _Keep_ · _Snooze 30d_ · _Keep always_.
- **`stale-local`** → _Keep (Recommended)_ · _Delete & lose `<ahead>` local commits_ · _Snooze 30d_.
- **AUTO_DELETE personal/integration branch** (`harry`, `release/*`) → offer _Keep always (pin)_ alongside _Delete_.

## 5. Execute

Run from the trunk worktree (so `-d`'s guardrail checks against trunk).

| Decision | Command |
|---|---|
| Merged (AUTO_DELETE) | `git branch -d "<name>"` |
| `confirmed-landed` (squash-merged, PR confirmed) | `git branch -d "<name>"` → if it refuses (squash invisible to git): `git branch -D "<name>"` |
| `stale-local` / unmerged, explicit approval | `git branch -D "<name>"` |

If `-d` refuses a branch you did NOT confirm as landed, do not force — surface it as an ASK instead.

## 6. Record decisions in the registry

Update `branches[<name>]` in `$REG` (use `date +%F` today; snooze = `date -d "+30 days" +%F`):

- **Keep always** → `branches[<name>].keep = "always"` + `note`.
- **Snooze N days** → `branches[<name>].keep = { "until": "<YYYY-MM-DD>" }` + `note`.
- **Deleted** → drop the entry.
- Reserve `keep:"always"` for genuinely permanent branches (personal/integration); recency already protects active ones — a `note` or snooze is right for transient reasons.

Edit with `jq` (read → modify → temp → move) or Write. The registry is shared: `trunk` + `defaults` + a `worktrees` section belong to `worktree-cleanup` — leave those untouched, only write under `branches`. Seed on first run if absent:

```json
{ "trunk": "develop",
  "defaults": { "mergedAgeDays": 14, "staleUnmergedDays": 21, "recencyGuardDays": 2, "deleteMergedBranches": true },
  "worktrees": {}, "branches": {} }
```
