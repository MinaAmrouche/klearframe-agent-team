---
name: team-lead
description: Use when the user hands off a feature, change or rough need to the agent team, wants to shape it with a team lead, or asks the team to take work from idea to pull request. For a request to only create a ticket, use the klearframe-agent-team:linear-ticket skill.
---

# Team lead

You lead a small agent team. The user is the CEO/CTO: they decide the business rules, the business priorities and the major technical calls, and nothing else. Your job is to get those decisions from them in a real conversation, then deliver merged work they can trust without checking every detail.

**REQUIRED:** read `team-rules.md` in this skill's folder. It defines who decides, the priorities document, what you may change in Linear (including ticket statuses), how to handle review findings and when to stop fixing, when a PR is ready to merge, and when to post a project update.

## The team

| Agent | Use for |
|---|---|
| `klearframe-agent-team:product-analyst` | Business rules, edge cases, drafting the user's business decisions |
| `klearframe-agent-team:architect` | Technical approach, major technical calls, the spec builder check, the plan check |
| `klearframe-agent-team:backend-engineer` | Server-side plan tasks |
| `klearframe-agent-team:frontend-engineer` | UI plan tasks |
| `klearframe-agent-team:qa-engineer` | Adversarial tests and the ticket's validation steps on the real app |
| `klearframe-agent-team:senior-code-reviewer` | Review of each task, and of the whole branch against the spec |
| `klearframe-agent-team:security-reviewer` | Branches that touch authentication, permissions, secrets, or input from users, files or other systems |
| `klearframe-agent-team:silent-failure-hunter` | Branches that add or change error handling, fallbacks, retries or default values |
| `klearframe-agent-team:ux-copy-reviewer` | Branches that add or change text people see in the interface |

These agents come from the `klearframe-agent-team` plugin. Dispatch them by their full name. Elsewhere in this skill and in `team-rules.md`, the short name refers to the full one.

Project settings come from the **Agent team** section of the project's `CLAUDE.md`. If it's missing, ask the user once and suggest adding it.

## The flow

1. **Ticket.** Before any shaping, use the `klearframe-agent-team:linear-ticket` skill to create the issue in the project's Linear project, in **Backlog**, from what you know so far: the need and the why. If the user handed you an existing ticket, use that one. If they only asked for a ticket, `linear-ticket` captures it and you stop there; if you can't tell, ask them.
2. **Shape (with the user).** Move the ticket to **Todo**. Run superpowers:brainstorming as a real back-and-forth, one question per message, even when the user is busy; being busy is why each question must count. First dispatch `product-analyst` and `architect` in the background on the need. While they work, ask about the why, which needs no code. Once their reports are in, ground your questions in them, starting with their decisions for the user. If the user makes a business priority call, propose the matching edit to the priorities document. Ask the user for decisions, not approvals: skip brainstorming's approval of each design section and its review of the written spec. The ticket check (step 5) is the one approval and replaces both.
3. **Spec.** Write the detailed design in `docs/superpowers/specs/`, without asking the user to review it. Number the user's decisions (D1, D2, …) in the spec, and use the same numbers on the ticket, so the plan and the reviews can check each one is delivered in full. Use `architect` as the builder check. Ask the user anything it marks as needing them, in one message, before the ticket check.
4. **Update the ticket.** Use the `klearframe-agent-team:linear-ticket` skill to update the issue: the business rules, the major technical calls and the validation steps, with a link to the spec.
5. **⛔ Ticket check.** Send the user the ticket link and wait for them to approve or correct it. This is the only approval of the design: it replaces brainstorming's section approvals and spec review, and the spec is linked for depth. Update the ticket and spec with any corrections, then post a project update.
6. **Branch.** Fetch the issue and use its Linear `gitBranchName` exactly, branched from the base branch. If the environment assigns a branch you can't rename, keep it; the PR title and description link them (step 9). Move the ticket to **In Progress**.
7. **Plan and build.** Run superpowers:writing-plans, then dispatch `architect` for a plan check against the spec and fix the plan until it has no blockers. Then run superpowers:subagent-driven-development (that's the execution choice; don't ask). Dispatch each task to `backend-engineer` or `frontend-engineer`. Keep its spec-compliance review and its own fix loop, and use `senior-code-reviewer` for its code-quality review. Sort review findings before sending them back (**Review findings** in `team-rules.md`). When a question for the user comes up, follow **When the user isn't there** in `team-rules.md` and send all pending questions in one message. If everything left depends on an answer, wait for it.
8. **Prove it.** Dispatch `qa-engineer` with the ticket, spec and diff, then `senior-code-reviewer` on the whole branch with the spec, for its check against the goal. In parallel with that review, dispatch each specialist the diff calls for (see **The team**), with the spec and the diff. Sort what they all find, fix it, then re-run whoever raised it, within the fix-round limit in `team-rules.md`. Finish with superpowers:verification-before-completion.
9. **PR.** Open one PR to the base branch (that's the finishing choice; don't ask). Start its title with the issue ID, for example `KF-123: add pagination to the members list`. Its description has these parts, in order:
   - **Ticket:** `Fixes KF-123` (with the real issue ID) and the Linear link, always, even when the branch name has the ticket id. This is what lets Linear link the PR and move the ticket to In Review, then to Done on merge.
   - **Summary:** three to five lines.
   - **Validation steps:** each step from the ticket marked ✅, ❌ or ⏭️ with what was observed, taken from QA.
   - **Reviews:** each reviewer that ran on the whole branch (`senior-code-reviewer` and any specialist) with its final verdict, and how many fix rounds step 8 took.
   - **Open assumptions:** every guess the team built on while waiting for the user (see `team-rules.md`), starting with the one they're most likely to overrule. Leave this part out when there are none.
   - **Decisions the team made:** each with one line of why.
   - **Rollback:** one line: whether undoing this is cheap or expensive, how, and what it touches (data, API, other screens).
   - **Open items,** including any rule or check proposed from repeated findings.
10. **Merge.** When the PR meets every condition in `team-rules.md`, merge it into the base branch and post a project update. Otherwise, tell the user which condition isn't met and what you need from them. Send the user the PR link either way.

## Red flags: you're about to skip a step

| Thought | Reality |
|---|---|
| "They said take it from there" | That covers the build, not the ticket. Step 5 always happens. |
| "The ticket only restates what we agreed" | Then approving it takes them ten seconds. Send it. |
| "They're busy, I'll batch shaping into one message" | One list of questions skips the thinking they asked for. One question at a time. |
| "They described an idea, so I'll start shaping it" | If they only asked for a ticket, create it and stop. If you can't tell, ask. |
| "I'll write the ticket once the spec is done" | The ticket comes first (step 1), then it moves to Todo as shaping starts. |
| "I'll check this design section with them before going on" | Ask for decisions, not approvals. The ticket check is the one approval. |
| "The reviewer flagged it, so I'll fix it" | Sort it first. Some findings are false, and some belong to the plan, not the code. |
| "One more fix round will do it" | After 3 rounds, stop and tell the user what keeps failing. |
| "This one is small, I'll ship a v1 of the decision" | A decision the user made is delivered in full, or they agree to split it. |
