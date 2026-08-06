# Hermes Agent (Nous Research) — native systemd service, no container.
#
# CLI-only deployment: no messaging adapters are enabled, so nothing is exposed
# through Caddy and there is no subdomain. Talk to it over SSH with
# `hermes chat` or `hermes --tui`.
#
# Config here is authoritative — the module runs hermes in "managed mode", which
# blocks `hermes setup`, `hermes config edit` and `hermes config set` on the box.
# Change settings here and rebuild.
#
# The API key lives in ${envFile}, deliberately outside this repo (it is public).
# The module concatenates that file into $HERMES_HOME/.env at activation time,
# so the key must be added before hermes can reach a provider:
#
#   echo "OPENROUTER_API_KEY=sk-or-..." | sudo install -m 0600 -o hermes -g hermes /dev/stdin /var/lib/hermes/env
#
# then rebuild (activation regenerates .env; a bare restart is not enough).
#
# Claude Code is authenticated interactively, once, and it must be done AS THE
# hermes USER — the same trap that broke photon's auth.json. Claude writes
# credentials 0600 into $HOME/.claude, so logging in as harry produces a file
# the service cannot read, and running it against ${stateDir} as harry leaves
# root-of-the-tree files hermes no longer owns. Over SSH:
#
#   sudo -u hermes -H PATH=/etc/profiles/per-user/hermes/bin:$PATH claude
#
# It prints a URL, you paste the code back — no browser needed on the VPS.
# Verify with `claude auth status`. Credentials land in ${stateDir}/.claude and
# survive rebuilds; they are not in this repo and not in the Nix store.
{ pkgs, lib, claude-code-pkg, ... }:
let
  stateDir = "/var/lib/hermes";
  envFile = "${stateDir}/env";

  # `agent.disabled_toolsets` is the documented single switch: a denylist applied
  # *after* per-platform config, across the CLI and every gateway platform at
  # once. Preferred over `platform_toolsets` — that key is an allowlist written
  # by the interactive `hermes tools` UI (i.e. machine-managed state), and it is
  # per-platform, so pinning it here would mean restating the full toolset list
  # once for `cli` and again for `matrix` and keeping both in sync by hand.
  #
  # Only toolsets that are ON by default and unwanted need listing. video,
  # video_gen, stt, x_search, spotify, homeassistant, context_engine and yuanbao
  # are already off upstream and are deliberately not restated here.
  disabledToolsets = [
    # Inert on a headless VPS — `hermes doctor` reports "system dependency not
    # met", so they contribute no tool schemas today. Listed anyway so they
    # cannot quietly switch on if a future closure pulls the deps in.
    #
    # computer_use drives a desktop (mouse/keyboard/screen) and there is no
    # display here; image_gen, bfl and tts all want provider API keys we have
    # not set. `browser` used to be in this list — see extraPackages below for
    # what it took to make it real instead.
    "computer_use"
    "image_gen"
    "bfl"
    "tts"
  ];

  # Kept on: web, browser, delegation, terminal, file, code_execution, vision,
  # skills, todo, memory, session_search, clarify, cronjob.

  # Bundled skills are ~67-on-by-default and each costs ~75 bytes of always-on
  # index in every single prompt (the full SKILL.md is only read on demand).
  # That is ~6.9 KB of a ~17 KB system prompt spent advertising ComfyUI and
  # vLLM serving to a personal assistant. Disabling the irrelevant ones cuts
  # roughly 4 KB per turn and, more usefully, stops the model reaching for a
  # Weights-and-Biases workflow when you asked it to summarise an email.
  #
  # Whole categories dropped: creative (ComfyUI/p5js/TouchDesigner/ASCII art),
  # github, mlops,
  # software-development, smart-home (no Hue bridge), social-media (needs an X
  # API key). The apple/* skills are already inert — macOS-only, so they never
  # enter the index on Linux and are not listed here.
  disabledSkills = [
    # autonomous-ai-agents — claude-code is deliberately kept ON; it is the one
    # coding agent installed here (see extraPackages) and the skill is what
    # teaches hermes to drive it. hermes-agent is also ON: it is the hub doc
    # for hermes' own CLI, config, profiles and sub-agent spawning — i.e. the
    # skill that lets it reason about itself and orchestrate copies of itself.
    # Parts of it are moot under managed mode (`hermes setup`/`config set` are
    # blocked here), but the orchestration and self-knowledge halves are not.
    # The rest below are rival CLIs we do not ship.
    "codex" "computer-use" "opencode"
    # creative — image/video/audio/diagram generation, none of it wired up.
    "architecture-diagram" "ascii-art" "ascii-video" "baoyu-infographic"
    "claude-design" "comfyui" "design-md" "excalidraw" "humanizer"
    "manim-video" "p5js" "popular-web-designs" "pretext" "sketch"
    "songwriting-and-ai-music" "touchdesigner-mcp"
    # github — Claude Code already covers this workflow from the desktop.
    "codebase-inspection" "github-auth" "github-code-review" "github-issues"
    "github-pr-workflow" "github-repo-management"
    # mlops — model training/serving/eval, irrelevant to a 37 GB VPS assistant.
    "evaluating-llms-harness" "huggingface-hub" "llama-cpp"
    "serving-llms-vllm" "weights-and-biases"
    # software-development — debuggers, TDD, code review, spikes.
    "dogfood" "hermes-agent-skill-authoring" "inspecting-hermes-desktop-dom"
    "node-inspect-debugger" "plan" "python-debugpy" "requesting-code-review"
    "simplify-code" "spike" "systematic-debugging" "test-driven-development"
    # Single-service integrations for services not in use.
    "openhue" "xurl" "obsidian" "airtable" "notion" "teams-meeting-pipeline"
    "gif-search" "songsee"
    # research — kept grounded-citations and blogwatcher; these are narrower.
    "arxiv" "llm-wiki" "polymarket" "research-paper-writing"
  ];

  # That leaves 14 on: claude-code, hermes-agent, himalaya (email), docx/xlsx/pdf/nano-pdf/
  # powerpoint and ocr-and-documents (read and write the attachments you send
  # it), maps, google-workspace, grounded-citations, blogwatcher,
  # youtube-content.
