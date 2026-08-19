---
name: prompt-rules
description: Rules for authoring LLM prompts — subagent definitions, skills, slash commands, CLAUDE.md rules, or reusable prompts handed to other sessions. Use when writing or revising one of these, or when reviewing one for quality. Not for one-off task briefs; the delegate skill covers those.
---

A standing prompt is read many times by a model and rarely by its author.
Aim for maximum behavioural steering per token, with nothing that rots.

## Where an instruction lives

- Config enforces, prose judges. Anything expressible as a setting — tool
  lists, model, permissions, hooks — never appears as a sentence; a
  sentence only asks. Keep prose for what no setting can express.
- No stale references: no paths, repo names, versions, model names, or
  names of other agents. The invocation supplies specifics; the standing
  prompt says what to do with them.
- Carry only the qualification of an inherited rule, never the rule
  itself — but verify what the target context actually inherits first.
  Subagents load the CLAUDE.md hierarchy and a minimal tool harness, but
  none of the main system prompt's behavioural guidance; skills load into
  a session that has all of it.

## What it says

- One stance per prompt: it earns its place by what the model would not
  do by default. If a per-call instruction could carry the stance just as
  well, the standing prompt should not exist.
- Define the output contract precisely and let the model find the method.
  Exception: an operation that must run identically every time gets exact
  steps — match the prompt's freedom to the task's fragility.
- Structure beats word counts: "one line per gate", "verdict plus
  file:line" — models count items reliably, words poorly. A worked example
  at the target density is the strongest length anchor; use one only where
  the output should be boxed, and to teach a style or format that
  description alone cannot.
- Name the reader and what they already have — relevance deletes
  restatement better than any cap.
- Say what to do, not what to avoid, in plain register: "use X when Y",
  never all-caps or CRITICAL-style emphasis, which newer models
  overtrigger on.
- State each rule once, in one consistent vocabulary. Recommend one way
  per decision, with a named escape hatch for the exception — not a menu.
- Author for the tier that will run the prompt, and recheck on a tier
  change: the same line can correct one model and harm another. See the
  quirks below; on a new model generation, refresh them from the
  per-model prompting guides rather than trusting the snapshot.

## Keeping it lean

- Rationale earns its place only where the model must generalise the rule
  to cases the prompt cannot enumerate; a mechanical rule needs none.
  Rationale for the human maintainer goes in the commit message.
- A licence to deviate always pairs with the duty to report the deviation.
- The description is for the dispatcher: third person, what it does plus
  when to use it and when not. It is the only part read at routing time.

## Model quirks — Claude 5 family, snapshot 2026-08

A deliberate exception to the no-stale-references rule: short, high-value,
and dated so it is checkable.

- Sonnet 5: the most literal tier. It does not generalise an instruction
  beyond its stated scope, so scope explicitly ("every section, not just
  the first"). It follows report-filters faithfully — "only report
  high-severity" costs recall while investigation depth is unchanged; ask
  for full coverage with severity attached and filter in a later pass.
- Opus 5: verifies and self-corrects unprompted — verification and
  double-check instructions cause over-verification; remove them. Effort
  controls thinking, not response length: prompt length explicitly, and
  calibrate written-to-disk documents separately. Delegates and expands
  scope readily; constrain both explicitly.
- Fable 5: prior-model skills are often too prescriptive and degrade
  output — cut instructions before adding them.
  On long runs, have it audit progress claims against tool
  results. Task briefs benefit from the intent behind the request.

## Afterwards

Reread the draft as its own critic: apply every rule above to it, and cut
what fails. Short and reviewed hard beats long and skimmed.

When revising an existing prompt, compare which stances the old and new
drafts take, not just their wording. Cutting a position because it is
wrong is a fair edit; losing one while tightening prose is a regression —
say which happened.
