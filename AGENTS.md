# Agent instructions — awesoMux Linux

This repository is now the public `Interactive-Buffoonery/awesoMuxchy` project.
awesoMuxchy is an Omarchy edition of the shared Linux app; see
`docs/adr/0005-awesomuxchy-omarchy-edition.md`. The existing local folder name
does not need to match the repository name.

Read `AGENT_PROMPT.md` and `swift-gtk/AGENT_PROMPT.md` completely before
changing this repository. `swift-gtk/` is the sole application implementation.

This GTK repository is the Linux development home. The Electron prototype is
historical evidence preserved in this repository; see
`docs/electron-behavior-handoff.md` and `docs/linux-consolidation.md`. Follow
`docs/adr/0004-consolidate-linux-development.md` for the current sequence.

## Boundaries

- Treat any macOS awesoMux reference checkout as read-only. Check
  `git status --short` before and after every reference pass and stop if dirty.
- Never inspect or copy GPL/AGPL source or unlicensed implementation source.
- Use canonical MIT Ghostty only through the pinned `vendor/ghostty` submodule.
  Keep it clean; stage any Linux patches in a build copy.
- Keep the Ghostty ABI language-neutral under `ghostty-shim/`.
- Do not install packages or use `sudo` without Sarah approving the exact list.
- Do not add CI, GitHub Actions, hosted automation, dependency bots, or workflow
  badges. `./script/preflight.sh` is the local verification authority.
  Sarah's separately authorized repository code-review tools are an exception;
  their setup does not authorize additional agent-created automation.
- Do not log terminal contents, commands, clipboard contents, credentials,
  private paths, or arbitrary agent output.
- Do not commit or push implementation work without separate approval.
  Focused visual-QA screenshot/index commits and pushes are explicitly allowed.

## Product rules

- One native GTK4 window; workspaces are sidebar rows and splits are panes.
- The focused pane owns Git, branch, changes, pull-request, agent, and action
  context.
- awesoMux owns commands, menus, shortcuts, and command-palette routing.
- Persist workspace state as defensive, profile-scoped JSON snapshots.
- Use exact reference wording through `shared/resources/text-baseline.json`.
- Record all unavoidable platform differences in `PLATFORM_DIFFERENCES.md`.

## Verification

Keep `IMPLEMENTATION_STATUS.md`, `swift-gtk/IMPLEMENTATION_STATUS.md`, and
`FEATURE_PARITY_MATRIX.md` current. A visual milestone is incomplete until the
real app was run, the image was inspected, the comparison index was updated,
and the focused visual-QA commit was pushed to the verified origin. The origin
is public; inspect screenshots and notes for private information before upload.
Build and source checks may run in the development workspace on pinguchy.
Omarchy is the baseline Linux platform and required acceptance target. Desktop
behavior, visuals, and daily use must pass on a real Omarchy/Hyprland session
(on pinguchy or another verified Omarchy host). If it does not run well on
Omarchy, it does not pass. Builds and runs on other desktops are supplementary;
record missing Omarchy evidence as pending.
