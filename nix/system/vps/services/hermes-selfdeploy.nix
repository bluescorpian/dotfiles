# Lets Hermes rewrite and deploy this machine's own NixOS configuration.
#
# This is a deliberate grant of root. `nixos-rebuild switch` on a flake the
# agent authors *is* root by construction — a config can add root SSH keys,
# activation scripts or systemd units — so no sudoers narrowing would contain
# it. Worth remembering that this agent ingests untrusted text by design
# (web_search, Firecrawl extraction, the browser toolset) and is reachable over
# Matrix, so a prompt injection in a fetched page reaches this. Accepted
# knowingly; the allowlists in hermes.nix are the thing keeping the front door
# shut, so keep MATRIX_ALLOWED_USERS/ROOMS tight.
#
# Why a trigger file rather than sudo:
#
# The agent cannot escalate in-process, and that is not a policy choice — it is
# mechanical. hermes-agent.service runs ProtectSystem=strict, which is
# implemented as a *mount namespace*, and namespaces are inherited across
# setuid. A `sudo nixos-rebuild switch` inside the service would run as root and
# still see /nix, /etc and /boot read-only, then fail. Relaxing the sandbox to
# fix that would weaken the unit for every other thing hermes does.
#
# So the privileged half lives outside the sandbox: the agent touches a trigger
# file inside its own writable state dir, a .path unit notices, and the rebuild
# runs as root in a clean context. hermes-agent.service keeps every hardening
# flag it has today. It also sidesteps a nasty failure mode — an in-process
# `sudo nixos-rebuild switch` would kill its own parent process when activation
# restarts hermes-agent, halfway through the switch.
{ pkgs, lib, domain, ... }:
let
  stateDir = "/var/lib/hermes";
  hermesHome = "${stateDir}/.hermes";
  workspace = "${stateDir}/workspace";
  repoDir = "${workspace}/dotfiles";

  # Inside stateDir, so the sandboxed agent can create it; watched from outside.
  trigger = "${stateDir}/deploy-request";
  deployLog = "${stateDir}/deploy.log";

  # Cloned over HTTPS so a fresh machine works with no credentials at all.
  # The *push* URL is switched to SSH by the init unit — see the key below.
  repoUrl = "https://github.com/bluescorpian/dotfiles.git";
  repoPushUrl = "git@github.com:bluescorpian/dotfiles.git";

  deployKey = "${stateDir}/.ssh/id_ed25519";

  # A store file rather than a heredoc in the init script: `<<EOF` needs its
  # terminator at column zero, and inside a Nix indented string only the
  # *common* indentation is stripped, so the marker keeps leading spaces and
  # the heredoc never closes.
  sshConfig = pkgs.writeText "hermes-ssh-config" ''
    Host github.com
      IdentityFile ${deployKey}
      IdentitiesOnly yes
      StrictHostKeyChecking accept-new
  '';

  # A skill, not an AGENTS.md: AGENTS.md is loaded as project context on every
  # single turn, which would permanently re-inflate the system prompt we spent
  # effort trimming in hermes.nix. A skill costs ~75 bytes of always-on index
  # and is only read in full when the agent actually intends to deploy.
  #
  # Custom skills are safe from the bundled-skill sync: skills_sync.py is
  # manifest-driven and only ever touches names it recorded itself, so anything
  # not in .bundled_manifest is left alone.
  skill = pkgs.writeTextDir "SKILL.md" ''
    ---
    name: vps-selfdeploy
    description: "Edit and deploy this VPS's own NixOS config (hrry.sh)."
    version: 1.0.0
    license: MIT
    platforms: [linux]
    metadata:
      hermes:
        tags: [NixOS, Deployment, Infrastructure, Self-Modification]
    ---

    # Deploying changes to this VPS

    You run on a NixOS machine whose entire configuration is declarative, and
    you can change it. The checkout at `${repoDir}` is yours to edit; it is the
    source this host rebuilds from when you ask it to.

    Your own settings are part of it: model, enabled toolsets, enabled skills,
    Matrix behaviour and web backends all live in
    `${repoDir}/nix/system/vps/services/hermes.nix`. Host-wide things (packages,
    services, firewall) are elsewhere under `${repoDir}/nix/system/vps/`.
    Read `${repoDir}/CLAUDE.md` first — it describes the repo's conventions.

    ## The loop

    1. **Edit.** Change the `.nix` files under `${repoDir}`. For anything
       non-trivial, delegate to Claude Code — it is installed here and is much
       better at multi-file edits:
       `claude -p "<task>" --dangerously-skip-permissions` run with
       `workdir=${repoDir}`. That flag is safe here: systemd confines you to
       `${stateDir}` regardless of what Claude decides to do.

    2. **Check it evaluates**, before deploying. This is fast, needs no
       privileges, and catches essentially every syntax and option error:

       ```
       nix eval --raw ${repoDir}/nix#nixosConfigurations.vps.config.system.build.toplevel.drvPath
       ```

       If that prints a `.drv` path, the config is valid. If it errors, fix it
       and repeat — do not deploy a config that does not evaluate.

    3. **Deploy.** You cannot run `nixos-rebuild` yourself; you ask for it:

       ```
       touch ${trigger}
       ```

       A privileged unit outside your sandbox picks that up within a second and
       runs `nixos-rebuild switch`.

    4. **Read the result** at `${deployLog}`. It ends in either `=== SUCCESS ===`
       or `=== FAILED ===` with the error above it. Full history is in
       `journalctl -u hermes-deploy`.

    ## Things that will bite you

    - **A successful deploy restarts you.** That is deliberate — it is the only
      way changes to your own config take effect. Expect the conversation to
      end at step 3. When you come back, read `${deployLog}` to find out
      whether it worked, and tell the user.
    - **Your eval check in step 2 cannot see untracked files**, because a bare
      path inside a git repo is evaluated through git. A brand-new `.nix` file
      you never `git add`ed will appear missing. Either `git add` it first, or
      check with the same `path:` form the deploy uses:
      `nix eval --raw path:${repoDir}/nix#nixosConfigurations.vps.config.system.build.toplevel.drvPath`
      The deploy itself is unaffected — it uses `path:`, which copies the
      directory as-is.
    - **Commit and push your work.** Harry also deploys this host from his
      desktop, from a different checkout of the same repo. Anything you leave
      only on this box gets silently reverted the next time he does that.
      `git commit` then `git push origin HEAD:<a-branch>` — push to a branch,
      never to `main`, so he can review it.
    - **This repo is public.** Never commit API keys, tokens or passwords.
      Secrets belong in `${stateDir}/env`, which is outside the repo.
    - If a deploy breaks the machine badly, you may not come back at all.
      Harry can roll back from the Hetzner console. Prefer small changes.
  '';

  deployScript = ''
    # Clear the trigger first: the .path unit fires on existence, so leaving it
    # in place would re-arm the moment this unit exits.
    rm -f ${trigger}

    # Created here rather than by tmpfiles so ownership is right on first run;
    # the agent must be able to read its own deploy result.
    install -o hermes -g hermes -m 0644 /dev/null ${deployLog}

    {
      echo "=== hermes self-deploy: $(date -Is) ==="

      # Guarded rather than left to `set -e`: an abort here would end the log
      # with neither SUCCESS nor FAILED, and the agent reads that verdict to
      # decide what to tell the user.
      if [ ! -e ${repoDir}/.git ]; then
        echo "no checkout at ${repoDir} — is hermes-dotfiles-init.service ok?"
        echo "=== FAILED ==="
        exit 1
      fi

      cd ${repoDir}

      echo "HEAD:   $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
      echo "dirty:"
      git status --short || true
      echo
      echo "--- nixos-rebuild switch ---"

      # `path:` rather than a bare path, for two reasons.
      #
      # A bare path inside a git repo makes Nix fetch it *as* a git repo, and
      # libgit2 then refuses it outright: this unit is root and the checkout is
      # owned by hermes, so the ownership check fails with "repository path is
      # not owned by current user". Same reason plain `git` needs the
      # safe.directory entry set in this unit's environment.
      #
      # It also fixes the untracked-file trap for free. Git-based fetching only
      # sees tracked files, so a module the agent just wrote but never `git
      # add`ed would evaluate as missing; `path:` copies the directory as-is.
      #
      # /run/current-system rather than a pkgs reference: nixos-rebuild is built
      # by the NixOS module set, not exposed as a package, and this way the
      # running system's own copy does the switch.
      if /run/current-system/sw/bin/nixos-rebuild switch --flake path:${repoDir}/nix#vps; then
        echo "=== SUCCESS ==="
      else
        echo "=== FAILED (exit $?) ==="
        exit 1
      fi
    } >> ${deployLog} 2>&1

    # switch-to-configuration only restarts a unit whose *definition* changed.
    # Hermes' config.yaml is regenerated at activation from the same unit file,
    # so a pure settings change would otherwise sit on disk unread until the
    # next unrelated restart. Unconditional restart is what makes the agent's
    # edits to its own config actually take effect.
    systemctl try-restart hermes-agent.service || true
  '';
