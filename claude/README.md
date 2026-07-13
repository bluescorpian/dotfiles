# claude/

Source for the global Claude Code config, deployed via `programs.claude-code` in `nix/home/common.nix` to `~/.claude`. `skills/` maps straight to `~/.claude/skills`; `settings.json`, `hooks/`, and `statusline.sh` deploy individually (see the comments in `common.nix` for why those use `home.file` instead of the module's own options).

## Skills

| Skill | Invoke | When |
|---|---|---|
| [`gotcha`](skills/gotcha/SKILL.md) | `/gotcha` | The moment you (or the agent) hit a recurring mistake, a stale/misleading doc, or missing context that cost extra prompting. One learning per run. Routes it to the cheapest durable home — code fix, type, test, code comment, path-scoped rule, memory, project `CLAUDE.md`, or global `agents/AGENTS.md` — fixing or pruning existing context rather than just appending. |
| [`retro`](skills/retro/SKILL.md) | `/retro` | End of a long or effortful session, run in that same session. Reviews (A) what context you had to hand-supply that a durable artifact should have covered, and (B) how every skill/subagent that actually ran performed (trigger accuracy, correction burden, model fit). Proposes fixes as a checklist you approve item by item; approved items are applied immediately. |
| [`save`](skills/save/SKILL.md) | `/save` | Checkpoint or end a session. Writes a session handoff note to `docs/session-notes/YYYY-MM-DD-<slug>.md` (goal, done, in progress, next steps, decisions, blockers) for a fresh session to pick up from. |

`gotcha` and `save` are both "write something down" skills but for different audiences: `gotcha` produces durable context for *future agents in any session*; `save` produces a one-off handoff note for *the next session on this task*. `retro` is the only one that looks backward across a whole session rather than forward.

## Adding a skill

Drop `skills/<name>/SKILL.md` in and `rebuild` — no `.nix` change needed. **New files must be `git add`ed (even just staged, not committed) before rebuilding** — Nix flakes only see git-tracked content, so an untracked new skill file is invisible to the build until it's at least staged.

Format: YAML frontmatter (`name`, `description` — the description is the trigger, so state what it does and when to invoke it; optional `allowed-tools`), then the skill body in Markdown. Keep the body under ~500 lines with single-depth references — a skill should be usable standalone.

See the model policy in `agents/AGENTS.md` before giving a skill or subagent write access to a fan-out: never leave a delegated call's model unset.
