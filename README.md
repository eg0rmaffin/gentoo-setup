# gentoo-setup

Declarative Gentoo setup. Package manifest + dotfiles.

    ./install.sh

Idempotent: links the manifest into /etc/portage/sets,
installs missing packages, links configs. Safe to re-run
after any repo change (including moving the repo —
symlinks are re-pointed automatically).

## Packages

`desktop` — declarative package manifest (Portage set).

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

## Boundaries

The repo holds machine-agnostic userspace only.
Bootstrap (kernel, bootloader, network, firmware) lives
in the world file of a concrete machine and never enters
the repo.
