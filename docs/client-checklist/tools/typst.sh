#!/bin/sh
# Runs `typst compile` and hides the two warnings every build prints: HTML
# export is experimental, and the font lists in src/template.typ name fonts a
# given machine may not have (Typst falls through to the next one). Real
# warnings and errors still show, and the exit status is typst's own.
out=$(typst compile --diagnostic-format short "$@" 2>&1)
status=$?
printf '%s\n' "$out" | grep -Ev 'unknown font family|html export is under active development|^$' >&2
exit $status
