# agents-assemble

A skill for running several coding agents in parallel on one repository — and getting a
merge you can trust at the end.

Parallel agents fail at the seams, never in the lanes. Give five agents five modules and each
finishes its own fine; what breaks is what they share — one database, one port, one schema,
one translation file, one test that counts things across the whole system.

Everything here was paid for. It comes out of a single session where six phases ran with
96 agents, producing 240 commits and roughly 116k lines against a monorepo with a seven-stage
gate. Every phase ended with the full suite green, and every failure along the way happened
at a seam. Those failures are written down in
[`references/failure-catalog.md`](references/failure-catalog.md) — what you see, what it
actually is, and what to do — and the rest of the skill is a summary of that file.

## Install

Claude Code reads personal skills from `~/.claude/skills/`:

```bash
git clone https://github.com/<you>/agents-assemble ~/.claude/skills/agents-assemble
```

Then invoke it by name, or let it trigger on its own when you ask for a large parallel
build-out. Other runtimes also accept `~/.agents/skills/`.

## What's inside

| File | What it is |
|---|---|
| [`SKILL.md`](SKILL.md) | The skill itself — the shape, what to isolate, the six rules, red flags |
| [`lane.sh`](lane.sh) | Creates and tears down a lane: git worktree + branch + its own database + env files, one command |
| [`references/failure-catalog.md`](references/failure-catalog.md) | Ten real seam failures with the fix for each |
| [`references/integrator-checklist.md`](references/integrator-checklist.md) | Per-merge and post-merge lists for the one person who merges |
| [`references/lane-prompt-template.md`](references/lane-prompt-template.md) | Build → review → fix prompts, with the boundaries a lane cannot infer |

## The shape

```
Foundation (serial, one lane)  →  Lanes (parallel)  →  Integration (serial, you)
   everything shared lands here     build → review → fix   merge one at a time
```

The rule that carries most of the weight:

> A lane can prove its own work. Only the integrator can prove the system.
> Every lane is green on its own branch. That fact predicts nothing about the merge.

## lane.sh

Configured through `LANE_*` environment variables so it is not tied to any one stack. Run it
with no arguments for usage.

```bash
export LANE_REPO=/path/to/repo
export LANE_ENV_FILES=".env apps/api/.env"
export LANE_DB_KIND=postgres LANE_DB_CONTAINER=my-postgres LANE_DB_USER=app LANE_DB_BASE=app_dev
export LANE_DB_DEPLOY="pnpm --filter api db:deploy"

lane.sh up   lane-a phase-42     # -> prints the worktree path
lane.sh down lane-a              # removes worktree, branch and database
```

## Testing

The guidance was written against observed failures rather than invented ones, and checked by
running the same planning task with and without the skill. Two things are worth saying plainly:

- On a machine that already carries a project's own accumulated notes, agents recover much of
  this on their own. The skill's value is portability to a fresh project, a tool that runs,
  and an ordering you can follow rather than notes you have to reconstruct.
- Three findings were missed by *every* run without the skill: tests that assert system-wide
  totals, a shared-contract change turning sibling branches red at merge, and conflict
  resolution by concatenation dropping a closing token from a code file. Those three are the
  core of what this teaches.

## License

MIT
