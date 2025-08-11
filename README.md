# Nix Bootstrap via Ansible (macOS & Linux)

This repository provisions a Nix-based developer environment using a modular Ansible playbook with roles:

- common (Nix install, flake repo clone, logging prep)
- mac_shell (mac apps/config; now assumes host Homebrew & Ansible exist)
- linux_desktop (Hyprland / Wayland placeholder)
- languages (language toolchain placeholder)

macOS bootstrap script now also ensures host dependencies:

1. Xcode Command Line Tools
2. Homebrew (installs if missing)
3. Ansible (via Homebrew if missing)
4. (Optionally) clone/update this repo
5. Run playbook (real or simulation)

All remaining package/app installations live in roles (idempotent & check‑mode aware). Ansible itself is NOT installed inside playbook anymore.

---

## Quick Start (macOS)

Just run (no pre-install needed):

```bash
./bootstrap-macos.sh https://github.com/snyderb-de/nix-from-ansible.git
```

Run modes:

| Mode | Command | What Happens | Side Effects |
|------|---------|--------------|--------------|
| Basic Dry Run | `./bootstrap-macos.sh --dry-run <repo>` | Prints planned actions (including messages about installing brew/ansible) | None |
| Full Simulation | `./bootstrap-macos.sh --dry-run-full <repo>` | Installs missing brew + ansible (real), shallow clone, runs `ansible --check` | Brew/Ansible install + clone only |
| Real Run | `./bootstrap-macos.sh <repo>` | Ensures deps, clones/updates, full playbook | Full changes |

Note: `--dry-run-full` performs real dependency installs so Ansible can execute.

Logs (real run): `~/.config/bootstrap.log` plus role buffered logs under `~/nix-bootstrap-logs/`.

---

## Quick Start (Linux)

(Host must already have Ansible & Git, or install them via your package manager.)

```bash
sudo apt update && sudo apt install -y ansible git   # example

git clone https://github.com/snyderb-de/nix-from-ansible.git
cd nix-from-ansible
ansible-playbook -i inventory playbook.yml           # add --check for dry run
```

---

## Dry-Run Layers

| Layer | Flag | Effect |
|-------|------|--------|
| Bootstrap basic | `--dry-run` | No installs, prints intentions |
| Bootstrap full  | `--dry-run-full` | Installs brew+ansible if missing, clone, ansible `--check` |
| Ansible | `--check` | Skips mutating tasks (debug messages instead) |

---

## Inventory Configuration

```ini
localhost ansible_connection=local \
  nix_config_repo_macos=https://github.com/your-user/your-macos-nix-config.git \
  nix_config_repo_linux=https://github.com/your-user/your-linux-nix-config.git
```

---

## Playbook Structure

Roles run in order: common → mac_shell → linux_desktop → languages.
mac_shell no longer installs Ansible (bootstrap responsibility).

---

## mac_shell Role Summary

- Ensures brew shellenv line in `~/.zprofile`
- Updates Homebrew (real runs)
- Installs Ghostty, Raycast, lazygit, powershell
- Ensures `community.general` collection

---

## Examples

Full simulation (will install brew + ansible if missing, but no other changes):

```bash
./bootstrap-macos.sh --dry-run-full https://github.com/snyderb-de/nix-from-ansible.git
```

Preview only:

```bash
./bootstrap-macos.sh --dry-run https://github.com/snyderb-de/nix-from-ansible.git
```

Real:

```bash
./bootstrap-macos.sh https://github.com/snyderb-de/nix-from-ansible.git
```

---

## Extending

Planned:

- Hyprland tasks (linux_desktop)
- Language toolchain mapping variable
- Home Manager integration
- Installer checksum verification

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Brew install failed | Re-run script; check network/proxy |
| Ansible still missing after run | Ensure brew in PATH; source `~/.zprofile` |
| Want pure simulation | Use basic `--dry-run` |
| Need diff of changes | `ansible-playbook ... --check --diff` |

---

Happy hacking! 🚀
