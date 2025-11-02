###### Bash

# Packaging & Distribution: Install Layouts, Man Pages, Completions, Debian/RPM/Brew Notes

Ship scripts like real software. Predictable install paths, versioning, man pages, shell completions, and lightweight OS packaging.

## TL;DR

* Use an **FHS** layout: `/usr/local/bin`, `/usr/local/share/doc`, `/etc` for configs.
* Provide **`--version`** and changelog; tag releases (semver).
* Generate **man pages** from `--help` (e.g., `help2man`).
* Ship **bash-completion** and **zsh** completion stubs.
* Offer one or more: **Deb**, **RPM**, or **Homebrew** tap for easy installs.

---

## Install layout

```
/usr/local/bin/myapp
/usr/local/lib/myapp/*.sh        (sourced libs)
/usr/local/share/myapp/*.tmpl    (templates)
/usr/local/share/doc/myapp/*     (README, LICENSE)
/etc/myapp/config.ini            (defaults; package should not overwrite on upgrade)
/usr/share/bash-completion/completions/myapp
/usr/share/zsh/site-functions/_myapp
```

---

## Makefile (install/uninstall + VERSION)

```make
PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin
LIBDIR := $(PREFIX)/lib/myapp
SHARE  := $(PREFIX)/share/myapp
DOCDIR := $(PREFIX)/share/doc/myapp
COMPD  := /usr/share/bash-completion/completions
ZSHD   := /usr/share/zsh/site-functions
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo 0.0.0)

install:
\tinstall -d $(BINDIR) $(LIBDIR) $(SHARE) $(DOCDIR) $(COMPD) $(ZSHD)
\tinstall -m 0755 bin/myapp $(BINDIR)/myapp
\tinstall -m 0644 lib/*.sh $(LIBDIR)/
\tinstall -m 0644 share/* $(SHARE)/
\tinstall -m 0644 docs/* $(DOCDIR)/
\tinstall -m 0644 completions/myapp.bash $(COMPD)/myapp
\tinstall -m 0644 completions/_myapp $(ZSHD)/_myapp

uninstall:
\trm -f $(BINDIR)/myapp
\trm -rf $(LIBDIR) $(SHARE) $(DOCDIR)
\trm -f $(COMPD)/myapp $(ZSHD)/_myapp

print-version:
\t@echo $(VERSION)
```

Ensure `myapp --version` echos the same value, ideally injected at build time (`VERSION` env var or sourced file).

---

## Man page generation with `help2man`

```bash
# Generate from --help and --version output
help2man -N -n "My Bash app for X" -o docs/myapp.1 ./bin/myapp
# Install to:
#   /usr/local/share/man/man1/myapp.1
```

**Tip:** Add a `docs/man.mk` target and publish man pages in releases.

---

## Bash & Zsh completion

```bash
# completions/myapp.bash
_myapp_complete() {
  local cur prev
  COMPREPLY=()
  _init_completion || return
  case "${COMP_WORDS[1]}" in
    scan) COMPREPLY=( $(compgen -f -- "$cur") ) ;;
    render) COMPREPLY=( $(compgen -f -- "$cur") ) ;;
    *) COMPREPLY=( $(compgen -W "scan render --help --version --format --config" -- "$cur") ) ;;
  esac
}
complete -F _myapp_complete myapp
```

```zsh
# completions/_myapp
#compdef myapp
_arguments \
  '1:subcommand:(scan render)' \
  '--help[show help]' \
  '--version[print version]' \
  '--format[output format]:format:(text json)' \
  '--config[config file]:file:_files'
```

---

## Debian packaging (minimal)

```bash
# debian/control
Source: myapp
Section: utils
Priority: optional
Maintainer: You <you@example.net>
Standards-Version: 4.6.2
Package: myapp
Architecture: all
Depends: bash (>=5), jq, coreutils
Description: My Bash app that does X

# debian/rules (dh)
#!/usr/bin/make -f
%:
\tdh $@

override_dh_auto_install:
\t$(MAKE) PREFIX=$(CURDIR)/debian/myapp/usr install
```

Build:

```bash
debmake -y -p myapp -u 0.4.0
dpkg-buildpackage -us -uc
```

---

## RPM packaging (sketch)

```spec
# myapp.spec
Name: myapp
Version: 0.4.0
Release: 1%{?dist}
Summary: My Bash app
License: MIT
BuildArch: noarch
Requires: bash >= 5, jq

%install
make PREFIX=%{buildroot}%{_prefix} install

%files
%{_bindir}/myapp
%{_libdir}/myapp/*
%{_datadir}/myapp/*
%doc %{_datadir}/doc/myapp/*
```

---

## Homebrew tap (macOS)

```ruby
# brew tap yourname/myapp; brew install yourname/myapp/myapp
class Myapp < Formula
  desc "My Bash app"
  homepage "https://github.com/you/myapp"
  url "https://github.com/you/myapp/archive/refs/tags/v0.4.0.tar.gz"
  sha256 "…"
  license "MIT"

  depends_on "bash"
  depends_on "jq"

  def install
    system "make", "PREFIX=#{prefix}", "install"
    man1.install "docs/myapp.1" if File.exist? "docs/myapp.1"
  end

  test do
    assert_match "Usage", shell_output("#{bin}/myapp --help")
  end
end
```

---

## Release checklist (practical)

* Update `CHANGELOG.md` and `VERSION`.
* Tag: `git tag -a v0.4.0 -m "Release v0.4.0"` → `git push --tags`.
* Build artifacts: `.deb`, `.rpm`, `.tar.gz`, `man` page.
* Attach to GitHub Release; publish checksums (`sha256sum` manifest).
* Verify install/uninstall paths on a clean VM/container.

---

## Smoke install (CI job)

```yaml
- name: Smoke install
  run: |
    sudo make install
    myapp --version
    myapp --help | head -n 5
    sudo make uninstall
```

---

## Licensing & provenance

Include `LICENSE` (MIT/Apache-2.0), `COPYRIGHT`, and embed a `--version` “build info” line (`git describe`, build date, platform).

---

```yaml
---
id: templates/bash/160-packaging-distribution.sh.md
lang: bash
platform: posix
scope: distribution
since: "v0.4"
tested_on: "bash 5.2, Debian 12, Fedora 40, macOS 14"
tags: [bash, packaging, fhs, man, completions, deb, rpm, homebrew, makefile]
description: "Production shipping: FHS install layout, Makefile targets, help2man pages, shell completions, and minimal Deb/RPM/Brew packaging with CI smoke installs."
---
```
