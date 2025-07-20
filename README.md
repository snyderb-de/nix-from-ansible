# Nix Setup via Ansible

> **Quickstart:**  
> Use one of the bootstrap scripts to prepare your system and run the playbook:
>
> ⚠️ **Note for macOS users:** If you plan to run the playbook manually (without using the bootstrap script), you must first install Git and Xcode Command Line Tools. See [Prerequisites](#prerequisites) below.

**macOS:**

```bash
curl -O https://raw.githubusercontent.com/your-username/nix-setup-ansible/main/bootstrap-macos.sh
chmod +x bootstrap-macos.sh
./bootstrap-macos.sh https://github.com/your-username/nix-setup-ansible.git
```

**Linux / NixOS:**

```bash
curl -O https://raw.githubusercontent.com/your-username/nix-setup-ansible/main/bootstrap-linux.sh
chmod +x bootstrap-linux.sh
./bootstrap-linux.sh https://github.com/your-username/nix-setup-ansible.git
```

---

## Prerequisites

### macOS Users

Before running the playbook manually (if not using the bootstrap script), you **must** install:

1. **Xcode Command Line Tools:**

   ```bash
   xcode-select --install
   ```

2. **Git** (usually included with Command Line Tools, but verify):

   ```bash
   git --version
   ```

   If Git is not available, install it via Homebrew or download from [git-scm.com](https://git-scm.com/).

3. **Ansible** (if running playbook manually):

   ```bash
   # Install via Homebrew (recommended)
   brew install ansible
   # OR install via pip
   pip3 install ansible
   ```

### Linux Users

Most Linux distributions include Git by default. If not, install via your package manager:

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install git ansible

# RHEL/CentOS/Fedora
sudo dnf install git ansible

# Arch Linux
sudo pacman -S git ansible
```

### NixOS Users

Add the following to your `/etc/nixos/configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  git
  ansible
];
```

Then run: `sudo nixos-rebuild switch`

---

## Description

This repository bootstraps a system to install the [Nix](https://nixos.org/) package manager on **macOS** or **Linux** using Ansible.

It automatically:

- Detects the operating system (macOS, Linux, or NixOS)
- Installs Ansible (via Homebrew or OS package manager)
- Installs required Ansible collections (`community.general`)
- Ensures `.zshrc` and `.config/` exist
- Installs `zsh` (on Linux) and sets it as the default shell
- Installs Nix via the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer) if missing
- Clones and updates your Nix config repo (based on OS)
- Installs Raycast (on macOS, via Homebrew Cask)

---

## Inventory File

The `inventory` file defines which repo to use depending on the OS:

```ini
localhost ansible_connection=local nix_config_repo_macos=git@github.com:your-username/your-macos-nix-config.git nix_config_repo_linux=git@github.com:your-username/your-linux-nix-config.git
```

Update it with the appropriate URLs for your Nix configurations.

---

## Bootstrap Scripts

You can use one of the following scripts depending on your OS. Each script:

- Installs required dependencies (Git, Ansible, Curl)
- Installs the `community.general` Ansible collection
- Clones the setup repository
- Runs the Ansible playbook
- Logs the full process to `~/bootstrap.log`

### `bootstrap-macos.sh`

For macOS. It:

- Installs Xcode Command Line Tools (if missing)
- Installs Homebrew
- Installs Git, Curl, Ansible
- Installs Raycast (via Homebrew Cask)

### `bootstrap-linux.sh`

For Linux:

- Detects the system package manager (APT, DNF, Pacman, Zypper)
- Installs Ansible, Git, Curl via the appropriate package manager

For **NixOS**:

- Skips system installs
- Prompts the user to add the following to `/etc/nixos/configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  git
  curl
  ansible
];
```

Then run:

```bash
sudo nixos-rebuild switch
```

After that, re-run the script to continue.

---

## Running the Playbook Manually

If you prefer to run the playbook manually instead of using the bootstrap scripts, ensure you have the prerequisites installed first:

## Prerequisites Check

**macOS users:** Verify you have the required tools:

```bash
# Check if Command Line Tools are installed
xcode-select -p

# Check if Git is available
git --version

# Check if Ansible is available
ansible --version
```

If any of these are missing, refer to the [Prerequisites](#prerequisites) section above.

**Linux/NixOS users:** Ensure Git and Ansible are installed via your package manager.

## Manual Installation Steps

Once prerequisites are met, run:

```bash
git clone https://github.com/your-username/nix-setup-ansible.git
cd nix-setup-ansible
ansible-galaxy collection install community.general
ansible-playbook -i inventory playbook.yml
```

---

## Behavior Overview

| Feature                        | macOS | Linux | NixOS |
|-------------------------------|:-----:|:-----:|:-----:|
| Create `.zshrc`               | ✅    | ✅    | ✅    |
| Create `.config/`             | ✅    | ✅    | ✅    |
| Install `zsh` if missing      | ❌    | ✅    | ✅    |
| Set default shell to `zsh`    | ❌    | ✅    | ✅    |
| Install Nix if missing        | ✅    | ✅    | ✅    |
| Clone Nix config repo         | ✅    | ✅    | ✅    |
| Install Raycast via Homebrew  | ✅    | ❌    | ❌    |
| Install Git, Ansible, Curl    | ✅    | ✅    | ❌ (manual in config) |
| Install Command Line Tools    | ✅    | ❌    | ❌    |

---

## Logging

The bootstrap scripts log all terminal output to:

```bash
~/bootstrap.log
```

This helps with debugging or reviewing the full install process.

---

## References

- [Nix Installation](https://nixos.org/download.html)
- [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
- [Homebrew](https://brew.sh/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Raycast](https://www.raycast.com/)
- [Xcode CLI Tools](https://developer.apple.com/xcode/resources/)
