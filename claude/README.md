# claude/

Source for the global Claude Code config, deployed via `programs.claude-code` in `nix/home/common.nix` to `~/.claude`. `skills/` maps straight to `~/.claude/skills`; `settings.json`, `hooks/`, and `statusline.sh` deploy individually (see the comments in `common.nix` for why those use `home.file` instead of the module's own options).

## Skills

| Skill | Invoke | When |
|---|---|---|
| [`gotcha`](skills/gotcha/SKILL.md) | `/gotcha` | The moment you (or the agent) hit a recurring mistake, a stale/misleading doc, or missing context that cost extra prompting. One learning per run. Routes it to the cheapest durable home — code fix, type, test, code comment, path-scoped rule, memory, project `CLAUDE.md`, or global `agents/AGENTS.md` — fixing or pruning existing context rather than just appending. |
| [`retro`](skills/retro/SKILL.md) | `/retro` | End of a long or effortful session, run in that same session. Reviews (A) what context you had to hand-supply that a durable artifact should have covered, and (B) how every skill/subagent that actually ran performed (trigger accuracy, correction burden, model fit). Proposes fixes as a checklist you approve item by item; approved items are applied immediately. |
| [`save`](skills/save/SKILL.md) | `/save` | End of a session, or any time you want certainty that something said in it was recorded. Sweeps the transcript for what must outlive the session — preferences, open follow-ups, decisions whose reasoning no commit carries — and proposes one line per item, filing the approved ones into auto-memory (or handing a rule-shaped item to the `gotcha` ladder). |

All three write something down, but each answers a different question. `gotcha` routes *one* known learning to its cheapest home. `save` asks what facts this session established that a future one would have to be told again, and files them as facts. `retro` asks what would have made the agent work better, and edits the instructions themselves — CLAUDE.md, rules, skill bodies. A preference can qualify for either `save` or `retro`; the ladder settles it, with rules going to CLAUDE.md and facts to memory. None of them free context — that is `/compact`.

## Adding a skill

Drop `skills/<name>/SKILL.md` in and `rebuild` — no `.nix` change needed. **New files must be `git add`ed (even just staged, not committed) before rebuilding** — Nix flakes only see git-tracked content, so an untracked new skill file is invisible to the build until it's at least staged.

Format: YAML frontmatter (`name`, `description` — the description is the trigger, so state what it does and when to invoke it; optional `allowed-tools`), then the skill body in Markdown. Keep the body under ~500 lines with single-depth references — a skill should be usable standalone.

**Work-specific skills stay out of this repo, because it's public.** `scrum` is one: it lives hand-placed and untracked at `~/.claude/skills/scrum/` on the work laptop only, since it carries work identifiers (Jira tenant and account IDs, client and project names). This works because the module writes `~/.claude/skills` as a real directory of per-file symlinks, so an untracked skill dir alongside the managed ones survives `rebuild` — verified, not assumed. Trade-off: no version control, no backup, one machine. Don't "restore" it here.

See the model policy in `agents/AGENTS.md` before giving a skill or subagent write access to a fan-out: never leave a delegated call's model unset.

## Output styles

`output-styles/pr-description.md` deploys to `~/.claude/output-styles/` and is selected by `"outputStyle": "pr-description"` in `settings.json`. It holds the response-format rules that used to be a `## Responses` section in `CLAUDE.md`.

Why it moved: an output style lands in the system prompt and rewrites the identity line to point at it, where `CLAUDE.md` is attached afterwards as a user message. It also stops applying to subagents, which is what we want — their output goes to the orchestrating agent, not to a human.

Three bullets were cut in the move rather than carried across: report-the-delta-not-the-journey, evidence-for-"done", and say-what-scope-you-trimmed. Each is already stated by an always-on section of the stock prompt, so keeping them paid twice for one instruction. **Don't restore them.** What survived is the part nothing upstream says — TLDR-first ordering, the ask in one place at the end, and glossing labels on first use.

Two costs to know before changing any of this. Only one style can be active, so adopting a built-in like `Proactive` means giving this one up. And `/config` inside any project writes `outputStyle` to that project's `.claude/settings.local.json`, which silently shadows the user-level setting.

See [`upstream-internals.md`](upstream-internals.md) for what the stock prompt actually contains, and for why `keep-coding-instructions: true` is set on the style even though it currently changes nothing.
