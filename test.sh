#!/bin/bash
#
# Copyright 2014-2015 Spotify AB. All rights reserved.
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#
export OPTIONS_SPEC="\
bash $0 [options]

Run tests

Example:
    sh $0 -v
--
 Available options are
v,verbose!      be more explicit about what is going on
q,quiet!        be quiet
x,exit!         exit after first test failure
s,shell=        shell to use [default: /bin/sh]
"

eval "$(
    echo "$OPTIONS_SPEC" \
	| git rev-parse --parseopt $parseopt_extra -- "$@" ||
    echo exit $?
)"

CR="$(printf "\r")"
NL='
'

verb=1
quit=0
last=""
pass=0
fail=0

shshell=${shshell:-/bin/bash}

total_argc=$#
while [ $# != 0 ]
do
    case $1 in
	-v|--verbose)
	    verb=2
	    ;;
	-q|--quiet)
	    verb=0
	    ;;
	-x|--exit)
	    quit=1
	    ;;
	-s|--shell)
	    shshell=$2
	    shift
	    ;;
	--shell=*)
	    shshell="${1#--shell=}"
	    ;;
	--)
	    shift
	    break
	    ;;
	*)
	    echo "\$1: $1"
	    echo "$OPTIONS_SPEC"
	    exit 0
	    ;;
    esac
    shift
done

PROJECT="${shshell} $(pwd)/git-test"
TMPDIR="${TMPDIR:=/tmp}"
SUBJECT="$TMPDIR/subject/"

rm -Rf "$SUBJECT"
mkdir -p "$SUBJECT"
cd "$SUBJECT"


dot() {
    if [ $verb -eq 1 ]; then
	if [ -n "$1" ]; then printf . ; else printf f ; fi
    elif [ $verb -eq 2 ]; then
	if [ -n "$1" ]; then echo "...pass" ; else echo "...fail"; fi
    fi

    if [ $quit -gt 0 ] && ! [ -n "$1" ]; then
	if [ $verb -lt 2 ]; then
	    printf "\n%s\n" "$last"
	fi
	exit 5
    fi
}

info() {
    last="$*"
    if [ $verb -ge 2 ]; then
	printf "%s\n" "$@"
    fi
}

fail() {
    fail=$(expr $fail + 1)
    dot
}

pass() {
    pass=$(expr $pass + 1)
    dot "t"
}

check() {
    if [ "$?" -eq 0 ]; then pass ; else fail ; fi
}

check_fail() {
    if [ "$?" -ne 0 ]; then pass ; else fail ; fi
}

is_empty() {
    if [ -f "$1" ] && ! [ -s "$1" ]; then pass ; else fail ; fi
}

add_commit() {
    echo "$1" > subject
    git add subject
    git commit -m "$2" subject
}

get_tree() {
    git rev-parse --short $(git cat-file -p $1 | grep tree | grep -o '[^ ]*$')
}

