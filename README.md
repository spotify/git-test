# git-test -- test your commits

Run tests on each *distinct* tree in a revision list, skipping versions whose
contents have already been tested.

The 99% example is simply:

    git test -v

By default it uses heuristics to try to determine what "local commits" to
test, but you can supply another ref spec. `git-test` looks at each commit and
checks the hash of the directory tree against the cache. You can also configure
a ref (usually a branch) to test against, per repo or or per branch.

From the point of view of `git-test`, a test can be any shell command and a
test is considered successful if that shell command returns with a `0` exit
status. This means `git-test` can be used both for specialised tests of a
single feature or failure mode or for running a comprehensive set of automated
tests. The cache is keyed on both directory tree and test, so it won't confuse
the unit tests with the integration tests, or a specific regression test.

## Motivation

An important design goal for `git-test` has been to make it convenient to use.

Ideally, you should have a work flow where you run your unit tests whenever
you save and run unit tests on all your local commits whenever you've done
something with version control.

For ease, `git-test` offers a few advantages over a simple for loop over a
`git rev-list`:

- By default it spends some effort on working out which commits to test.
- Cached results, which are keyed to tree contents, rather than commit. This
  means that commits can be amended or reordered, but only content trees that
  have never been tested before will be tested.
- Separate pre- and post-action hooks, the results of which don't actually
  factor into the test result. (Useful if cleaning fails if there is nothing
  to clean, for instance.)
- Configuration of housekeeping and verification steps using
    - `git config`,
    - environment variables or
    - command line arguments
- Selective redo, for where you trust failures but not successes, vice versa,
  or trust nothing.
- Save output (both `STDOUT` and `STDERR`) from cleaning and verifying to
  an easily referenced symlink farm.


## Configure

Mostly just this:

    git config test.verify "test command that returns nonzero on fail"

to default to testing against origin/master:

    git config test.branch origin/master

to do the same, but for a single branch:

    git config branch.mybranch.test parentbranch


## Self-Test

To try the test script with different shells:

    for sh in /bin/dash /bin/bash /bin/ksh /bin/mksh /bin/pdksh; do
        echo $sh
        sh test.sh -s $sh
    done

Note that since version 1.0.2, the shebang is set to `/bin/bash`. Other shells
are now supported on a "patches welcome" basis. (This is largely because I
couldn't find a shell I could run in my GNU/Linux environment that behaves
like the OS X (FreeBSD?) `sh` shell, which has very different behaviour from
all the others.)

To regression test properly:

    rev=$(git rev-parse --short HEAD)
    cp test.sh regressions_${rev}.sh
    GIT_TEST_VERIFY="sh regressions_${rev}.sh" git test -v

(The reason for copying the script is to test each commit against the new
tests, and the reason for naming it based on the current commit is to key the
cache correctly.)


## Installation

You can just have the `git-test` script in your `PATH`, but there are other
options:

### Homebrew (on OS X)

If you have [Homebrew](http://brew.sh) installed, you can install
`git-test` with:

    $ brew install git-test

### From source

Aside from the packaging, you can also install from source. It's a single
POSIX shell script that uses core git, so all that's required for plain `git
test` to work (besides git, of course) is that `git-test` needs to be
somewhere in your `PATH` (or `GIT_EXEC_PATH`).

You can install from source by doing the following:

    $ install git-test   /usr/local/bin
    $ install git-test.1 /usr/local/share/man1

Or just add this directory to your `PATH` environment variable.

### Debian GNU/Linux

The usual

    $ fakeroot debian/rules binary

Should give you a Debian package.

### Arch Linux

With Arch Linux, you can use the provided `PKGBUILD` file. Simply download the
file and run `makepkg` in the same directory as the file. It will always build
the latest `git` version of this package, even if you have an old checkout.
