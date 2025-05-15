# Nix Setup via Ansible

> **Quickstart:**  
> Use one of the bootstrap scripts to prepare your system and run the playbook:

macOS:
```bash
curl -O https://raw.githubusercontent.com/your-username/nix-setup-ansible/main/bootstrap-macos.sh
chmod +x bootstrap-macos.sh
./bootstrap-macos.sh https://github.com/your-username/nix-setup-ansible.git
```

Linux:
```bash
curl -O https://raw.githubusercontent.com/your-username/nix-setup-ansible/main/bootstrap-linux.sh
chmod +x bootstrap-linux.sh
./bootstrap-linux.sh https://github.com/your-username/nix-setup-ansible.git
```

---

# Description

This repository bootstraps a system to install the [Nix](https://nixos.org/) package manager on **macOS** or **Linux** using Ansible.

It automatically:
- Detects the operating system (macOS or Linux)
- Installs Ansible (via Homebrew or OS package manager)
- Installs required Ansible collections (e.g., `community.general`)
- Ensures `.zshrc` and `.config/` exist
- Installs `zsh` (on Linux) and sets it as the default shell
- Installs Nix (if missing)
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

- Installs required dependencies (Git, Ansible)
- Installs the `community.general` Ansible collection
- Clones the setup repository
- Runs the Ansible playbook
- Logs the full process to `~/bootstrap.log`

### `bootstrap-macos.sh`

For macOS. Installs Homebrew, Ansible, and Raycast.

### `bootstrap-linux.sh`

For Linux. Detects package manager (APT, DNF, Pacman, Zypper) and installs Ansible appropriately.

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

| Feature                        | macOS | Linux |
|-------------------------------|:-----:|:-----:|
| Create `.zshrc`               | ✅    | ✅    |
| Create `.config/`             | ✅    | ✅    |
| Install `zsh` if missing      | ❌    | ✅    |
| Set default shell to `zsh`    | ❌    | ✅    |
| Install Nix if missing        | ✅    | ✅    |
| Clone Nix config repo         | ✅    | ✅    |
| Install Raycast via Homebrew  | ✅    | ❌    |

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
- [Homebrew](https://brew.sh/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Raycast](https://www.raycast.com/)
