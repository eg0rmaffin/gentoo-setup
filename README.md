# gentoo-setup

Declarative Gentoo setup. Package manifest + dotfiles.

    ./install.sh

Idempotent: links the manifest into /etc/portage/sets,
installs missing packages, links configs. Safe to re-run
after any repo change (including moving the repo —
symlinks are re-pointed automatically).

## Packages

`desktop` — declarative package manifest (Portage set).
`package.use/` — declared USE flags, linked into /etc/portage/package.use.
`package.accept_keywords/` — declared keywords, linked into
/etc/portage/package.accept_keywords.

### Search

By name (fast, local tree):

    emerge --search tmux

By description (slower, when the name is unknown):

    emerge --searchdesc "terminal multiplexer"

Look for the atom in the output: `app-misc/tmux` —
category/name. The category is mandatory in the manifest
(package names are only unique within a category).

### Add a package

1. find the atom: `emerge --search <name>`
2. add the `category/name` line to `desktop`
3. `./install.sh`

Never install directly via `emerge <pkg>` — the atom
lands in world bypassing the repo and the declaration
drifts from the system.

### Try without declaring

    sudo emerge --oneshot -av <pkg>

Not recorded anywhere, removed by the next depclean.

### Remove

Delete the line from `desktop`, then:

    ./install.sh
    sudo emerge --ask --depclean

depclean removes the package and its orphaned deps.

## USE flags

`package.use/<name>` — one file per intent, linked to
/etc/portage/package.use/<name> by install.sh.

A flag belongs here when it states what the setup *is* on any
machine ("DOOM runs X-free via KMS/DRM"). It stays on the
machine when it describes the hardware — VIDEO_CARDS, CPU_FLAGS,
make.conf never enter the repo.

Verify flag names against the current ebuild before declaring:

    equery uses media-libs/libsdl2

## Keywords

`package.accept_keywords/<name>` — same shape as package.use:
one file per intent, linked by install.sh.

Write bare atoms, without `~amd64`. An entry with no keyword
accepts the unstable branch of whatever arch the machine runs,
which keeps the file machine-agnostic.

## Assets

`assets` — content Portage cannot ship (WADs, mods). Packages
come from Portage only; its Manifest already verifies those.

    sha256 | dest relative to $HOME | mirror URLs, primary first

`assets.sh` fetches it, and install.sh calls it. The hash is the
truth: a file that does not match is discarded and the next
mirror is tried. Present + hash ok means no network at all, so
re-runs are free. Downloads land in `.part` and are renamed only
once verified — an interrupted run leaves nothing half-written.
A fetch that fails everywhere warns loudly and installs nothing;
it never aborts install.sh.

To add an asset, download it by hand, `sha256sum` it, and add
the line. Never pin a hash you have not computed from the file
yourself — a wrong hash rejects the right file forever.

    ./tests/test-assets.sh

## Boundaries

The repo holds machine-agnostic userspace only.
Bootstrap (kernel, bootloader, network, firmware) lives
in the world file of a concrete machine and never enters
the repo.
