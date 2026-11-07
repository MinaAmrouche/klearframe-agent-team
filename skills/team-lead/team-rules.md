# Team rules

Shared by the `team-lead`, `whats-next` and `linear-ticket` skills. Project settings (Linear project, base and production branches, priorities document, how to verify) come from the **Agent team** section of the project's `CLAUDE.md`.

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

**Ticket statuses** follow the work:

| Status | Set by | When |
|---|---|---|
| Backlog | you | the ticket is created, before any shaping |
| Todo | you | shaping starts with the user |
| In Progress | you | the branch is created and implementation starts |
| In Review | Linear | a linked PR is opened |
| Done | Linear | the linked PR is merged |

Never set In Review or Done yourself: Linear's GitHub automations do it, as long as the PR title starts with the issue ID and its description has `Fixes <issue ID>`. If a ticket didn't move when its PR was opened or merged, tell the user: the link or the automation is broken.

**Ask first:** anything that moves an item against the user's order, closing or cancelling a ticket, and any edit to the priorities document.

## Review findings

Before fixing anything a reviewer or QA reports, check each finding against the code and sort it:

- **False:** the claim doesn't hold, or the code already handles it. Drop it with one line of why.
- **Back to the user:** the fix depends on a business rule or a major technical call the ticket doesn't settle. Ask them.
- **Plan problem:** the code does what the plan said, and the plan missed something. Fix the plan and redo that part instead of patching around it; note what to keep.
- **Patch:** caused by this change, and the smallest fix is local and adds no new public surface.
- **Later:** real, but not caused by this change. Create a Backlog ticket with the `linear-ticket` skill and list it under the PR's Open items.

Drop a low-risk finding when its only fix is one more guard, check or fallback for a state nothing can reach: it adds code without removing a risk.

**Fix rounds.** A round is fixing findings, then re-running whoever raised them. Stop after 3 rounds that still leave a critical or major finding or a failing validation step, or as soon as a fixed failure comes back. Post a project update set to *at risk*, and tell the user what keeps failing, what was tried and what you recommend.

## When the user isn't there

When a question for the user comes up mid-build, keep working on what doesn't depend on it. If going on needs a guess, record the guess, what it's based on, and how hard it would be to undo. Build only on guesses that are cheap to undo; anything else waits for the user. The PR lists every guess under **Open assumptions**, the one the user is most likely to overrule first, and each one counts as an open question for merge condition 4.

## Lessons from repeated findings

When a finding repeats a mistake already made earlier in the branch or in a recent PR, the project's rules are missing something. Propose the smallest change that stops it coming back, preferring a check over prose: a lint rule, a test or a hook before a one-line `CLAUDE.md` rule. Put the proposal under the PR's Open items, and apply it only once the user agrees.

## Branch history

- **Updating a branch:** rebase it on the base branch and push with `--force-with-lease`. Never merge the base branch into it.
- **Tidying before merge:** once the PR meets every merge condition, fold fix-up and review commits into the branch commit they belong to (`git commit --fixup=<commit>`, then `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base branch>`). No commit should hold changes that would make sense in another commit of the same branch. Then check that the content didn't change (`git diff <branch tip before tidying> HEAD` prints nothing) and push with `--force-with-lease`. Skip this when the project squash-merges its PRs: the branch commits never reach the base branch.

## Merging

You merge into the base branch, never into the production branch. A hook blocks pushes and merges to the production branch; if it fires, tell the user what needs releasing and stop there.

A PR is ready to merge when every one of these holds:

1. Lint, tests and build pass on the PR branch, run fresh by you (and CI is green, if the project has CI).
2. `senior-code-reviewer` gave **Approve**, or **Approve with minor changes** and those changes are done. Every specialist reviewer that ran has no critical or major finding left.
3. Every validation step is ✅, or ⏭️ with a reason written in the PR.
4. No review comment is unresolved, and no question for the user or open assumption is left.
5. The user hasn't asked to review it, and its ticket has no `review-before-merge` label.

Then tidy the branch history (see **Branch history**), merge it the way the project's recent PRs were merged, delete the branch (remote and local), check that Linear moved the ticket to Done and post a project update.

## Project updates

Post a status update on the Linear project when something changes:
- the user approves a ticket at the ticket check
- a PR is opened or merged
- a critical bug is found
- work hits the fix-round limit
- the priorities change
- a decision changes direction
- work becomes blocked on the user

Don't post one when nothing changed. The update has these parts, in order:

1. **Since the last update:** what moved.
2. **In flight:** what's being worked on.
3. **Waiting on you:** questions, reviews, releases.
4. **Next.**

Set its health to *at risk* when something is blocked, otherwise *on track*.
