# Nix Setup via Ansible

> **Quickstart:**  
> Use one of the bootstrap scripts to prepare your system and run the playbook:

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

# Description

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

# Inventory File

The `inventory` file defines which repo to use depending on the OS:

```ini
localhost ansible_connection=local nix_config_repo_macos=git@github.com:your-username/your-macos-nix-config.git nix_config_repo_linux=git@github.com:your-username/your-linux-nix-config.git
```

Update it with the appropriate URLs for your Nix configurations.

---

# Bootstrap Scripts

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

# Running the Playbook Manually

If you've installed Git and Ansible manually, you can run the playbook like this:

```bash
git clone https://github.com/your-username/nix-setup-ansible.git
cd nix-setup-ansible
ansible-galaxy collection install community.general
ansible-playbook -i inventory playbook.yml
```

---

# Behavior Overview

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

# Logging

The bootstrap scripts log all terminal output to:

```bash
~/bootstrap.log
```

This helps with debugging or reviewing the full install process.

---

# References

- [Nix Installation](https://nixos.org/download.html)
- [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
- [Homebrew](https://brew.sh/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Raycast](https://www.raycast.com/)
- [Xcode CLI Tools](https://developer.apple.com/xcode/resources/)
