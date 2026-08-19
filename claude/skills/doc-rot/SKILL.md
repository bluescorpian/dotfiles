---
name: doc-rot
description: Finds documents that have become append-only status logs — dated entries stacked up, status cells mutated in place, corrections sitting under the claims they retract — and rewrites them by decay rate, moving rationale to a decisions log and deleting what a command can answer. Use when a repo's docs contradict themselves or the code, or before trusting a status document. Not for the repo's own agent context files, which have a dedicated audit skill. Invoked with /doc-rot [path].
---

A document rots when it is asked to hold what changes faster than anyone
edits it. The repair is not summarising — it is separating the content by
how fast it decays, then removing the instruction that caused the growth.

## 1. Find the rotting documents

Rank candidates on the signals rather than on size:

- dated entries stacked in one file, or a "current state as of" header
- status cells mutated in place — checkboxes, "not started", "done"
- retraction words: superseded, stale, no longer, corrected, was wrong
- a monotonic history — walk the file's commits and diff its byte size at
  each one. Near-zero net-negative commits means nothing is ever removed,
  which is the condition itself rather than a symptom of it.
- a shape that mirrors the code — a section per route, table or module.
  Compare the doc's last commit against the last commit of what it
  describes: a doc older than its subject is already wrong.

Report the shortlist before touching anything.

## 2. Sort the content by decay rate

Four kinds. Only one of them is worth keeping where it is:

| Content | Where it goes |
|---|---|
| Anything a command answers — what is deployed, what passed, what is done | Delete it, leaving the command that derives it. Record the query, never its output. |
| Why a decision went that way, what was rejected, what an incident taught | A dated entry in a decisions log, written once and then left alone. |
| What the code already states — what a route does, what a table holds, how a module is wired | Delete it, leaving a pointer to the file. A second copy makes every code change a two-file change, and the doc edit is the one that gets skipped. |
| A rule or an invariant | The repo's agent rules file — or a check that fails the build, which is strictly better and costs no tokens. |

Rationale is the valuable half and the easiest to destroy by accident.
Move it intact; do not compress it.

## 3. Cut the instruction that caused the growth

Search the repo's rules and context files for anything directing an agent
to update a status document. That instruction is why the file grew, and a
rewrite that leaves it in place grows back within days. This step is what
makes the rest hold.

## 4. Resolve what the document disagrees with itself about

Where a claim appears twice, check reality once and keep the answer rather
than both claims. Where a retraction sits under the text it retracts,
delete the retracted text — a correction only works if the reader reaches
it, and search and partial reads reach the original first.

## 5. Propose, then apply

Show the shortlist, what moves where, what gets deleted, and the rules
change from step 3. Anything not carried forward appears in the proposal,
so nothing is dropped silently. Wait for approval before editing.
