# klearframe-agent-team

A Claude Code plugin with a small agent team, the skills that lead it, and a guard on production branches.

You act as CEO/CTO: you set the business rules, the priorities and the major technical calls. The team lead runs the rest, from a rough need to a pull request on your base branch, and only comes to you for decisions.

## What's inside

- **Agents:** `product-analyst`, `architect`, `backend-engineer`, `frontend-engineer`, `qa-engineer` and `senior-code-reviewer`, plus three specialists the team lead calls only when a branch needs them: `security-reviewer`, `silent-failure-hunter` and `ux-copy-reviewer`. Claude names them with the plugin prefix, for example `klearframe-agent-team:architect`.
- **Skills:** `klearframe-agent-team:team-lead` takes a feature from a rough need to a merged pull request. `klearframe-agent-team:whats-next` answers "what's next?" and picks up work where it was left off. `klearframe-agent-team:linear-ticket` writes Linear tickets, and captures an idea as a ticket without starting the work.
- **Hook:** blocks `git push` to `master` or `main`, and `gh pr merge` into them, so only you release to production. It also blocks git commands that skip the project's git hooks (`--no-verify`).

## How a feature flows

1. **Ticket.** The team lead files the need as a Linear ticket in Backlog.
2. **Shape.** The product analyst and the architect read the code and draft the decisions only you can make. The team lead asks you about them one at a time.
3. **Spec and one approval.** The team lead writes the spec with your decisions numbered, puts the business rules and validation steps on the ticket, and asks you to approve the ticket. That's the only approval.
4. **Build.** It plans the work, has the architect check the plan delivers every decision in full, and hands each task to the backend or frontend engineer, test-first, with a code review after each task.
5. **Prove it.** The QA engineer targets what no test covered, adds adversarial tests and runs the ticket's validation steps on the real app. The senior reviewer checks the whole branch against the spec, joined by the specialists the diff calls for. The team lead sorts every finding before fixing it, and stops to ask you after 3 rounds that don't converge.
6. **Pull request.** The team lead opens a PR linked to the ticket, listing any guesses it made while waiting for you and what a rollback would cost, and merges it into your base branch once every merge condition holds. Releasing to production stays with you.

## Requirements

- **Claude Code.**
- **The [Superpowers](https://github.com/obra/superpowers) plugin,** installed wherever this plugin is: the skills and agents rely on `superpowers:*` skills.
- **The Linear connector (MCP),** for tickets, priorities and project updates.
- **A GitHub repo connected to Linear** (see [Using it in a repo](#using-it-in-a-repo)).
- **`jq` or `python3`** for the branch guard.
- **Optional: the Playwright connector (MCP),** so the QA engineer can run the ticket's UI validation steps in a real browser. Without it, those steps are marked ⏭️ with the reason.

## Installing it

There are two ways. Pick one per machine: with both, Claude loads two copies and the names clash.

- **From this GitHub repo,** which is also a plugin marketplace named `Klearframe`. This works in local Claude Code sessions only. In a session:

  ```
  /plugin marketplace add MinaAmrouche/klearframe-agent-team#main
  /plugin install klearframe-agent-team@Klearframe
  ```

  `#main` pins the marketplace to released work; without it, Claude Code follows the repo's default branch. To get a new release, run `/plugin marketplace update Klearframe`, or turn on auto-update for `Klearframe` under **Marketplaces** in `/plugin`.
- **Through your claude.ai account.** Build the package with `bash scripts/package.sh` (see [Releasing](#releasing)) and upload it on claude.ai. It then loads in local Claude Code sessions (listed as `synced` in `/plugin`) and in claude.ai/code cloud sessions. A repo's `.claude/settings.json` can't install it for cloud sessions.

The plugin has its own `linear-ticket` skill. If you also have a standalone `linear-ticket` skill, remove it: both would answer "create a ticket".

## Using it in a repo

The repo needs:

1. **A base branch that isn't `master` or `main`,** such as `develop`. The team lead merges there, and the hook blocks the production branch.
2. **An "Agent team" section in its `CLAUDE.md`.** The skills read the project's settings from it. Template:

   ```markdown
   ## Agent team

   The agent team comes from the `klearframe-agent-team` plugin. When the user hands off a feature, use the `klearframe-agent-team:team-lead` skill. When they only ask to create a ticket, use `klearframe-agent-team:linear-ticket`. When they ask what's next, for a status update or to pick up work, use `klearframe-agent-team:whats-next`. This section holds the project's settings for them.

   - Linear: team **<team>**, project **<project>**. Branches use the issue's Linear branch name (for example `feature/abc-123`).
   - Business priorities: the Linear document **Business priorities** in that project. Project updates are posted to the same project.
   - Base branch: `develop` (the team lead merges here). Production branch: `master`, which only the user merges or pushes to; the plugin's branch guard blocks it.
   - Verifying a branch means running <lint, test and build commands> on it.
   - Runtime modes that must keep working: <modes, or "one">.
   - Running the app for validation: <how to start it and where to call it>.
   ```

3. **Linear's GitHub integration with status automations.** In Linear, connect GitHub, then in the team's settings under **Workflows & automations** set "PR opened" to move the issue to **In Review** and "PR merged" to move it to **Done**. The team lead sets Backlog, Todo and In Progress itself, but never In Review or Done: it relies on these automations, and links each PR with the issue ID in its title and `Fixes <issue ID>` in its description.

The team writes its specs and plans to `docs/superpowers/`. They are part of how the work gets built, so keep them out of git (for example with `docs/superpowers/` in a global gitignore) unless a repo wants them shared.

## The branch guard

By default it guards `master` and `main` in every repo, whether or not the repo uses the team. To guard other branches in one repo, set `AGENT_TEAM_PROTECTED_BRANCHES` (space-separated) in that repo's checked-in `.claude/settings.json`. It replaces the default:

```json
{
  "env": {
    "AGENT_TEAM_PROTECTED_BRANCHES": "production master"
  }
}
```

An empty value still guards `master main`; there is no off switch.

The guard reads Claude's command with `jq`, or `python3` when `jq` is missing. With neither, it blocks every `git push` and `gh pr merge` rather than letting them through.

## Maintaining

### Releasing

This repo works on `develop`. Its own hook stops Claude from pushing `main`, so you merge each release yourself.

1. On `develop`: make the change, bump `version` in `.claude-plugin/plugin.json`, commit and push.
2. Merge `develop` into `main` (you). People who installed from the GitHub marketplace get it on their next marketplace update.
3. On `main`, run `bash scripts/package.sh`. It writes `klearframe-agent-team-<version>.plugin` from `HEAD`, leaving out `docs/` and `scripts/`.
4. Upload that file on claude.ai.
5. Check it loaded: in Claude Code, `/plugin` → **Installed** shows `klearframe-agent-team` at the new version with source `synced`. Then start a new session: `/reload-plugins` in a session that was already open picks up the agents and skills, but not the hook.

### Testing locally

- Hook: `bash hooks/protect-branch.test.sh`
- Manifest and layout: `claude plugin validate .`
- A full session: `claude --plugin-dir <path to this repo, or a packaged file copied to a .zip name>`. `--plugin-dir` silently loads nothing from a `.plugin` file; the same file renamed to `.zip` works. Run it in a scratch repo, not in a repo that still has its own copies of these agents and skills, or the names will clash. Once the plugin is installed through claude.ai, this loads a second copy, so test against a scratch repo only.

## License

[MIT](LICENSE) © Mina Amrouche
