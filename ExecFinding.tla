-------------------------------- MODULE ExecFinding --------------------------------
\* Reproduces the finding "a model-checked spec runs OS commands via IOUtils".
\* Evaluating this spec makes TLC run a command chosen by the spec. The command
\* here is benign: it writes a marker file next to the run. The point is that
\* merely checking an untrusted spec that EXTENDS IOUtils executes its commands.
EXTENDS IOUtils, Integers, Sequences, TLC

VARIABLE x

\* IOExec returns a record [exitValue, stdout, stderr]; evaluating it spawns the
\* process. The marker file it writes is the observable side effect on disk.
Exec == IOExec(<<"/bin/sh", "-c", "echo ioexec-ran > ioexec-ran.marker">>)

Init == /\ PrintT(Exec)
        /\ x = 0

Next == x' = x
===================================================================================
