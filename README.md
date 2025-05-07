# Nix Setup via Ansible

> **Quickstart:**  
> If you already have **Homebrew**, **Git**, and **Ansible** installed:
>
> ```bash
> git clone git@github.com:your-username/nix-setup-ansible.git
> cd nix-setup-ansible
> ansible-playbook -i inventory playbook.yml
> ```

---

# Description

This repository bootstraps a system to install [Nix](https://nixos.org/) package manager on **macOS** or **Linux** using Ansible.

It automatically:
- Detects the operating system (macOS or Linux)
- Ensures `zsh` is installed and set as default shell (on Linux)
- Creates `.zshrc` and `.config/` if missing
- Installs Nix if not already installed
- Clones and updates the correct `nix-config` repository based on OS

---

# Prerequisites

You need the following installed first:

## 1. Install Homebrew (macOS and Linux)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation:

- On Linux, add Brew to your shell:

```bash
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc
```

or if you use Zsh:

```bash
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

---

## 2. Install Git

Check if installed:

```bash
git --version
```

If not:

```bash
brew install git  # macOS or Linux with Homebrew
sudo apt install git  # Ubuntu/Debian
sudo dnf install git  # Fedora/RHEL
```

---

## 3. Install Ansible

```bash
brew install ansible  # macOS/Linux via Homebrew
sudo apt install ansible  # Ubuntu/Debian
sudo dnf install ansible  # Fedora/RHEL
```

Check:

```bash
ansible --version
```

---

# Inventory file

The `inventory` file defines:

```ini
localhost ansible_connection=local nix_config_repo_macos=git@github.com:your-username/your-macos-nix-config.git nix_config_repo_linux=git@github.com:your-username/your-linux-nix-config.git
```

Update it with your real GitHub repositories.

---

# Running the playbook

After installing prerequisites and cloning this repo:

```bash
ansible-playbook -i inventory playbook.yml
```

---

# Behavior Overview

| What                   | macOS | Linux |
|:------------------------|:-----:|:-----:|
| Ensure `.zshrc` exists   | ✅    | ✅    |
| Ensure `.config/` exists | ✅    | ✅    |
| Install `zsh` if missing | ❌    | ✅    |
| Set shell to `zsh`       | ❌    | ✅    |
| Install Nix if missing   | ✅    | ✅    |
| Clone nix-config repo    | ✅ (mac repo) | ✅ (linux repo) |

---

# References

- [Nix Installation](https://nixos.org/download.html)
- [Homebrew](https://brew.sh/)
- [Ansible Documentation](https://docs.ansible.com/)

---
