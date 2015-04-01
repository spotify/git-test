#!/bin/sh -x

rev=$(git rev-parse --short HEAD)
cp test.sh tests_of_${rev}.sh
cp all_shells.sh all_shells_${rev}.sh
export GIT_TEST_VERIFY="./all_shells_${rev}.sh tests_of_${rev}.sh -v"
./git-test -v -o reports "$@"
