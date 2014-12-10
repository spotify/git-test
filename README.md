# git-test -- test your commits

Run tests on each *distinct* tree in a revision list, skipping versions whose
contents have already been tested.

The 99% example is simply:

    git test -v

By default it uses heuristics to try to determine what "local commits" to
test, but you can supply another ref spec. `git-test` looks at each commit and
checks the hash of the directory tree against the cache.

From the point of view of git-test, a test can be any shell command and a test
is considered successful if that shell command returns with a zero exit
status. This means git-test can be used both for specialised tests of a single
feature or failure mode or for running a comprehensive set of automated tests.
The cache is keyed on both directory tree and test, so it won't confuse the
unit tests with the integration tests, or a specific regression test.

## Motivation

An important design goal for git-test has been to make it convenient to use.

Ideally, you should have a work flow where you run your unit tests whenever
you save and run unit tests on all your local commits whenever you've done
something with version control.

For ease, git-test offers a few advantages over a simple for loop over a "git
rev-list":

- By default it spends some effort on working out which commits to test.
- Caching of results, keyed on tree contents, rather than commit. This means
  that commits can be amended or reordered, but only content trees that have
  never been tested before will be tested.
- Separate pre and post actions, the results of which don't actually factor
  into the test result. (Useful if cleaning fails if there is nothing to
  clean, for instance.)
- Configuration of housekeeping and verification steps using
    - git config,
    - environment variables or
    - command line arguments
- Selective redo, where you trust failures but not successes, vice versa, or
  trust nothing.
- Save output, both stdout and stderr from cleaning and verifying to
  an easily referenced symlink farm.


## Self-Test

To try the test script with different shells:

    for sh in /bin/dash /bin/bash /bin/ksh /bin/mksh /bin/pdksh; do
        echo $sh
        sh test.sh -s $sh
    done

To regression test properly:

    rev=$(git rev-parse --short HEAD)
	cp test.sh regressions_${rev}.sh
	GIT_TEST_VERIFY="sh regressions_${rev}.sh" git test -v

(The reason for copying the script is to test each commit against the new
tests, and the reason for naming it based on the current commit is to key the
cache correctly.)


## Installation

Aside from the [Debian](https://www.debian.org) packaging, you can also
install from source. It's a single POSIX shell script that uses core git. All
that's required for plain `git test` to work, besides git, of course, is that
git-test needs to be somewhere in the PATH (or GIT_EXEC_PATH).

You can install from source by doing the following:

    $ install -b git-test /usr/local/bin
    $ install git-test.1 /usr/local/share/man1
