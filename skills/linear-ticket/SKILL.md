---
name: linear-ticket
description: Use when the user wants a Linear ticket, issue or task created, for example "create a ticket", "open an issue", "add this to Linear", "log this in Linear", or when they describe a bug, feature, chore or improvement to file. Also used by the team-lead skill to create and update the ticket for the work it leads.
---

# Linear ticket

You write well-formed Linear tickets and create them through the Linear MCP.

**REQUIRED:** read `../team-lead/team-rules.md` (next to this skill's folder). It defines the priorities document, the ticket statuses and what you may change in Linear. Project settings (Linear team and project) come from the **Agent team** section of the project's `CLAUDE.md`. If it's missing, ask the user for the Linear project once and suggest adding the section.

## Capture only, or start the work?

The user often asks for a ticket only so an idea isn't forgotten. Decide which request this is before anything else:

- **Capture only** ("create a ticket for…", "log this so I don't forget"): follow **Capture only** below.
- **Start the work** ("let's build…", "take this to a PR", "work on this"): use the `team-lead` skill. It calls this skill to create the ticket first.
- **Unclear:** ask the user one question: capture it only, or start working on it?

## Capture only

1. Write the ticket from what the user said, following **Ticket structure**. If the topic is ambiguous, ask one focused question first.
2. Work out its priority as `team-rules.md` allows: from the priorities document and technical urgency (critical bugs are Urgent). If neither gives a priority, ask the user which they prefer, with two options: no priority, or your suggestion (Urgent, High, Medium or Low) with one line of why.
3. Create it in the project's Linear project with the status **Backlog** and that priority.
4. Send the user the ticket's title and link, and stop. Don't start brainstorming, don't dispatch agents and don't post a project update. When the user picks the ticket later (through `whats-next` or by handing it off), the `team-lead` skill takes it from its Shape step.

## Ticket structure

### Title

Short, imperative, specific. No trailing punctuation. Examples:
- "Add pagination to the team members list"
- "Fix crash when uploading files larger than 10 MB"

### Description

Clear, concise prose, with these sections:

- **Context:** one or two sentences on why this ticket exists and what problem it solves. Skip obvious context.
- **What needs to be done:** a short numbered list of concrete, actionable steps or changes.
- **Decisions:** only when the work was shaped with the user. Each decision they made in one line, numbered as in the spec (D1, D2, …), so the plan check and the reviews can confirm each one is delivered. Leave the section out otherwise.
- **Docs / tests:** only when the ticket changes user-facing behaviour, a public API, or code with existing tests. Say what to update or add. Leave the section out for internal refactors with no observable change and no test surface.
- **Validation steps:** always. A numbered list someone can follow to check the ticket is done, tailored to its type:
  - *Feature:* the happy path, then at least one edge case.
  - *Bug fix:* reproduce the bug, then confirm it no longer occurs.
  - *Refactor:* confirm behaviour is unchanged (existing tests, smoke test of the affected flows).
  - *Chore or infra:* confirm the expected state (CI passes, config applied, version bumped).

  Be specific: "click Save and confirm the toast appears" beats "test the feature". Write them yourself from the topic; don't ask the user for them.

## Creating and updating the ticket

Use the Linear MCP's `save_issue`:
- **Create:** `title`, `description` (markdown, real newlines), `team` and `project` from `CLAUDE.md`, `state` "Backlog", and `priority` when you set one.
- **Update:** pass the issue's `id` with only the fields that change.

Add an assignee only when the user asks. Labels, estimates and blocking links follow `team-rules.md`.

After creating or updating, give the ticket's title and Linear link.

## Rules

- Never invent requirements. Ask one focused question when the topic is ambiguous.
- Keep the description tight. No filler such as "This ticket aims to".
- If the Linear MCP isn't connected, output the ticket as markdown and tell the user to connect the Linear connector.
