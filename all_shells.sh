#!/bin/sh

for sh in /bin/dash /bin/bash /bin/ksh /bin/mksh /bin/pdksh; do
    echo Using $sh
    $sh "$@" || exit $?
done
