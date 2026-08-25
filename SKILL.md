---
name: agents-assemble
description: Use when dispatching several coding agents to work in parallel on one repository — five lanes, big fan-out, "จัดทีมชุดใหญ่", multi-agent build-outs — or when parallel work merged cleanly but the suite broke, every lane reported green yet integration is red, or agents overwrote each other's shared files. Also when a parallel run should come back as a phased progress tree with per-agent tokens rather than five loose reports.
---

# Agents Assemble

## Overview

Parallel agents fail at the seams, never in the lanes.

Give five agents five modules and each finishes its own fine. What breaks is what they
*share*: one database, one port, one schema, one translation file, one test that counts things
across the whole system.

> **A lane can prove its own work. Only the integrator can prove the system.**
> Every lane is green on its own branch. That fact predicts nothing about the merge.

## The shape

```
Foundation (serial, one lane)  →  Lanes (parallel)  →  Integration (serial, you)
   everything shared lands here     build → review → fix   merge one at a time
```

**Never skip the foundation.** Anything more than one lane touches — schema, shared types,
permissions, menu, error codes, translation namespaces, seed, test-data cleanup — lands in one
serial commit set first, gate green, before any lane branches. Lanes built on a moving base
cannot be merged.

## Two ways to run it

Same shape either way — only the dispatch differs.

| | Hand-dispatched | Workflow script |
|---|---|---|
| How | one `Agent` call per lane, you steer between them | one `Workflow` run: `pipeline(lanes, build, review, fix)` |
| Fits when | the lane list is still moving, or lanes need conversation mid-flight | the lane list is fixed before dispatch and every lane runs the same three stages |
| You get | full control, redirection at any moment | phases with per-agent tokens and time (`/workflows`), reports as JSON, resume one dead lane without re-running the rest |
| You pay | tracking five conversations yourself | the shape is fixed once it starts — changing it means editing the script and resuming |

Either way the foundation, every merge and the final gate stay **here**, serial, yours. The
workflow runs the lanes and nothing else.

**REQUIRED before writing one: `references/workflow-mode.md`** — the script, and the four ways
a workflow silently loses lane isolation.

## Isolate per lane

| Resource | Why |
|---|---|
| git worktree + branch | One working tree means agents corrupt each other's edits |
| No `git stash` | The stash is a repo ref, not a worktree one — one lane's pop restores another's files |
| Database | Test cleanup truncates; two lanes delete each other's rows mid-run |
| Ports | A leftover server makes the next lane test *the previous lane's code* and pass |
| Test-data prefix | So cleanup can tell whose rows are whose |
| File ownership list | Written before dispatch. A file outside it is a bounce, before reading code |

`lane.sh` does worktree + branch + database + env files in one command. Run it with no
arguments for usage. It runs **before** dispatch in both modes — a workflow's own
`isolation: 'worktree'` gives a git tree with no database and no ports, which is not a lane.

## Rules that were paid for

**REQUIRED:** read `references/failure-catalog.md` before writing lane prompts — it carries
the evidence behind each line here.

1. **Lanes may not edit tests asserting system-wide totals** (page counts, menu counts, module
   counts). Each lane sees only its own contribution, so every lane's number is wrong. Lanes
   report the delta; you set the number once, after the last merge.
2. **A shared-contract change is a foundation change.** Renaming one request field turned 43
   sibling tests red at merge — tests green on both branches minutes earlier.
3. **"Keep both sides" resolves data files, never code.** Concatenating a conflict inside a
   block silently drops its closing token. Type-check after *each* merge, not after the last.
4. **Lanes run only their own tests.** Five browser suites at once produce red runs with no bug
   behind them. You run the full gate, on an idle machine.
5. **Reports are leads, not evidence.** Require the command, the raw tail, the counts.
6. **Every lane gets a reviewer who did not write it, then a fix pass.** Across two rounds of
   five lanes, the reviewer found a must-fix defect in all ten — a cross-tenant data leak, a
   button that looked like it saved and did nothing.

## Integration

Merge one lane at a time. Lint and type-check after each — that catches a mangled conflict
while you still know which merge caused it. After the last, do what only you can (system-wide
totals, logic two lanes duplicated, document assembly), then run the whole gate idle.

**REQUIRED:** `references/integrator-checklist.md` · **for dispatch prompts:**
`references/lane-prompt-template.md` · **to run the lanes as one workflow:**
`references/workflow-mode.md`

## Red flags — stop

- "All five lanes are green, so the merge is fine" → nothing is proven yet
- "Merge them all and see what breaks" → you lose which lane broke it
- A lane asks to edit schema, menu, or a shared contract → that is yours; then all lanes rebase
- A lane's diff has a file outside its ownership list → bounce before reading code
- A lane reaches for `git stash` → separate worktrees share one stash stack
- One red run and you are about to call it flaky → re-run idle, and across seeds, first
- You are about to write a system-total number from inside a lane → stop
- A workflow phase is about to merge or push → integration is this session's, never a lane's
- "`isolation: 'worktree'` isolates the lanes" → no database, no ports, a fresh tree per stage

## Rationalizations

| Excuse | Reality |
|---|---|
| "Foundation first is slow" | Lanes on a moving base cannot be merged. You repay it at the seam |
| "Branches are enough" | Branches share one working tree |
| "One database is fine, tests clean up" | They clean up the other lane's fixtures too, mid-run |
| "The lane already ran the full gate" | On a loaded machine, or against a stale server |
| "This conflict is trivial, keep both sides" | That is how a closing brace disappears |
| "A reviewer will slow us down" | Ten of ten lanes had a defect the author could not see |
| "Let the workflow merge at the end, it has all five" | Batch merges lose which lane broke it, and nobody watched the gate |
| "The schema says the gate was green" | A boolean is a field, not a run. Require the command and the raw counts |

## Real-world impact

Six phases in one session — 96 agents, 240 commits, +116k lines, seven-stage gate green at the
end of every phase. Everything that broke, broke at a seam, and every one is in the catalog.