in {
  services.hermes-agent = {
    enable = true;

    # Puts the `hermes` CLI on the system PATH and sets HERMES_HOME globally so
    # an interactive shell shares sessions/memories/cron with the gateway
    # service instead of creating its own ~/.hermes.
    addToSystemPackages = true;

    settings = {
      # Via OpenRouter (the module's default provider — no base_url needed).
      # Sonnet 5 rather than deepseek-v4-pro: better instruction-following and
      # tool use for an assistant that drives claude-code, a browser and a
      # dozen skills. It costs: $2/$10 per million tokens in/out against
      # DeepSeek's $0.44/$0.87, so ~4.5x in and ~11x out — and the $2/$10 is
      # Anthropic's introductory rate, which ends 2026-08-31 and reverts to
      # $3/$15. Fall back to "deepseek/deepseek-v4-pro" (or -flash, at
      # $0.09/$0.18) if the bill outgrows the benefit.
      #
      # Slug is dotless for the 5 generation — anthropic/claude-sonnet-5, not
      # -5.0; older families keep the dot (anthropic/claude-sonnet-4.6).
      model.default = "anthropic/claude-sonnet-5";

      # Thinking depth, sent to OpenRouter as `reasoning.effort` and mapped by
      # it onto Anthropic's adaptive-thinking control. Upstream default is
      # "medium"; "high" is the level Anthropic recommends as a floor for
      # anything intelligence-sensitive, which is most of what gets asked here.
      #
      # Ladder: minimal | low | medium | high | xhigh | max | ultra, or false
      # to switch thinking off entirely. xhigh is Anthropic's pick for coding
      # and agentic work and is a reasonable next step up, but only high and
      # below are confirmed to survive the OpenRouter passthrough for this
      # model — check the journal for a 400 before leaving it there.
      #
      # `agent.reasoning_overrides` takes a per-model dict ({"model" = "high";})
      # if a second model ever needs a different level; unnecessary while there
      # is only one.
      agent.reasoning_effort = "high";
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;

        # Raised from upstream's 2200/1375, and levelled: USER.md was sitting at
        # 1365 of its 1375 chars, i.e. completely full, so everything new it
        # learned about Harry was being rejected. There is no reason the profile
        # should get half the room the agent's own notes get.
        #
        # These are hard character caps, not soft targets: `memory_add` refuses
        # the write once the joined entries would cross the limit and tells the
        # model to consolidate or remove something first — the ceiling is felt
        # as dropped facts, not truncation.
        #
        # Both files are pasted into the system prompt verbatim every turn, so
        # this is a straight context trade: at ~2.75 chars/token the pair goes
        # from ~1300 to ~3300 always-on tokens when full, spending back most of
        # what disabling the skills below saved. Cheap at Sonnet input rates;
        # the cost is prompt bloat, not dollars.
        #
        # Note the injected block is a snapshot taken at session start, so a
        # memory saved mid-session does not reach the model until the next one.
        memory_char_limit = 4500;   # ~1650 tokens
        user_char_limit = 4500;     # ~1650 tokens
      };

      agent.disabled_toolsets = disabledToolsets;
      skills.disabled = disabledSkills;

      # Split across two providers, which hermes supports per-capability. If
      # `backend` were set instead it would force one provider to do both.
      #
      # Parallel for search: it is built for multi-step agentic research and is
      # the strongest of the five on hard questions — it self-reports 47% on
      # HLE against Exa's 24% and Tavily's 21%, and independent testing puts it
      # in the top tier. The cost is latency, ~13s per search against sub-second
      # for the snappier providers. Worth it for hard queries, not for "what's
      # the weather".
      #
      # Firecrawl for extract: highest measured relevance of the set and by far
      # the best page-extraction stack. Parallel can extract too, but this is
      # the half Firecrawl is actually best at.
      #
      # Ruled out: tavily (consistently benchmarks below the leaders), searxng
      # (free and private, but metasearch scraping rather than agentic
      # research). Brave scored well independently but hermes has no backend
      # for it.
      web = {
        search_backend = "parallel";
        extract_backend = "firecrawl";
      };
    };

    # Matrix is the only messaging platform enabled. Signal was considered and
    # dropped; Telegram/Discord/Slack are deliberately absent — the bot API for
    # those is not end-to-end encrypted.
    #
    # Provider SDKs are optional extras upstream, and the venv is sealed — the
    # Nix store is read-only, so nothing can be pip-installed at runtime. Any
    # extra we actually use has to be built in here.
    #
    # `parallel-web` and `firecrawl` back web_search and web_extract. Note the
    # trap: the extra literally named `web` is FastAPI/uvicorn for the
    # dashboard, nothing to do with web search. Without these two, `hermes
    # doctor` still reports "✓ web" — it only checks that the API keys exist —
    # and the failure surfaces at the first search, as an ImportError the agent
    # helpfully suggests fixing with `uv pip install`, which cannot work here.
    #
    # `matrix` is Linux-only and pulls mautrix + python-olm.
    extraDependencyGroups = [ "matrix" "parallel-web" "firecrawl" ];

    # What it takes to make the `browser` toolset real on NixOS. Hermes gates
    # browser_* behind two checks (tools/browser_tool.py): the `agent-browser`
    # CLI must be on PATH, and a Chromium must be findable. Without both it
    # hides the tools rather than advertising a capability that hangs on first
    # use — which is why `hermes doctor` said "system dependency not met".
    #
    # Upstream's install path is `npx playwright install --with-deps chromium`,
    # which is a dead end here: those are prebuilt FHS binaries that will not
    # run against NixOS's loader. Both pieces are packaged instead, and both
    # are in the binary cache, so a deploy substitutes them straight onto the
    # VPS rather than pushing ~1.9 GB up this uplink.
    #
    # extraPackages lands them on the systemd service PATH *and* in the hermes
    # user profile, so terminal commands, skills and cron jobs see them too.
    #
    # claude-code gives hermes a real coding agent to delegate to — the bundled
    # `claude-code` skill (kept enabled above) drives it, preferring `claude -p`
    # print mode, which needs no PTY. Supplied via specialArgs rather than
    # `pkgs.claude-code`; flake.nix explains why that distinction matters.
    #
    # Where it can work: everywhere. This used to say that ProtectSystem=strict
    # confined `claude` to ${stateDir} and that systemd, not Claude's own
    # prompt gate, was the boundary that mattered — which made
    # `--dangerously-skip-permissions` far less alarming than it sounds. That
    # is no longer true; see the privilege grant at the bottom of this file.
    # `claude -p … --dangerously-skip-permissions` now means what it says.
    extraPackages = [ pkgs.agent-browser pkgs.chromium claude-code-pkg ];

    # Non-secret, so safe to have in the world-readable Nix store. Everything
    # identifying or authenticating lives in ${envFile} instead — see below.
    environment = {
      # The documented way to point agent-browser at a pre-installed browser
      # (checked before any PATH lookup or Playwright cache scan). Chromium is
      # on PATH via extraPackages anyway, but naming the store path exactly
      # removes the ambiguity — and it is what the Chromium-presence check
      # looks at first.
      AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";

      # Claude Code ships a self-updater that rewrites its own install dir.
      # That dir is the Nix store here, so every run would otherwise attempt a
      # write to a read-only path and warn about it. Version is a Nix concern:
      # bump the claude-code flake input (`update-claude`) and redeploy.
      DISABLE_AUTOUPDATER = "1";

      # fast | one-shot | agentic. Already the upstream default, but pinned
      # because it is the whole reason Parallel was picked over a faster
      # provider — a silent default change would quietly undo that.
      PARALLEL_SEARCH_MODE = "agentic";

      MATRIX_HOMESERVER = "https://matrix.org";
      # `optional` tries E2EE but keeps working unencrypted if crypto fails to
      # initialise — i.e. it can silently downgrade. mautrix + python-olm are
      # confirmed present in the built closure, so it should engage; grep the
      # journal for "E2EE" after first start to be sure. `required` fails closed
      # instead, if you'd rather it refuse to run than send plaintext.
      MATRIX_E2EE_MODE = "optional";
      # Rooms need an @mention; DMs always get a response.
      MATRIX_REQUIRE_MENTION = "true";
      # The bot auto-accepts room invites, so without this anyone who can invite
      # it into a room could reach it. Keep public-room joins off.
      MATRIX_ALLOW_PUBLIC_ROOMS = "false";
    };

    # Secrets and personal identifiers, kept out of this public repo:
    #   PARALLEL_API_KEY      web_search  — platform.parallel.ai
    #   FIRECRAWL_API_KEY     web_extract — firecrawl.dev
    #   MATRIX_ACCESS_TOKEN   full access to the bot's Matrix account
    #   MATRIX_ALLOWED_USERS  your @user:matrix.org — who may talk to the bot
    #   MATRIX_ALLOWED_ROOMS  which rooms may trigger a turn
    #   MATRIX_RECOVERY_KEY   optional; lets the bot self-sign its device so
    #                         Element will share encryption sessions with it
    # Upstream is explicit that a locked-down deployment sets BOTH the user and
    # room allowlists: with either unset, anything that reaches the bot in a
    # joined room can trigger an agent turn.
    environmentFiles = [ envFile ];
  };

  # The module's container.hostUsers option — which normally grants an
  # interactive user access to the service state — is gated on
  # container.enable, so in native mode we join the group by hand. State dirs
  # are 2770 hermes:hermes, so group membership is what makes `hermes chat`
  # work as harry rather than erroring with EACCES on /var/lib/hermes.
  users.users.harry.extraGroups = [ "hermes" ];

  # ── Full root on this host ────────────────────────────────────────────────
  #
  # The agent ingests untrusted text by design (web_search, Firecrawl, the
  # browser toolset) and is reachable over Matrix, so a prompt injection in a
  # fetched page reaches root here. Not a new class of risk — the self-deploy
  # path this replaced handed over root by construction, since a NixOS config
  # the agent authors can add root SSH keys — but it is now direct. The
  # MATRIX_ALLOWED_USERS/ROOMS allowlists above are the front door.
  #
  # Both halves below are required; granting only the sudo rule is the trap.
  # Rules rather than adding hermes to `wheel`, which would work but splits the
  # grant across two files and inherits a setting meant for human admins.
  security.sudo.extraRules = [{
    users = [ "hermes" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # Sudo alone buys nothing while the sandbox is up: ProtectSystem=strict is a
  # mount namespace, and namespaces are inherited across setuid, so a sudo'd
  # rebuild would run as uid 0 and still see /nix and /boot read-only.
  # NoNewPrivileges blocks the setuid transition before even that.
  # ReadWritePaths must be emptied rather than widened — a non-empty list
  # forces the namespace even with ProtectSystem=off. mkForce because upstream
  # assigns these directly, not with mkDefault.
  systemd.services.hermes-agent.serviceConfig = {
    ProtectSystem = lib.mkForce "off";
    NoNewPrivileges = lib.mkForce false;
    PrivateTmp = lib.mkForce false;
    ReadWritePaths = lib.mkForce [ ];
  };

  # The service still runs as hermes, not root: root is a sudo away, but files
  # it creates stay hermes:hermes, so harry keeps group access to sessions and
  # memories. Running the unit as root would flip every new file to root
  # ownership — the state-dir ownership trap, inverted and permanent.
  #
  # One consequence to know before letting the agent deploy this host from its
  # own checkout: the grant lives in the config being deployed, so any config
  # older than it un-grants it. A stale checkout restores the sandbox and
  # deletes the sudoers rule mid-task, and the agent can neither undo that nor
  # diagnose it — from inside, the evidence is a sudo prompt contradicting a
  # config it can still read saying NOPASSWD. It must pull before deploying.
  # (Happened once, 2026-08-06.)
}
