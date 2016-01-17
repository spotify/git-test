# -*- mode: pkgbuild -*-
pkgname=git-test-git
pkgrel=1
pkgver=r48.2324a42
pkgdesc=Git extension to conveniently test all distinct versions
arch=(any)
url=https://github.com/spotify/git-test
depends=(git)
source=('git-test-git::git+ssh://git@github.com/spotify/git-test.git')
md5sums=(SKIP)

pkgver() {
  cd "$srcdir/$pkgname"
  ( set -o pipefail
    git describe --long --tags 2>/dev/null | sed 's/\([^-]*-g\)/r\1/;s/-/./g' ||
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
  )
}

package() {
  cd "$srcdir/$pkgname"
  install -Dm 0755 git-test   "$pkgdir/usr/bin/git-test"
  install -Dm 0644 git-test.1 "$pkgdir/usr/share/man/man1/git-test.1"
}
