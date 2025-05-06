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

# Nix Setup via Ansible

This repository bootstraps a system to install [Nix](https://nixos.org/) package manager on **macOS** or **Linux** using Ansible.

It automatically:
- Detects the operating system (macOS or Linux)
- Creates `.zshrc` and `.config/` if needed (macOS only)
- Installs Nix with the multi-user (daemon) installation method
- Clones a predefined `nix-config` repository on macOS

---

# Prerequisites

Before running the playbook, make sure the following are installed:

- **Homebrew** (recommended)
- **Git**
- **Ansible**

## 1. Install Homebrew (Recommended for macOS and Linux)

Homebrew simplifies installing Git, Ansible, and other tools.

### Check if Homebrew is already installed:

```bash
brew --version
```

If you see a version like `Homebrew 3.x.x`, it's already installed.

### To install Homebrew:

Run this command (works on macOS and Linux):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation:

#### On macOS:

No further steps needed.

#### On Linux:

You must add Homebrew to your shell environment:

```bash
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc
```

Or for Zsh:

```bash
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

---

## 2. Install Git

### Check if Git is already installed:

```bash
git --version
```

If you see output like `git version 2.x.x`, Git is installed.

### If Git is missing:

#### macOS (using Homebrew):

```bash
brew install git
```

#### Linux (Ubuntu/Debian):

```bash
sudo apt update
sudo apt install git
```

#### Linux (Fedora/RHEL):

```bash
sudo dnf install git
```

---

## 3. Install Ansible

After Git and Homebrew are ready:

### Install Ansible via Homebrew (macOS or Linux):

```bash
brew install ansible
```

### Or install Ansible via your system package manager:

#### Ubuntu/Debian:

```bash
sudo apt update
sudo apt install ansible
```

#### Fedora/RHEL:

```bash
sudo dnf install ansible
```

### Verify Ansible installation:

```bash
ansible --version
```

You should see output like `ansible [core 2.x.x]`.

---

# Usage

Once Git, Homebrew, and Ansible are installed:

### 1. Clone this repository:

```bash
git clone git@github.com:your-username/nix-setup-ansible.git
cd nix-setup-ansible
```

(Replace `your-username` with your GitHub username.)

---

### 2. Run the Ansible playbook:

```bash
ansible-playbook -i inventory playbook.yml
```

- `-i inventory` specifies the provided inventory file.
- `playbook.yml` runs the OS detection, Nix installation, and config steps.

---

# Inventory File

The provided `inventory` file looks like this:

```text
localhost ansible_connection=local
```

This tells Ansible to target your **local machine** — no remote server is needed.

---

# Future Plans

- Add Linux-specific `nix-config` repository setup.
- Install and configure [Home Manager](https://nix-community.github.io/home-manager/).
- Make the Nix installation idempotent (check if Nix is already installed).

---

# References

- [Nix Installation Documentation](https://nixos.org/download.html)
- [Ansible Documentation](https://docs.ansible.com/)
- [Homebrew Installation Guide](https://brew.sh/)

---
