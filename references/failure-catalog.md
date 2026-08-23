# Failure catalog

Every entry happened. Each is written as: what you see → what it actually is → what to do.
Nothing here is hypothetical; the guidance in `SKILL.md` is a one-line summary of these.

---

## 1. Four lanes, four different numbers, all wrong

**Seen:** a test asserting the number of navigation headings was edited by four lanes in the
same round — to 4, 5, 5 and 6. Merged, the true answer was 6.

**Actually:** the heading renders only once at least one of its children is real. Each lane
had made exactly one child real, so each lane's local answer was correct *for its branch* and
wrong for the system. No lane could have been right.

**Do:** keep a frozen list of system-total assertions — counts of pages, menu entries,
registered modules, seeded rows, translated keys. Lanes must not edit them. A lane that makes
one go red reports the delta ("+1 heading from this lane") and moves on. The integrator sets
the number once, after the last merge.

**Related:** the same round had a test asserting *placeholder* nav entries still existed.
Once every module landed there were none left, and the assertion had inverted into "there must
always be unfinished work." When a system-total test goes red because the work finished, flip
the assertion; do not restore the placeholder.

---

## 2. Green on both branches, red on the merge

**Seen:** lane B renamed the login payload field from `email` to `identifier` so the endpoint
could accept either. Lane D, branched earlier, wrote 43 new tests that still sent `email`.
Both lanes were green. The merge was red in 43 places. It happened twice in one session.

**Actually:** a shared contract changed in one lane while another lane was writing new callers
of the old one. Nothing either lane runs can see this.

**Do:** treat any change to a shared contract — a request payload, an exported type, an enum,
a permission name — as a foundation change. Announce it. Better: land it in the foundation
before fan-out. At integration, always run the full suite yourself; per-lane green is not
evidence about the merge.

---

## 3. "Keep both sides" ate a closing token

**Seen:** two files resolved by concatenating both sides of the conflict. One lost the `];`
that closed an array; the other lost the `});` closing a test block *and* the one closing its
enclosing group. The type-checker caught both — which was luck, not design.

**Actually:** conflict regions do not respect syntax. When a hunk starts inside a block and
the other side starts a new one, concatenation drops the terminator between them.

**Do:** "keep both sides" is for data files — translation dictionaries, changelogs, ledgers.
For code, resolve deliberately, then run type-check **after each merge**, not after the last.
For structured data that must merge by key rather than by line (translation dictionaries),
do a three-way merge on the parsed structure and report keys both sides changed instead of
guessing.

---

## 4. A red run with no bug behind it

**Seen:** the browser suite failed 13 tests while five lanes were building. Re-run on an idle
machine: all green, nothing changed. Earlier the same day, integration tests failed only the
two slowest suites — they exceeded a fixed 30-second timeout under CPU contention while
passing in 253 ms when run alone.

**Actually:** a fixed per-test timeout turns machine load into test failure. Five agents
building, testing and compiling at once will exceed it.

**Do:** lanes run only their own tests. The full gate belongs to the integrator, on an idle
machine. A single red run is not a flake diagnosis — re-run once idle. If it still fails, or
fails across different random seeds, it is real.

---

## 5. A test that assumed it was alone

**Seen:** an ordering test created three rows and asserted the whole registry equalled exactly
those three. Another test in the same file left a fourth row behind. The suite randomizes
order, so it failed only sometimes.

**Actually:** the test asserted on a shared registry rather than on the rows it created.

**Do:** every test starts from state it created. Assert on your own rows, not on the whole
table. Verify by running the file under three different seeds before you believe it.

---

## 6. Cleanup that killed the run before it started

**Seen:** the test-data reset deleted bank accounts before deleting the expenses referencing
them. The foreign key is restrict, so the delete failed, so the browser suite's global setup
threw — the whole suite died before the first test.

**Actually:** the new module added a restrict-level reference to an existing table, and the
cleanup order was never updated. It only surfaced once a screen existed that created that
data — long after the schema landed.

**Do:** whenever the foundation adds a table with a restrictive reference, add its cleanup in
the same commit, in dependency order. Have the foundation reviewer walk the list. Then prove
it by running the reset against a database that already has data in it.

---

## 7. A gate that proved nothing

**Seen:** the task runner cached test results. `run test` answered "successful" in 16
milliseconds without executing anything, replaying an old log. Every "full suite green" claim
in the project's history was weaker than it read — and any run that passed by luck was cached
as passing forever.

**Actually:** test tasks are not pure functions of the source; caching them caches luck.

**Do:** disable result caching for test tasks. Lint and type-check may stay cached — those
*are* functions of the files. When you report numbers, report the ones you watched run.

---

## 8. The port that tested last week's code

**Seen:** the browser runner was configured to reuse an already-listening server. A server
left over from an earlier run answered, so the suite exercised the previous build and passed.
Separately, a smoke script killed the wrong process — it captured the wrapper shell's id, not
the server's — so the server survived and held the port, and the script's own shutdown check
had never once tested a real shutdown.

**Do:** never reuse an existing server for a run whose result you will report. Check the port
is free before starting and after finishing. Give each lane its own ports. When something must
be killed, verify it died.

---

## 9. Two lanes, one number, one namespace

**Seen:** two lanes opened a numbered debt entry in a shared register using the same number
for different items. Separately, two lanes each extracted the same seed data into two
different modules — leaving two copies that would drift the day someone edited one.

**Do:** lanes refer to shared registers by text, not by number; the integrator assigns numbers
at merge. When two lanes extract the same thing, one home wins and the other re-exports from
it — decided at integration, never left as two copies.

---

## 10. What the independent reviewer caught

Two rounds, five lanes each. A must-fix defect in all ten, none of which any gate could see:

- a query joined on name without scoping to the tenant, so an export could carry another
  company's tax IDs
- a confirm button that closed its dialog and issued no request — the user believed it saved
- a "sign out everywhere" action that skipped the current device
- a navigation badge linking to a filter the target page did not accept, two of nine wrong
- a cleanup routine missing six tables

**Do:** every lane gets a reviewer who did not write the code, then a fix pass. Instruct the
fixer explicitly: verify each finding against the real files first, and report — do not
"fix" — the ones where the reviewer was wrong.
