# How this was tested

Skills are documentation, and untested documentation is untested code. This is what was
actually run, including the part that did not work.

## The method

One planning task, given four times to fresh agents: *"orchestrate five agents in parallel to
build five modules in this monorepo; answer where they work, what they may run, how you merge,
how you know their work is real, and what will go wrong."* Three runs had no skill; one had it.

Nine checks, each drawn from a failure that actually happened — not from a wish list:

| | Check |
|---|---|
| A | Lanes isolated by git worktree, not just branches |
| B | A database per lane |
| C | Lanes forbidden from running the full or browser suite; integrator runs it |
| D | An independent reviewer who did not write the code |
| E | Integrator re-runs the whole gate at merge instead of trusting lane reports |
| F | An explicit plan for files every lane must touch |
| G1 | Tests asserting system-wide totals are frozen; the integrator sets the number |
| G2 | A shared-contract change is treated as breaking sibling branches |
| G3 | "Keep both sides" is confined to data files, never code |

## Result

| Run | A | B | C | D | E | F | G1 | G2 | G3 | Total |
|---|---|---|---|---|---|---|---|---|---|---|
| no skill 1 | ✓ | ✗ | ✓ | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ | 5/9 |
| no skill 2 | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | 4/9 |
| no skill 3 | ✓ | ✗ | ✓ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | 5/9 |
| **with skill** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **9/9** |

**B, G2 and G3 were missed by every run without the skill.** Those three are the core of what
it teaches, and each maps to a failure in the catalog: lanes deleting each other's test rows,
43 sibling tests turning red at merge from a renamed field, and a closing token vanishing
during conflict resolution.

## What did not work, and why it is here

The first attempt at a baseline was thrown away. Those agents had filesystem access and found
the host project's own engineering notes, which already contained these lessons — so they
scored well by quoting them back. That measures whether written knowledge transfers, not
whether an agent arrives with it. The baseline was re-run with tools disabled.

Even the second baseline is not perfectly clean: agents on that machine inherit the project's
memory files, which carry some of the same lessons. So these numbers understate the gap a
fresh project would see, and the honest reading is narrow — on a codebase that has already
written its lessons down, agents recover much of this unaided. What the skill adds is
portability, a tool that runs, and an ordering to follow rather than notes to reconstruct.

## Provenance

The rules were not invented and then tested. They are the residue of six phases run in one
session — 96 agents, 240 commits, roughly 116k lines, a seven-stage gate green at the end of
every phase. Everything in `references/failure-catalog.md` broke during that run, and the
guidance is what stopped it breaking again.