setup_for_redo() {
    rm -rf .git/test-cache/*
    touch .git/test-cache/${tree_a}_${ver}_pass
    touch .git/test-cache/${tree_b}_${ver}_pass # flappy!
    touch .git/test-cache/${tree_b}_${ver}_fail #
    touch .git/test-cache/${tree_c}_${ver}_fail
}

unset GIT_TEST_CLEAN
unset GIT_TEST_VERIFY

info "# Basic sanity tests"

info "Should be able to report version without repo"
$PROJECT --version                                   >out 2>err ; check
grep "^git-test version" out                    >/dev/null 2>&1 ; check

info "Empty repo should not pass tests"
git init -q                                     >/dev/null 2>&1
git config user.email "test.user@example.com"   >/dev/null 2>&1
git config user.name "User deTest"              >/dev/null 2>&1

$PROJECT                                             >out 2>err ; check_fail

info "( Create repo with initial subject file )"
add_commit 'contains the SUT.' "first file"          >out 2>err ; check

info "Check that a verification action is required"
$PROJECT HEAD                                        >out 2>err ; check_fail
grep "A verification action is required." out   >/dev/null 2>&1 ; check

printf pass > verify_result
verify="{ touch ran_test && [ \"\$(cat verify_result)\" = \"pass\" ]; }"
info "Configure verification in git config"
git config --local test.verify "$verify"

info "Clear results cache"
$PROJECT -v --clear                                  >out 2>err ; check
info "Clearing results doesn't output anything on stdout"
is_empty out
info "Clearing results doesn't output anything on stderr"
is_empty err

info "Pass test, because git-test uses the git config"
rm -f ran_test
$PROJECT -v master                                   >out 2>err ; check
grep "master will test *1 commit" out           >/dev/null 2>&1 ; check
grep "^0000 .* pass *$" out                     >/dev/null 2>&1 ; check

info "Pass test without checking, because the result is cached"
printf fail > verify_result
rm -f ran_test
$PROJECT -v --verify="$verify" master                >out 2>err ; check
grep "^0000 .* pass (cached)" out               >/dev/null 2>&1 ; check

info "Didn't run the verify action"
! test -f ran_test                                              ; check

info "Clear cache"
$PROJECT --clear

info "Fail test after clearing the cache"
rm -f ran_test
$PROJECT -v master                                   >out 2>err ; check_fail
grep "^0000 .* fail *$" out                     >/dev/null 2>&1 ; check

info "This time we ran the verify action"
test -f ran_test                                                ; check

add_commit "is the SUT" "Frob the subject file" >/dev/null 2>&1
$PROJECT --clear

git config --local test.verify "grep contains subject"
info "Fail on new commit, because code and tests are out of sync"
$PROJECT -v master                                   >out 2>err ; check_fail
grep "master will test *2 commits" out          >/dev/null 2>&1 ; check
grep "^0000 .* pass *$" out                     >/dev/null 2>&1 ; check
grep "^0001 .* fail *$" out                     >/dev/null 2>&1 ; check

info "No results came from cache"
! grep "(cached)" err                           >/dev/null 2>&1 ; check

info "Check that results are cached"
$PROJECT -v master                                   >out 2>err ; check_fail
grep "master will test *2 commits" out          >/dev/null 2>&1 ; check
grep "^0000 .* pass (cached)$" out              >/dev/null 2>&1 ; check
grep "^0001 .* fail (cached)$" out              >/dev/null 2>&1 ; check

info "# Feature: Redo modes"

# Preliminaries for redo tests
add_commit "some other thing" "another commit"  >/dev/null 2>&1
add_commit "MOOAAR SUT!" "<o> fuuu"             >/dev/null 2>&1
$PROJECT --clear                                >/dev/null 2>&1 ; check
verify="grep SUT subject"
verification="$(echo "$verify" | git hash-object --stdin)"
ver="$(git rev-parse --short $verification)"
git config test.verify "$verify"

tree_a=$(get_tree HEAD~3)
tree_b=$(get_tree HEAD~2)
tree_c=$(get_tree HEAD^)
tree_d=$(get_tree HEAD)

# ...

info "Check that --redo=all re-tests both pass and fail"
setup_for_redo
$PROJECT -v --redo=all master                        >out 2>err ; check_fail
grep "master will test *4 commits" out          >/dev/null 2>&1 ; check
grep "^0000 .* pass *$" out                     >/dev/null 2>&1 ; check
grep "^0002 .* fail *$" out                     >/dev/null 2>&1 ; check
grep -v "(cached)" out                          >/dev/null 2>&1 ; check

info "Check that --redo=pass re-tests pass and not fail"
setup_for_redo
$PROJECT -v --redo=pass master                       >out 2>err ; check_fail
grep "master will test *4 commits" out          >/dev/null 2>&1 ; check
grep "^0000 .* pass *$" out                     >/dev/null 2>&1 ; check
grep "^0001 .* pass (FLAPPY)$" out              >/dev/null 2>&1 ; check
grep "^0002 .* fail (cached)$" out              >/dev/null 2>&1 ; check
grep "^0003 .* pass *$" out                     >/dev/null 2>&1 ; check

info "Check that --redo=fail re-tests fail and not pass"
setup_for_redo
$PROJECT -v --redo=fail master                       >out 2>err ; check_fail
grep "master will test *4 commits" out          >/dev/null 2>&1 ; check
grep "^0000 .* pass (cached)$" out              >/dev/null 2>&1 ; check
grep "^0001 .* pass (FLAPPY)$" out              >/dev/null 2>&1 ; check
grep "^0002 .* fail$" out                       >/dev/null 2>&1 ; check
grep "^0003 .* pass *$" out                     >/dev/null 2>&1 ; check


info "Check that --redo=both re-tests only flappy tests"
setup_for_redo
$PROJECT -v --redo=both master                       >out 2>err ; check_fail
grep "master will test *4 commits" out          >/dev/null 2>&1 ; check
grep "^0000 .* pass (cached)$" out              >/dev/null 2>&1 ; check
grep "^0001 .* pass (FLAPPY)$" out              >/dev/null 2>&1 ; check
grep "^0002 .* fail (cached)$" out              >/dev/null 2>&1 ; check
grep "^0003 .* pass *$" out                     >/dev/null 2>&1 ; check

$PROJECT --clear
git branch long-history
git reset --hard HEAD~2                         >/dev/null 2>&1

info "# Feature: pre-action"
$PROJECT --clear

info "Check that pre- and post-actions are run"
export GIT_TEST_PRE="touch ran-pre"
export GIT_TEST_POST="touch ran-post"
export GIT_TEST_VERIFY="touch tested"
$PROJECT -v -ra master                               >out 2>err ; check
tr "$CR" "$NL" < err > err2 && mv err2 err
grep "master will test *2 commits" out          >/dev/null 2>&1 ; check
grep "^0000 .* pass" out                        >/dev/null 2>&1 ; check
grep "^0001 .* pass" out                        >/dev/null 2>&1 ; check
grep "pre-action" err                           >/dev/null 2>&1 ; check
grep "post-action" err                          >/dev/null 2>&1 ; check
test -f ran-pre                                                 ; check
test -f ran-post                                                ; check

info "Check that pre- and post-actions are permitted to fail"
export GIT_TEST_PRE="false"
export GIT_TEST_POST="false"
export GIT_TEST_VERIFY="true"
$PROJECT -v -ra master                               >out 2>err ; check
tr "$CR" "$NL" < err > err2 && mv err2 err
grep "master will test *2 commits" out          >/dev/null 2>&1 ; check
grep "^0000 .* pass" out                        >/dev/null 2>&1 ; check
grep "^0001 .* pass" out                        >/dev/null 2>&1 ; check
grep "pre-action" err                           >/dev/null 2>&1 ; check
grep "post-action" err                          >/dev/null 2>&1 ; check


info "# Priority of conflicting configurations"

unset GIT_TEST_PRE
unset GIT_TEST_POST
export GIT_TEST_VERIFY="echo 'environment' > winner"
git config test.verify "echo 'config' > winner"
verify_redir="echo 'argument' > winner"

info "Check that command-line argument is highest priority"
$PROJECT -v -ra --verify="$verify_redir" master      >out 2>err ; check
result=$(cat winner)
test "$result" = "argument"                                     ; check

info "Check that environment variable is second highest priority"
$PROJECT -v -ra master                               >out 2>err ; check
result=$(cat winner)
test "$result" = "environment"                                  ; check

info "Check that git config is third highest priority"
unset GIT_TEST_VERIFY
$PROJECT -v -ra master                               >out 2>err ; check
result=$(cat winner)
test "$result" = "config"                                       ; check

info "# Regressions"

info "Should refuse empty rev-list"
$PROJECT -v -ra master ^master                       >out 2>err ; check
is_empty out                                                    ; check
grep "List of commits to test is empty" err     >/dev/null 2>&1 ; check
grep "^iter commit" err out                     >/dev/null 2>&1 ; check_fail

info "Should fail with helpful message if lock dir is present"
mkdir -p .git/test-cache/testing
$PROJECT -v -ra master                               >out 2>err ; check_fail
grep "git-test already in progress" err         >/dev/null 2>&1 ; check
grep "(lock: .*.git/test-cache/testing)" err    >/dev/null 2>&1 ; check

info "Re-running git-test should not remove lock dir"
$PROJECT -v -ra master                               >out 2>err ; check_fail
grep "git-test already in progress" err         >/dev/null 2>&1 ; check
grep "(lock: .*.git/test-cache/testing)" err    >/dev/null 2>&1 ; check

info "Check that selective --clear removes correct cache entries"
git reset --hard long-history                        >out 2>err ; check
git config test.verify "$verify"
setup_for_redo
touch .git/test-cache/${tree_d}_${ver}_fail
ls .git/test-cache/*_*_* | wc -l | grep '^ *5 *$'    >/dev/null ; check
$PROJECT -v --clear  master~1 ^master~3              >out 2>err ; check
ls .git/test-cache/*_*_* | wc -l | grep '^ *2 *$'    >/dev/null ; check

info "Should present actual ref spec and commit count"
git branch upstream master~2                    >/dev/null 2>&1 ; check
git branch --set-upstream-to=upstream           >/dev/null 2>&1 ; check
$PROJECT -v --verify=true                            >out 2>err ; check
grep ".upstream.*will test *2 commits" out      >/dev/null 2>&1 ; check

info "Should show commit table header"
$PROJECT --clear                                >/dev/null 2>&1 ; check
$PROJECT -v --verify=true                            >out 2>err ; check
grep "^iter.*commit.*tree.*result$" out err     >/dev/null 2>&1 ; check

info "Should just show version, even when not in a repo"
GIT_DIR=.git/refs $PROJECT --version                 >out 2>err ; check
grep "Not a git repo" out err                   >/dev/null 2>&1 ; check_fail

info "Should not confuse files and branches"
$PROJECT --clear                                >/dev/null 2>&1 ; check
git checkout -b subject                         >/dev/null 2>&1 ; check
add_commit "x" "differentiate branches"         >/dev/null 2>&1 ; check
$PROJECT -v --verify=true subject ^master            >out 2>err ; check
grep "^iter.*commit.*tree.*result$" out err     >/dev/null 2>&1 ; check

info "Should refuse to run if work tree is dirty"
echo "y" > subject
$PROJECT -v -ra master                               >out 2>err ; check_fail
grep "Cannot test: You have unstaged changes." err   >/dev/null ; check
git checkout -- subject                         >/dev/null 2>&1 ; check

info "TODO: check output report feature/s"

if [ $verb -ge 1 ]; then
    echo
    echo "passed: $pass failed: $fail"
fi

if test "$fail" -eq 0 ; then exit 0 ; else exit 5 ; fi
