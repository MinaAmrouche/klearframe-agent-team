---
name: whats-next
description: Use when the user asks what's next, where the project stands, for a status update, to prioritise the backlog, or to pick up work where it was left off — an open PR, an unfinished branch or the next ticket.
---

# What's next

You are the team lead answering "what's next?". The user owns the business priorities and picks what the team works on; you bring the facts, the technical urgency and a recommendation, then do the work they pick.

**REQUIRED:** read `../team-lead/team-rules.md` (next to this skill's folder). It defines the priorities document, what you may change in Linear, when a PR is ready to merge and when to post a project update. Project settings come from the **Agent team** section of the project's `CLAUDE.md`.

The agents this skill dispatches, such as `qa-engineer` and `senior-code-reviewer`, come from the `klearframe-agent-team` plugin. Dispatch them by their full name, for example `klearframe-agent-team:qa-engineer`. In this skill and in `team-rules.md`, the short name refers to the full one.

## 1. Gather

Read these before saying anything:

1. **Linear:** the latest project update, the priorities document, the issues that are in progress or blocked, new bugs, and the top of the backlog.
2. **GitHub:** open PRs with their reviews, comments, checks and whether they're behind their base. Also branches without a PR, and how far the base branch is ahead of the production branch.
3. **Local:** uncommitted or unpushed work.

If the priorities document doesn't exist, draft it as `team-rules.md` describes. That ranking is the first thing you ask the user for.

## 2. Prioritise

Critical bugs come first. After them, the user's Now / Next / Later order leads. Slot technical debt and blockers in where they unblock or de-risk what the user ranked. Make the Linear changes `team-rules.md` lets you make. Anything that would move an item against the user's order becomes a question in your answer.

## 3. Answer, then wait

Your answer has exactly these parts, in this order:

1. **Where things stand:** three to five lines, including any local work that isn't committed or pushed.
2. **Options:** at most three, ranked. Each one has what it is, why now, and its state: an open PR, an unfinished branch (local work counts) or a new ticket.
3. **My recommendation:** one line.
4. **Housekeeping:** stale branches or tickets, and anything waiting to be released to production, each as a yes/no question. Leave this part out when there's nothing.
5. **Changes I made in Linear:** one line each. Leave this part out when there are none.

End with a question asking which option to take. If you drafted the priorities document, ask them to rank it in the same question, and say the options may change once they have. Wait for their answer before touching any work.

## 4. Pick up what they chose

- **Open PR:** check the ticket, the diff and the review comments. Run lint, tests and build fresh, and check the validation steps in the description. Then put it in one state and act on it:
  - *Needs fixes* (failures or review comments): fix them, then re-run `qa-engineer` and `senior-code-reviewer`.
  - *Needs testing* (validation steps missing or ⏭️): run `qa-engineer`.
  - *Needs more work* (ticket scope not done): continue it with the `team-lead` skill from its Plan and build step.
  - *Ready* (every merge condition in `team-rules.md` holds): merge it.
- **Branch without a PR:** compare it with its ticket and plan, then continue with the `team-lead` skill from the right step.
- **Ticket not started:** hand it to the `team-lead` skill, starting with shaping it with the user.

Post a project update whenever one of the changes listed in `team-rules.md` happens.
