# communitymodules-ioutils-exec-measurements

Measurements behind a proposed change to
[tlaplus/CommunityModules](https://github.com/tlaplus/CommunityModules): make the
`IOUtils` exec operators opt-in, so that model-checking a specification does not
run OS commands unless the person running the check explicitly allows it.

`modules/tlc2/overrides/IOUtils.java` registers a TLC override
(`tlc2.overrides.TLCOverrides`) that TLC loads by default. Its operators
`IOExec`, `IOEnvExec`, `IOExecTemplate` and `IOEnvExecTemplate` start an OS
command through a `ProcessBuilder`, and their `@TLAPlusOperator` annotations
carry `warn = false`, so no warning is printed. A specification that
`EXTENDS IOUtils` therefore runs commands of its own choosing while TLC checks
it, on the machine of whoever runs the check. Source at commit
`4c6c79bf6f3124dfa3a4fd3cfa9a92fe34c20763`:
<https://github.com/tlaplus/CommunityModules/blob/4c6c79bf6f3124dfa3a4fd3cfa9a92fe34c20763/modules/tlc2/overrides/IOUtils.java>.

This repository holds a benign specification that exercises one exec operator, a
patch that adds an opt-in gate at the single point where a process is started,
and a runner that builds CommunityModules in Docker both as shipped and with the
patch, and model-checks the specification in each case. Same class as
[vscode-tlaplus-mcp-bind-measurements](https://github.com/nonesilva-contributions/vscode-tlaplus-mcp-bind-measurements).

## Affected versions

Measured in the git history of this module. `IOExec` was added on 2020-02-10
(commit `9fb2baf`), so model-checking a spec that `EXTENDS IOUtils` has started
OS commands since then; the `warn = false` that silences the override-loaded
warning was added on 2020-03-04 (commit `59479c7`). The behaviour is unchanged at
the measured HEAD, commit `4c6c79bf6f3124dfa3a4fd3cfa9a92fe34c20763`.
CommunityModules publishes rolling, date-stamped releases with no semantic
version; every release from 2020-02-10 through the latest at the time of writing
(`202610131629`, 2026-10-13) carries the exec operators, so all current releases
are affected.

## Run it

Requirements: Docker. Nothing runs on the host.

```text
./run-docker.sh
```

It starts `eclipse-temurin:11-jdk-jammy`, mounts this repository and a
CommunityModules clone read-only (default `/home/data/oss/CommunityModules`,
override with `CM=/path/to/CommunityModules`), copies the source into the
container, checks it is at the pinned commit, and builds it with Apache Ant
(`ant dist`, which fetches TLA+ tools v1.8.0). It then runs `tlc2.TLC` on
`ExecFinding.tla` three times: the shipped build, the patched build with no
option, and the patched build with the opt-in option. The spec's only effect is
to write a marker file; the runner reports whether that file appeared.

## The specification

`ExecFinding.tla` evaluates
`IOExec(<<"/bin/sh", "-c", "echo ... > ioexec-ran.marker">>)` while computing the
initial state. The command is benign: it writes a marker file next to the run.
The marker's presence is the observable sign that model-checking the spec
executed the command.

## Cases and results

CommunityModules at commit `4c6c79bf6f3124dfa3a4fd3cfa9a92fe34c20763`. Output in
[`results/`](results/).

| # | Build | TLC exit | Marker | Meaning |
|---|-------|----------|--------|---------|
| 1 | shipped (no gate) | 0 | present | checking the spec ran the command |
| 2 | patched, default | 75 | absent | the command is blocked; TLC reports the gate error |
| 3 | patched, opt-in (`-Dtlc2.overrides.IOUtils.enableExec=true`) | 0 | present | explicit opt-in still runs it |

What the rows establish:

- Row 1: a specification that `EXTENDS IOUtils` runs an OS command merely by being
  model-checked, with no option asked for and no warning.
- Row 2: with the gate, the default build refuses to start the process and TLC
  reports the error; the command does not run.
- Row 3: the gate is a switch, not a removal. Someone who wants the exec
  operators enables them with one JVM option, so existing specifications keep
  working. Every observation in row 1 flips in row 2 and returns in row 3, so the
  measurement separates the defect from its fix.

## The patch

`ioutils-exec-gate.patch` adds, at the top of the single `runProcess(ProcessBuilder)`
method that all four exec operators route through, a check of the system property
`tlc2.overrides.IOUtils.enableExec`. When it is not `true`, the method throws a
TLC evaluation error (`EC.GENERAL`) before the process is started. The default is
off. Nothing else changes.

## Read in the code, not reproduced here

- The single process-spawn point is `runProcess(final ProcessBuilder)` in
  `modules/tlc2/overrides/IOUtils.java`; `IOExec`, `IOEnvExec`, `IOExecTemplate`
  and `IOEnvExecTemplate` all reach it.
- `tlc2.overrides.TLCOverrides` returns `IOUtils.class` on every path, so the
  override loads by default.
- The four exec operators' `@TLAPlusOperator` annotations carry `warn = false`,
  so TLC prints no override-loaded warning for them.

## Not measured, and why

- Windows and macOS. Linux containers only.
- Any command other than writing a marker file. The measurement only needs to
  show that a command runs, not what a command can do.
- The patched behaviour inside the TLA+ Toolbox or the VS Code extension; the
  measurement runs TLC directly.

License: MIT.
