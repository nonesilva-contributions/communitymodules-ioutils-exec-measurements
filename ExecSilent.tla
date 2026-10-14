-------------------------------- MODULE ExecSilent --------------------------------
\* Forces IOExec during initial-state generation without PrintT. Running this on
\* the shipped build shows TLC prints no notice when the spec runs a command.
EXTENDS IOUtils, Integers

VARIABLE x

Exec == IOExec(<<"/bin/sh", "-c", "echo exec-silent-ran > exec-silent.marker">>)

Init == x = Exec.exitValue
Next == x' = x
===================================================================================
