# Workflow mode

The same shape as hand-dispatching — foundation, lanes, integration — with the *lanes* run by
one `Workflow` script instead of one `Agent` call each. You get a phased progress tree with
per-agent tokens and time (`/workflows`), reports that arrive as JSON instead of prose, and a
resume that re-runs one dead lane without re-running the other four.

It changes **how the lanes are dispatched. It changes nothing about who proves the system.**

## What stays here, in this session

| In the workflow | In this session, serial, yours |
|---|---|
| build → review → fix, one pipeline per lane | The foundation, and its gate, before the script is written |
| Reporting deltas against frozen totals | `lane.sh up` for every lane — worktree, branch, database, ports |
| Contract-change *requests* | Every merge, one lane at a time, lint + type-check after each |
| | Every system-wide total, the assembled documents, the final gate on an idle machine |
| | `lane.sh down` |

A workflow whose last phase merges has thrown away the only thing that catches a mangled
conflict: knowing which merge caused it.

## Four ways a workflow quietly loses lane isolation

**1. `isolation: 'worktree'` is not lane isolation.** It gives the agent a git worktree and
nothing else — no database, no ports, no env files — so two lanes still truncate each other's
test rows and still answer on each other's servers. It is also a *fresh* tree per `agent()`
call, so the reviewer would not be looking at the builder's working tree. Run `lane.sh up`
first, pass the paths in through `args`, and tell each agent to `cd` there. Do not set
`isolation`.

**2. `parallel()` between the stages.** `parallel()` is a barrier: no lane starts its review
until the slowest lane finishes building. Nothing in build → review → fix needs another lane's
result, so use `pipeline()` — lane A can be in its fix pass while lane E is still building.

**3. `phase()` inside a stage callback.** `phase()` sets one global; called from inside a
pipeline stage it races with the other lanes and scatters agents into the wrong group. Set the
group per call: `agent(prompt, {phase: 'Review'})`. Use `phase()` only in the straight-line
body.

**4. A schema with booleans in it.** `gateGreen: true` is a field an agent can fill without
running anything — the same "reports are leads, not evidence" failure, now type-checked and
therefore more convincing. Every gate field is a **string that must contain the command and
the raw tail with counts**. Same for commits: the `git log` line, not "3 commits".

## Size

Lanes × 3 agents, plus anything you add. Five lanes is 15 — the ceiling under the session's
default size guideline (`/config` → Dynamic workflow size). More lanes than that: raise the
guideline deliberately or run two workflows back to back. Concurrency is capped at
`min(16, CPUs − 2)` regardless, so a sixth lane queues rather than starving the machine.

## The script

Fill the prompts from `lane-prompt-template.md` — the whole text, placeholders replaced. Do
not paraphrase it; the boundaries a lane cannot infer are exactly what gets dropped when you
summarize. Scripts are plain JS (no type annotations) with no filesystem access, and
`Date.now()` / `Math.random()` / `new Date()` throw — pass anything time-dependent in
through `args`.

```js
export const meta = {
  name: 'phase-lanes',
  description: 'Build, independently review, then fix — one pipeline per lane',
  phases: [
    { title: 'Build',  detail: 'one agent per lane, in the worktree lane.sh made' },
    { title: 'Review', detail: 'a reviewer who did not write the lane' },
    { title: 'Fix',    detail: 'apply the review, reject the findings that are wrong' },
  ],
}

// args.lanes: [{ name, path, branch, base, db, webPort, apiPort, prefix, spec, owns }]
// args.docs:  { rules, handoff, truth, frozen }   args.gate: { lint, typecheck, unit }
const { lanes, docs, gate } = args

const str = { type: 'string' }
const strs = { type: 'array', items: str }

const BUILD = {
  type: 'object',
  required: ['commits', 'gateOutput', 'unfinished', 'contractRequests', 'frozenDeltas'],
  properties: {
    commits: strs,                    // "<sha> <subject>" from git log
    gateOutput: str,                  // command + raw tail with counts, never "passed"
    unfinished: strs,
    contractRequests: strs,           // schema, shared type, menu, permission
    frozenDeltas: strs,               // "+1 nav heading", never an absolute number
  },
}

const REVIEW = {
  type: 'object',
  required: ['verdict', 'findings', 'gateOutput'],
  properties: {
    verdict: { type: 'string', enum: ['pass', 'must-fix'] },
    gateOutput: str,
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'file', 'what', 'evidence'],
        properties: {
          severity: { type: 'string', enum: ['must-fix', 'should-fix', 'nit'] },
          file: str, what: str, evidence: str,
        },
      },
    },
  },
}

const FIX = {
  type: 'object',
  required: ['fixed', 'rejected', 'commits', 'gateOutput'],
  properties: {
    fixed: strs,
    rejected: strs,                   // reviewer was wrong, with evidence
    commits: strs,
    gateOutput: str,
  },
}

const buildPrompt = (l) => `
You are one lane of a parallel build. Other lanes are working right now.

## Your workspace
${l.path} — branch ${l.branch}, database ${l.db}, ports ${l.webPort}/${l.apiPort},
test-data prefix ${l.prefix}. cd there before anything. Never edit a file outside it:
the main repo and the other worktrees belong to other lanes.

## Read first
1. ${docs.rules} in full   2. ${docs.handoff}   3. your spec: ${l.spec}
4. ${docs.truth} — open the real thing and verify; do not trust a description of it.

## You own these files
${l.owns.join('\n')}
Everything else is someone else's. A change outside the list — schema, shared type, menu
entry, permission — is a contractRequests entry, not an edit. The integrator makes it and
every lane rebases.

