# communitymodules-ioutils-exec-measurements

A measurement for a proposed change to
[tlaplus/CommunityModules](https://github.com/tlaplus/CommunityModules).

The change: make the `IOUtils` exec operators opt-in. Today they run on any
model check. The goal: a model check must not run OS commands unless the user
turns them on.

## The problem

CommunityModules ships a TLC override class, `tlc2.overrides.IOUtils`. TLC loads
it by default. Four operators run an OS command: `IOExec`, `IOEnvExec`,
`IOExecTemplate`, and `IOEnvExecTemplate`. Each one starts a process with
`ProcessBuilder`.

So a spec that `EXTENDS IOUtils` can run commands when TLC checks it. The
commands run on the machine of the user who runs the check.

It is also quiet. TLC prints no message that a command ran. The subprocess output
is captured into a record, not shown (`inheritIO` is commented out in the code).
So the user sees nothing from the tool — only what the spec itself prints. The
`ExecSilent` run proves this: it has no `PrintT`, the command still runs, and the
full TLC console has no line about a command.

The operators run only when the CommunityModules Java overrides are on TLC's
classpath. That is the normal setup: the `deps` jar, the VS Code extension
nightly, or the Toolbox library path. A plain `.tla` copy without the overrides
does not execute.

Source at commit `4c6c79bf6f3124dfa3a4fd3cfa9a92fe34c20763`:
<https://github.com/tlaplus/CommunityModules/blob/4c6c79bf6f3124dfa3a4fd3cfa9a92fe34c20763/modules/tlc2/overrides/IOUtils.java>.

## Affected versions

The facts come from git history and the release tags.

- `IOExec` first shipped in the release tagged `202002102301` (2020-02-10). An
  earlier tag the same day, `202002101658`, does not have it.
- It has shipped in every release since, up to the latest, `202610131629`
  (2026-10-13), which is the commit measured here (`4c6c79b`).
- 205 of the 206 date-stamped releases have it.

CommunityModules uses date-stamped releases, not semantic versions.

## What the gate does not break

The gate sits only in `runProcess`, the one method the four exec operators use.
Everything else keeps working by default:

- Other CommunityModules modules (CSV, GraphViz, SVG, Json, ...) do not call the
  exec operators. They are unaffected.
- The other `IOUtils` operators (serialize, deserialize, `IOEnv`, `atoi`) do not
  go through `runProcess`. They are unaffected.
- The project's own test suite stays green. `ant test` passes because the patch
  opts the tests in (see Results).

The one change: a spec that calls `IOExec` on purpose now needs the opt-in flag.
That is the goal, not a side effect.

## Run it

You need Docker. Nothing runs on the host.

```text
./run-docker.sh
```

The script starts a digest-pinned `eclipse-temurin:11-jdk-jammy`. It mounts this
repo and a CommunityModules clone, both read-only. The default clone is
`/home/data/oss/CommunityModules`. Override it with `CM=/path/to/CommunityModules`.

Inside the container it takes the committed tree at the pinned commit with
`git archive`, so no local edits can leak in. It builds with Ant. The build
downloads TLA+ tools v1.8.0. Then it runs the cases below, and runs the project's
own `ant test` on the patched build.

## The specifications

- `ExecFinding.tla` calls `IOExec` inside `PrintT` while TLC builds the first
  state. The command is benign. It writes `ioexec-ran.marker`.
- `ExecSilent.tla` calls `IOExec` with no `PrintT`. It shows the silence. Its only
  on-disk effect is the marker file `exec-silent.marker`.

If a marker appears, the command ran.

## Results

CommunityModules at commit `4c6c79b`. Full output in [`results/`](results/).

| Build | Case | TLC exit | Marker | Meaning |
|-------|------|----------|--------|---------|
| shipped | `ExecFinding` (PrintT) | 0 | present | the check ran the command |
| shipped | `ExecSilent` (no PrintT) | 0 | present | it ran, and the console shows no notice |
| patched | `ant test` | 0 | — | the fix keeps their test suite green |
| patched | default, no opt-in | 75 | absent | blocked; TLC prints the gate error |
| patched | opt-in (`-Dtlc2.overrides.IOUtils.enableExec=true`) | 0 | present | the user opted in, so it runs |

What this shows:

- The shipped build runs a command from a model check, with no option and no
  notice.
- The gate blocks it by default and names the switch in the error.
- The gate is a switch, not a removal. One JVM option turns it back on.
- The fix does not break the project's own tests.

## The patch

`ioutils-exec-gate.patch` changes three files:

- `modules/tlc2/overrides/IOUtils.java`: adds a check at the top of
  `runProcess(ProcessBuilder)`, the one method all four exec operators use. If the
  system property `tlc2.overrides.IOUtils.enableExec` is not `true`, it throws a
  TLC error (`EC.GENERAL`) before the process starts. The default is off.
- `build.xml`: passes the opt-in to the project's test run, so `ant test` still
  runs the exec tests.
- `tests/IOUtilsUnixTests.tla`: passes the opt-in to the nested child TLC that the
  tests launch.

## Read in the code, not tested here

- The one spawn point is `runProcess(final ProcessBuilder)` in
  `modules/tlc2/overrides/IOUtils.java`. No other override class starts a process.
- `tlc2.overrides.TLCOverrides` returns `IOUtils.class` on every path. So the
  override always loads.
- The exec operators set `warn = false`. That only hides the warning for an
  override a spec loads but does not use. It does not affect a spec that uses
  `IOExec`.

## Not measured, and why

- Windows and macOS. Linux containers only.
- Any command other than writing a marker. The test only needs to show that a
  command runs.
- The TLA+ Toolbox and the VS Code extension. The test runs TLC directly.

License: MIT.
