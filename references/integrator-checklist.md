# Integrator checklist

You are the only one who merges, and the only one who can prove the system.
Lanes never merge, never push, never touch another lane's branch.

## Before fan-out — the foundation is done when

- [ ] Every shared thing has landed in one serial commit set: data schema and its migration,
      shared types and contracts, permissions, menu entries, error codes, translation
      namespaces, seed data, **test-data cleanup for every new table, in dependency order**
- [ ] The full gate is green on the foundation. Lanes branch from that commit, not from before it
- [ ] Each lane has, written down before dispatch: its file ownership list, its ports,
      its database, its test-data prefix, and its slice of any shared numbering
- [ ] The frozen list exists: which tests assert system-wide totals, and therefore no lane
      may edit them
- [ ] Test result caching is off for test tasks (lint and type-check may stay cached)

## Accepting a lane's work

- [ ] Its branch actually contains the work — a clean status and the commits, not a report
- [ ] `git diff --name-only <base>...<lane>` contains no file outside its ownership list.
      A stray file is a bounce *before* anyone reads the code
- [ ] The gate output is quoted with commands and counts, not summarized as "green"
- [ ] The reviewer's findings and what the fix pass did with each — including any the fixer
      rejected, with evidence
- [ ] What it did **not** finish, in full. A lane that reports only its wins has not reported

## Per merge — every single one, no batching

- [ ] Merge one lane. Never merge several at once; you lose which one broke it
- [ ] Resolve conflicts by file kind:
      **data** (translations, changelogs, registers) → merge by key/entry, keep both sides;
      **code** → resolve deliberately, never by concatenation
- [ ] For key-value data files, merge the parsed structure three ways and report keys that
      both sides changed instead of picking one silently
- [ ] Registers and ledgers: merge row by row, newest wins per row. Concatenating gives you
      duplicate rows where the stale copy can win
- [ ] **Run lint and type-check now.** This is what catches a mangled conflict while you still
      know which merge caused it
- [ ] Run the unit tests of the packages that lane touched
- [ ] Note anything it asked you to decide — shared numbering, duplicated logic, a system total

## After the last merge — work only you can do

- [ ] Set every system-wide total once, from the merged truth
- [ ] Find logic two lanes implemented separately; one home wins, the other calls it
- [ ] Assemble the shared documents; fix heading levels and ordering so one voice reads through
- [ ] Recompute any summary counts in shared registers from the files themselves — lanes
      updated their own rows and nobody recomputed the totals
- [ ] Cleanup: remove worktrees, lane branches, and per-lane databases

## The final gate

- [ ] Machine is idle. No lane servers, no builds, no other agents
- [ ] Every stage, in order, exit codes checked — do not pipe through a filter without
      enabling pipefail, or a failing run reports success
- [ ] Integration tests: run more than once. Randomized order across seeds is what exposes a
      test that depends on another test's leftovers
- [ ] One red run is not a flake diagnosis. Re-run idle; if it still fails, or fails on other
      seeds, it is real — find it
- [ ] Report the numbers you watched run, per package, against the previous phase's numbers.
      Any count that went *down* means something was lost in a merge

## Reporting

- [ ] What was found, what was decided on the owner's behalf and why, what was done
- [ ] Everything still open — in full, not a selection
- [ ] What needs the owner: anything irreversible or outward-facing. Merging to a shared
      branch and pushing are theirs to authorize unless they said otherwise