## Tests
${gate.lint} && ${gate.typecheck} && ${gate.unit}, then only the integration tests for your
own area, on your own ports. Do NOT run the full suite or the browser suite. Never pipe a
gate through a filter without pipefail.

## Frozen — do not edit
${docs.frozen}
You can only see your own contribution, so any total you compute is wrong. Report the delta.

## Rules
Test first, watch it fail. Never merge, never push, never touch another branch. If the spec
does not answer something, decide it against the source of truth and write down the reason —
nobody is watching. If the real files contradict the spec, believe the files and say so.
`

const reviewPrompt = (l, build) => `
You are the independent reviewer for lane ${l.name}. You did not write this code.
Workspace ${l.path}. See the work: git diff ${l.base}...HEAD
Spec ${l.spec} · source of truth ${docs.truth} · project rules ${docs.rules}

The builder's report — do not trust it, check it:
${JSON.stringify(build, null, 2)}

Check, in this order: every query scoped to the tenant and every permission enforced
server-side · numbers invented rather than declared uncomputable · spec items missing that the
builder did not declare · every button and link with a real destination · tests that stay green
through deliberate sabotage (break it, confirm red, restore) · the gate's real counts.

Each finding is three fragments, no sentences:
  file  -> "path:line"
  what  -> what breaks, and for whom
  proof -> the command, or the line of code, that shows it
No preamble, no summary, no restating the spec, no praise. Findings only.
"pass" only if nothing is must-fix. Do not pass out of politeness.
`

const fixPrompt = (l, review) => `
You are fixing lane ${l.name} against its review. Workspace ${l.path}.
${JSON.stringify(review, null, 2)}

Fix everything must-fix and should-fix. Do NOT follow criticism blindly — verify each finding
against the real files first; where the reviewer is wrong, say so with evidence instead of
changing working code. Then ${gate.lint} && ${gate.typecheck} && ${gate.unit} and commit.
Never merge, never push.
`

const results = await pipeline(
  lanes,
  (l) => agent(buildPrompt(l), { label: `build:${l.name}`, phase: 'Build', schema: BUILD }),

  (build, l) => agent(reviewPrompt(l, build), {
    label: `review:${l.name}`, phase: 'Review', schema: REVIEW,
  }).then((review) => ({ lane: l.name, build, review })),

  (r, l) => {
    if (r.review.verdict === 'pass' && !r.review.findings.length) {
      log(`${l.name}: reviewer found nothing — no fix pass`)
      return r
    }
    return agent(fixPrompt(l, r.review), {
      label: `fix:${l.name}`, phase: 'Fix', schema: FIX, effort: 'low',
    }).then((fix) => ({ ...r, fix }))
  },
)

const done = results.filter(Boolean)
const dead = lanes.filter((l, i) => !results[i]).map((l) => l.name)
log(`${done.length}/${lanes.length} lanes complete${dead.length ? ` · dead: ${dead.join(', ')}` : ''}`)

return {
  lanes: done,
  dead,                                             // a bounce, not a silence
  contractRequests: done.flatMap((r) => r.build.contractRequests),
  frozenDeltas: done.flatMap((r) => r.build.frozenDeltas),   // you set the totals, after the merges
  unfinished: done.flatMap((r) => r.build.unfinished),
}
```

## Token budget

Measured on one lane review, four agents, same diff (`TESTING.md`):

| | Where it goes | Lever |
|---|---|---|
| ~57k | the agent's whole context — tool schemas, the files it opens | stop five lanes each reading the same rules file |
| ~7k | output tokens | the finding contract above: −20%, with the same defects found |
| ~1.5k | the report itself | already the smallest part. Shrinking it further buys nothing |

So the report shape is free money but it is not the win. Three things that are:

**Distill the shared documents once.** `Read ${docs.rules} in full` × 5 lanes reads one file
five times. Read it once in the foundation and paste the constraints that apply to *that* lane
into its prompt. Lanes cannot infer boundaries, but they do not need the whole rulebook to
respect them.

**Spend on the reviewer, save on the fix pass.** The reviewer is the stage that pays: in the
run above, every reviewer ran mutation tests unprompted and found that three of four planted
breakages left the suite green — no gate could have told you that. The fix pass is mechanical,
applying a list someone else wrote: `effort: 'low'`.

**Let a clean review skip its fix agent.** One `if` in the last stage, one agent saved per
lane that came back clean.

Do not economize by cutting the reviewer, by handing lanes a summary of the spec instead of the
spec, or by dropping "break the code and confirm it goes red". Those are the checks that
justify the whole run.

## When it comes back

A lane in `dead` returned `null` — the agent died after retries or was skipped. That is a
bounce like any other: it has no branch you can merge, and an empty `lanes` array reads as
"nothing found" if you do not check. Before believing any empty or surprising result, read
`journal.jsonl` in the run's transcript directory — it holds what each agent actually
returned.

Then work the integrator checklist: verify each branch contains the work, diff against the
ownership list, merge one lane at a time. `contractRequests` is yours to make and every
surviving lane rebases; `frozenDeltas` are the numbers you set once, after the last merge.

**Resume instead of re-running.** `Workflow({ scriptPath, resumeFromRunId })` replays the
longest unchanged prefix of `agent()` calls from cache and runs live from the first changed
one. Fix one lane's prompt and only that lane re-runs. Same session only, and stop the prior
run first.

## Hybrid: scout, then fan out

When the lane list is not known yet, run a recon workflow first — several agents each sweeping
a different way, returning the work list — then write the lane workflow from what it found.
Inside a script that is `workflow(nameOrScriptPath, args)`, one level deep only; it shares
this run's concurrency cap and shows up as its own group in the tree. From the main session it
is simply two `Workflow` calls, and you read the first before deciding the second.