in
{
  # Seeds the checkout, the git identity, and the push key. Ordered before
  # hermes-agent so the workspace is populated the first time the agent looks.
  systemd.services.hermes-dotfiles-init = {
    description = "Seed Hermes' dotfiles checkout and deploy key";
    wantedBy = [ "multi-user.target" ];
    before = [ "hermes-agent.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.git pkgs.openssh pkgs.coreutils ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "hermes";
      Group = "hermes";
    };

    environment.HOME = stateDir;

    script = ''
      mkdir -p ${workspace} ${stateDir}/.ssh
      chmod 0700 ${stateDir}/.ssh

      # Read-only clone needs no credentials; pushing does. Generated here so
      # the private half never touches this repo or the Nix store. Add the
      # printed public key to GitHub as a deploy key WITH WRITE ACCESS to let
      # the agent push branches — until then, push simply fails and everything
      # else still works.
      if [ ! -f ${deployKey} ]; then
        ssh-keygen -t ed25519 -N "" -C "hermes@${domain}" -f ${deployKey}
      fi
      echo "hermes deploy key (add to GitHub as a deploy key, write access):"
      cat ${deployKey}.pub

      install -m 0600 ${sshConfig} ${stateDir}/.ssh/config

      if [ ! -e ${repoDir}/.git ]; then
        git clone ${repoUrl} ${repoDir}
      fi

      # Fetch over HTTPS (always works), push over SSH (works once the deploy
      # key is registered).
      git -C ${repoDir} remote set-url --push origin ${repoPushUrl}
      git -C ${repoDir} config user.name "Hermes"
      git -C ${repoDir} config user.email "hermes@${domain}"
    '';
  };

  # The privileged half. Fires on the trigger file appearing.
  systemd.paths.hermes-deploy = {
    description = "Watch for a deploy request from Hermes";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists = trigger;
  };

  systemd.services.hermes-deploy = {
    description = "Rebuild this host from Hermes' dotfiles checkout";
    path = [ pkgs.git pkgs.coreutils pkgs.nix pkgs.openssh pkgs.systemd ];

    # Deliberately no sandboxing: this unit exists precisely to run outside the
    # agent's namespace. Runs as root.
    serviceConfig.Type = "oneshot";

    # Root inspecting a hermes-owned checkout trips git's ownership guard, so
    # the status lines above would otherwise be replaced by a "dubious
    # ownership" error. Scoped to this one repo via the environment rather than
    # written into a global gitconfig.
    environment = {
      GIT_CONFIG_COUNT = "1";
      GIT_CONFIG_KEY_0 = "safe.directory";
      GIT_CONFIG_VALUE_0 = repoDir;
    };

    # This unit is defined by the very config it deploys, so switch-to-
    # configuration would otherwise be entitled to stop it mid-rebuild.
    restartIfChanged = false;
    stopIfChanged = false;

    script = deployScript;
  };

  # Symlinked from the store rather than copied: the agent reads it, never
  # writes it, and this way editing the skill is a rebuild like everything else.
  systemd.tmpfiles.rules = [
    "d ${hermesHome} 2770 hermes hermes -"
    "d ${hermesHome}/skills 2770 hermes hermes -"
    "d ${hermesHome}/skills/local 2770 hermes hermes -"
    "L+ ${hermesHome}/skills/local/vps-selfdeploy - - - - ${skill}"
  ];
}
