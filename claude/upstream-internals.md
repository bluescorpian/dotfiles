# Claude Code internals

What upstream's system prompt actually contains, read out of the shipped
binary. All of it is empirical, and it contradicts the public docs in two
places.

> **Verified against claude-code 2.1.235.** If `claude --version` prints
> anything else, treat every claim below as unverified until you re-derive
> it. Each finding names the string that regenerates it.

## Reading the live system prompt

The `claude` on `PATH` is a small ELF wrapper; the JS lives in the
bun-compiled binary beside it.

```bash
f="$(dirname "$(readlink -f "$(which claude)")")/.claude-unwrapped"   # ~330 MB
perl -0777 -ne 'my $i=index($_,q{# Output Style: }); print substr($_,$i-400,2000)' "$f"
```

Slurp mode is the part that matters. Prompt text lives in template literals
spanning newlines, so `strings` and line-based `grep` cut every one of them
in half.

Anchor searches on English prompt text, never on identifiers — the bundle is
minified and every symbol name is regenerated per release. The section keys
the prompt builder uses (`output_style`, `delivering_work_max`, …) sit in
between: semantic, but not a stability guarantee.

## Two prompt paths, and only one has "coding instructions"

The builder branches on the model. Models flagged `lean_prompt` get a short
identity line plus a `# Harness` block and nothing more. Everything else gets
the long-standing prompt: `# Doing tasks`, `# Tone and style`, and friends.
The predicate names the verbose set explicitly — `claude-3-*`, `haiku`,
`sonnet`, and `opus-4-0` through `opus-4-7`. Anchor: `lean_prompt`.

So **`keep-coding-instructions: true` is a no-op on the lean path.** The block
it preserves — "Don't add features, refactor, or introduce abstractions beyond
what the task requires", the comment-writing rules, "prefer editing existing
files" — is not in the prompt to begin with. Set it anyway: it becomes
load-bearing the moment a main session runs on Sonnet. Anchor:
`Don't add features, refactor, or introduce abstractions`.

Every clause that pulls against our response format is on the verbose path
too, so today they cost nothing. `# Doing tasks` carries "For exploratory
questions … respond in 2-3 sentences with a recommendation and the main
tradeoff", and `# Tone and style` carries "Your responses should be short and
concise" — the latter not gated by `keep-coding-instructions`, so on Sonnet
you get it either way. Anchor: `Your responses should be short and concise.`

## Custom output styles get no per-turn reminder

The docs claim all output styles trigger reminders. The renderer looks the
active style up in the **built-in** registry — `default`, `Proactive`,
`Explanatory`, `Learning` — and returns nothing on a miss, so a custom style
never fires one. Custom styles are merged into a copy of that registry
elsewhere, never into the one the renderer reads. Anchor:
`Remember to follow the specific guidelines for this style.`

## The style is not appended at the end

The docs say a style's text is added to the end of the system prompt. It is
injected at the `output_style` slot, ahead of the context-management,
act-don't-re-derive, `# Delivering work`, and `# Corrections` sections.

A style does something stronger than appending, though: it rewrites the
identity line from "helps users with software engineering tasks" to "helps
users according to your Output Style below, which describes how you should
respond to user queries". The sentence defining the role starts pointing at
your text. Anchor: `according to your "Output Style" below`.
