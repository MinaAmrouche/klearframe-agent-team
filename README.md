# klearframe-agent-team

A Claude Code plugin with a small agent team, the skills that lead it, and a guard on production branches.

- **Agents:** `product-analyst`, `architect`, `backend-engineer`, `frontend-engineer`, `qa-engineer` and `senior-code-reviewer`. Claude names them with the plugin prefix, for example `klearframe-agent-team:architect`.
- **Skills:** `klearframe-agent-team:team-lead` takes a feature from a rough need to a merged pull request. `klearframe-agent-team:whats-next` answers "what's next?" and picks up work where it was left off.
- **Hook:** blocks `git push` to `master` or `main`, and `gh pr merge` into them, so only you release to production.

It needs the **Superpowers** plugin turned on in the same claude.ai account, because the skills and agents rely on `superpowers:*` skills.

It is installed through the claude.ai account, so it loads in local Claude Code sessions (listed as `synced` in `/plugin`) and in claude.ai/code cloud sessions. A repo's `.claude/settings.json` can't install it for cloud sessions.

## Using it in a repo

The repo needs:

1. **A base branch that isn't `master` or `main`,** such as `develop`. The team lead merges there, and the hook blocks the production branch.
2. **An "Agent team" section in its `CLAUDE.md`.** The skills read the project's settings from it. Template:

   ```markdown
   ## Agent team

   The agent team comes from the `klearframe-agent-team` plugin. When the user hands off a feature, use the `klearframe-agent-team:team-lead` skill. When they ask what's next, for a status update or to pick up work, use `klearframe-agent-team:whats-next`. This section holds the project's settings for them.

   - Linear: team **<team>**, project **<project>**. Branches use the issue's Linear branch name (for example `feature/abc-123`).
   - Business priorities: the Linear document **Business priorities** in that project. Project updates are posted to the same project.
   - Base branch: `develop` (the team lead merges here). Production branch: `master`, which only the user merges or pushes to; the plugin's branch guard blocks it.
   - Verifying a branch means running <lint, test and build commands> on it.
   - Runtime modes that must keep working: <modes, or "one">.
   - Running the app for validation: <how to start it and where to call it>.
   ```

3. **Specs and plans that get committed.** The team writes them to `docs/superpowers/`. If a global gitignore hides that folder, re-include it in the repo's `.gitignore` with `!docs/superpowers/`.

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

## Releasing

This repo works on `develop`. Its own hook stops Claude from pushing `main`, so you merge each release yourself.

1. On `develop`: make the change, bump `version` in `.claude-plugin/plugin.json`, commit and push.
2. Merge `develop` into `main` (you).
3. On `main`, run `bash scripts/package.sh`. It writes `klearframe-agent-team-<version>.plugin` from `HEAD`, leaving out `docs/` and `scripts/`.
4. Upload that file on claude.ai.
5. Check it loaded: in Claude Code, `/plugin` → **Installed** shows `klearframe-agent-team` at the new version with source `synced`. Run `/reload-plugins` in a session that was already open.

## Testing locally

- Hook: `bash hooks/protect-branch.test.sh`
- Manifest and layout: `claude plugin validate .`
- A full session: `claude --plugin-dir <path to this repo or a packaged .plugin>`. Run it in a scratch repo, not in a repo that still has its own copies of these agents and skills, or the names will clash. Once the plugin is installed through claude.ai, this loads a second copy, so test against a scratch repo only.
