# Team rules

Shared by the `team-lead` and `whats-next` skills. Project settings (Linear project, base and production branches, priorities document, how to verify) come from the **Agent team** section of the project's `CLAUDE.md`.

## Who decides

- **The user:** every business rule and the business priority order, plus every major technical call as the `architect` agent defines it.
- **The team:** everything else, including technical urgency (critical bugs, blockers, technical debt). Decide it. If it changes behaviour, data or an API, add it to the PR's "Decisions the team made" list; naming and file layout don't go on the list.

## Business priorities

The priorities document in Linear belongs to the user. It has three sections, **Now**, **Next** and **Later**; each line is a goal or feature, its ticket links and one line of why.

- Read it before ranking anything.
- Never edit it yourself. When the user makes a business call in conversation, propose the edit and apply it once they agree.
- If it doesn't exist yet, draft it from the open Linear projects and tickets, show it to the user, and create it once they've ranked it.

## Changes in Linear

**Make these yourself:** set each issue's priority from the document and technical urgency (critical bugs are Urgent); add blocking links, labels and estimates; keep statuses true to reality; link PRs. Until the priorities document exists, leave existing priorities as they are.

**Ask first:** anything that moves an item against the user's order, closing or cancelling a ticket, and any edit to the priorities document.

## Merging

You merge into the base branch, never into the production branch. A hook blocks pushes and merges to the production branch; if it fires, tell the user what needs releasing and stop there.

A PR is ready to merge when every one of these holds:

1. Lint, tests and build pass on the PR branch, run fresh by you (and CI is green, if the project has CI).
2. `senior-code-reviewer` gave **Approve**, or **Approve with minor changes** and those changes are done.
3. Every validation step is ✅, or ⏭️ with a reason written in the PR.
4. No review comment is unresolved and no question for the user is open.
5. The user hasn't asked to review it, and its ticket has no `review-before-merge` label.

Then merge it the way the project's recent PRs were merged, delete the branch (remote and local), move the ticket to Done and post a project update.

## Project updates

Post a status update on the Linear project when something changes:
- the user approves a ticket at the ticket check
- a PR is opened or merged
- a critical bug is found
- the priorities change
- a decision changes direction
- work becomes blocked on the user

Don't post one when nothing changed. The update has these parts, in order:

1. **Since the last update:** what moved.
2. **In flight:** what's being worked on.
3. **Waiting on you:** questions, reviews, releases.
4. **Next.**

Set its health to *at risk* when something is blocked, otherwise *on track*.
