# Ansible Claude Code VPS

An Ansible role that hardens a small VPS and sets it up to run Claude Code
for remote development, with the session running inside `tmux`.

[![CI workflow](https://github.com/kirill-zak/ansible-cloude-code-vps/actions/workflows/ci.yml/badge.svg)](https://github.com/kirill-zak/ansible-cloude-code-vps/actions/workflows/ci.yml)
[![Ansible Galaxy](https://img.shields.io/badge/galaxy-kirill_zak.cloude_code_vps-660198.svg)](https://galaxy.ansible.com/kirill_zak/cloude_code_vps)

## Table of Contents

- [What it does](#what-it-does)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start (from scratch, no clone)](#quick-start-from-scratch-no-clone)
- [Development setup (this repository)](#development-setup-this-repository)
- [Supported platforms](#supported-platforms)
- [Role Variables](#role-variables)
- [Security notes](#security-notes)
- [Dependencies](#dependencies)
- [Provisioning your VPS](#provisioning-your-vps)
  - [A) Root access by password](#a-root-access-by-password)
  - [B) Root access by SSH key](#b-root-access-by-ssh-key)
  - [C) Panel + root password (hybrid)](#c-panel--root-password-hybrid)
- [Connecting and running Claude Code](#connecting-and-running-claude-code)
- [License](#license)
- [Author Information](#author-information)

## What it does

- Creates two users:
  - `manager` — SSH + `sudo` access for administration;
  - `code` — an unprivileged account (no `sudo`, home directory mode `0700`)
    used to run Claude Code. It is not a filesystem sandbox: the role does not
    restrict where the account can read or write.
- Downloads the Claude Code release binary into the `code` user's
  `~/.local/bin/claude` and links it to `/usr/local/bin/claude`.
- Deploys a helper script (`/usr/local/bin/claude-code-session`) that runs
  Claude Code in a `claude-code` tmux session and (re)attaches to it.
- Hardens SSH: only the `manager` and `code` users may log in (`AllowUsers`),
  remote root login is blocked, key-based auth is required, and brute-force
  protection is enabled with fail2ban.
- Configures the firewall so all ports are closed by default and only the SSH
  port is open: nftables with a drop policy on Alpine, firewalld with a
  `DROP` target on RHEL-family, and ufw on Debian/Ubuntu.
- Installs `tmux` on the target distro and creates a 2 GB swap file by
  default, so 1–2 GB VPSes can run Claude Code.

## Requirements

* Ansible core 2.19 or newer.
* 4 GB or more of RAM is recommended: Claude Code itself recommends 4 GB+.
  1–2 GB VPSes work with the default 2 GB swap file (`swap_enabled: true`,
  `swap_file: /swapfile`, `swap_size_mb: 2048`); the role prints a warning when
  the host has less than 4 GB of RAM and `claude_code_install` is true.
* Outbound HTTPS from the VPS to `storage.googleapis.com` (the Claude Code
  release download) and to Anthropic's API endpoints (the agent itself).

## Installation

Install the role from Ansible Galaxy:

```console
$ ansible-galaxy role install kirill_zak.cloude_code_vps
```

Or add it to your `requirements.yml`:

```yaml
---
roles:
  - name: kirill_zak.cloude_code_vps
```

## Quick start (from scratch, no clone)

You don't need to clone this repository. On a clean laptop, set up a Python
virtual environment, install Ansible, pull the role from Ansible Galaxy, write
a small playbook, and run it against your VPS.

**1. Create a virtual environment and install Ansible**

```console
$ python3 -m venv .venv
$ source .venv/bin/activate
(.venv) $ pip install --upgrade pip
(.venv) $ pip install ansible
(.venv) $ ansible --version
```

> Tip: just `ansible`, not `ansible-core` — the `ansible` package bundles the
> core plus a curated set of collections (including `ansible.posix` and
> `community.general`, which this role needs).

**2. Install the role from Ansible Galaxy**

```console
(.venv) $ ansible-galaxy role install kirill_zak.cloude_code_vps
```

**3. Create a playbook** that calls the role. For example, open a new file
`playbook.yml` in any text editor (e.g. `vim playbook.yml`) and paste:

```yaml
---
- name: Provision VPS
  hosts: all
  remote_user: root
  become: true
  vars:
    # Your own public keys, installed for the manager and code users. The
    # manager account has no password, so at least one manager key is
    # required; the role refuses to run without it.
    manager_ssh_public_keys:
      - "ssh-ed25519 AAAAC3... your-manager-key"
    cloud_code_ssh_public_keys:
      - "ssh-ed25519 AAAAC3... your-code-key"
  roles:
    - role: kirill_zak.cloude_code_vps
```

Then create an inventory `hosts.ini` (again, with a text editor — for example
`vim hosts.ini`) and paste, replacing `PUBLIC_IP` with your VPS address:

```ini
[all]
vps ansible_host=PUBLIC_IP ansible_user=root
```

**4. Run the playbook**

```console
(.venv) $ ansible-playbook -i hosts.ini -u root --ask-pass playbook.yml
```

See [Provisioning your VPS](#provisioning-your-vps) for all supported access
methods (root password, SSH key, or panel).

## Development setup (this repository)

Contributors who have cloned the repository can use the bundled `Makefile`,
which sets up an isolated virtual environment (`.ansible/`) from
`requirements.txt` and `requirements.yml`.

```console
# 1. Create the virtual environment and install Ansible + collections
$ make create-venv

# 2. Activate the venv (opens a new shell with ansible on PATH)
$ make activate
(ansible) $ ansible --version

# 3. Deactivate when you're done
(ansible) $ exit
```

You can activate the venv directly instead of using `make activate`:

```console
$ source .ansible/bin/activate
```

`make create-venv` installs everything from `requirements.txt`
(`ansible==15.0.0`, `ansible-lint==26.11.0`, `molecule==26.11.0`,
`molecule-plugins[podman]==26.11.0`, `yamllint==1.38.0`) plus the collections
in `requirements.yml` (`ansible.posix`, `community.general`) into `.ansible/`.
To refresh everything to the latest versions, run `make update-venv`.

## Supported platforms

| Distribution | Versions |
| ------------ | -------- |
| AlmaLinux    | 8, 9 |
| Alpine Linux | all |
| Debian       | 12 (Bookworm), 13 (Trixie) |
| Fedora       | 43, 44 |
| Rocky Linux  | 8, 9 |
| Ubuntu       | 22.04 (Jammy), 24.04 (Noble) |

## Role Variables

| Variable | Description | Default |
| -------- | ----------- | ------- |
| `manager_user` | Administrator user (SSH + passwordless `sudo`) | `manager` |
| `cloud_code_user` | Unprivileged user that runs Claude Code (no `sudo`) | `code` |
| `manager_user_home` | Home directory of the `manager` user | `/home/manager` |
| `cloud_code_user_home` | Home directory of the `code` user | `/home/code` |
| `manager_ssh_public_keys` | Public keys installed for `manager` | `[]` |
| `cloud_code_ssh_public_keys` | Public keys installed for `code` | `[]` |
| `ssh_port` | SSH port (also opened in the firewall and used by the fail2ban jail) | `22` |
| `ssh_disable_password_auth` | Disable password auth (keys only) | `true` |
| `ssh_disable_root_login` | Disable remote root login (`PermitRootLogin no`) | `true` |
| `ssh_allow_users` | Users allowed to log in over SSH (`AllowUsers`) | `manager code` |
| `ssh_max_auth_tries` | Max SSH auth attempts before disconnect | `3` |
| `ssh_client_alive_interval` | Seconds between SSH keepalive probes | `300` |
| `ssh_client_alive_count_max` | Keepalive failures before session end | `2` |
| `ssh_login_grace_time` | Seconds to complete login | `60` |
| `ssh_permit_user_environment` | Allow `~/.ssh/environment` for users | `false` |
| `ssh_allow_agent_forwarding` | Allow SSH agent forwarding | `false` |
| `firewall_policy` | Firewall default policy | `drop` |
| `firewall_manage` | Manage the firewall | `true` |
| `firewall_service_manage` | Start and enable the firewall service (Alpine/nftables only) | `true` |
| `protect_ssh_bruteforce` | Enable fail2ban SSH brute-force protection | `true` |
| `fail2ban_service_manage` | Start and enable the fail2ban service | `true` |
| `fail2ban_bantime` | Ban duration for repeat offenders | `1h` |
| `fail2ban_findtime` | Lookback window for counting failures | `10m` |
| `fail2ban_maxretry` | Allowed failures before a ban | `5` |
| `fail2ban_banaction` | Firewall backend fail2ban uses | resolved per distro: `firewallcmd-ipset` / `ufw` / `nftables-multiport` |
| `auto_updates_enabled` | Install and configure automatic package updates | `true` |
| `dnf_automatic_update_type` | dnf-automatic channel (RHEL-family) | `security` |
| `manager_2fa_enabled` | Enable optional 2FA (TOTP) for `manager` | `false` |
| `claude_code_install` | Download the Claude Code release binary for `code` | `true` |
| `claude_code_release_channel` | Release channel resolved to a concrete version before the download | `stable` |
| `claude_code_download_base` | Public release bucket the binary is downloaded from | `https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases` |
| `cloud_code_command` | Command that launches Claude Code inside tmux | `claude` |
| `tmux_session_name` | tmux session name for the Claude Code session | `claude-code` |
| `swap_enabled` | Create and enable the swap file | `true` |
| `swap_file` | Path of the swap file | `/swapfile` |
| `swap_size_mb` | Size of the swap file in megabytes | `2048` |

> **Note on `ssh_port`:** if you change it, open the same port in your VPS
> provider's firewall or security group **before** you run the role. The role
> moves sshd, its own firewall, and the fail2ban jail to the new port
> together, but it cannot open the provider's perimeter firewall for you —
> otherwise the new sshd port is unreachable.

> **Note on `manager_ssh_public_keys`:** with the default settings this
> variable is effectively required. The `manager` account is created without
> a password, and with `ssh_disable_password_auth: true` the role refuses to
> run when no manager key is provided.

## Security notes

- **Use a dedicated VPS.** Claude Code credentials and any API keys live in
  the `code` user's home directory on the VPS; keep this workload off a
  server that runs anything else.
- **Scope your keys.** Prefer API keys scoped to the minimum access the agent
  needs, with spending budgets set.
- **Rotate them.** Rotate the Claude Code credentials and API keys on a
  regular schedule.

## Dependencies

- `ansible.posix` — `authorized_key`, `firewalld`, `mount`.
- `community.general` — `apk`, `ufw`.

## Provisioning your VPS

VPS providers hand over a fresh server in one of three ways. Pick the playbook
that matches how your provider delivered your VPS.

### A) Root access by password

The provider generated a **root password** (no SSH key on the server yet).

```yaml
---
- name: Provision VPS (root + password)
  hosts: all
  remote_user: root
  become: true
  vars:
    # Public keys that the role installs for manager and code.
    manager_ssh_public_keys:
      - "ssh-ed25519 AAAAC3... your-manager-key"
    cloud_code_ssh_public_keys:
      - "ssh-ed25519 AAAAC3... your-code-key"
  roles:
    - role: kirill_zak.cloude_code_vps
```

Run it — Ansible will prompt for the root password:

```console
$ ansible-playbook -i hosts.ini -u root --ask-pass playbook.yml
```

After the role runs, root login and password auth are disabled, so reconnect
as `manager`.

### B) Root access by SSH key

The provider **attached your SSH key** at creation time, so you can log in as
root over SSH without a password.

```yaml
---
- name: Provision VPS (root + key)
  hosts: all
  remote_user: root
  become: true
  vars:
    ansible_ssh_private_key_file: ~/.ssh/id_ed25519
    manager_ssh_public_keys:
      - "ssh-ed25519 AAAAC3... your-manager-key"
    cloud_code_ssh_public_keys:
      - "ssh-ed25519 AAAAC3... your-code-key"
  roles:
    - role: kirill_zak.cloude_code_vps
```

Run it (no password prompt):

```console
$ ansible-playbook -i hosts.ini -u root playbook.yml
```

`hosts.ini` for this case:

```ini
[all]
vps ansible_host=PUBLIC_IP ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

### C) Panel + root password (hybrid)

The provider gave you the **root password and a web panel/console**. You can
either add your SSH key through the panel first (then use playbook B), or let
the role install the keys on the first run — the setup is the same as playbook A:

```yaml
---
- name: Provision VPS (panel + password)
  hosts: all
  remote_user: root
  become: true
  vars:
    manager_ssh_public_keys:
      - "ssh-ed25519 AAAAC3... your-manager-key"
    cloud_code_ssh_public_keys:
      - "ssh-ed25519 AAAAC3... your-code-key"
  roles:
    - role: kirill_zak.cloude_code_vps
```

```console
$ ansible-playbook -i hosts.ini -u root --ask-pass playbook.yml
```

Once the keys are installed, root login over password is disabled and you
should connect as `manager`.

## Connecting and running Claude Code

After the role has provisioned the VPS, connect as the `code` user and
(re)attach the Claude Code session inside `tmux`, which keeps the session
alive across disconnects. Use the bundled helper script:

```console
$ VPS_HOST=203.0.113.10 ./scripts/connect-cloud-code.sh
```

What the script does: it connects over SSH and execs the helper that the role
deploys on the VPS:

```bash
ssh code@203.0.113.10 -t /usr/local/bin/claude-code-session
```

- `-t` forces a TTY, required for the interactive tmux session.
- The `claude-code-session` helper runs `tmux new-session -A -s claude-code claude`:
  it attaches to the existing `claude-code` session, or creates it and starts
  `claude` if none exists.

Set the values via environment variables as needed:

| Variable | Default | Meaning |
| -------- | ------- | ------- |
| `VPS_HOST` | — (required) | Your VPS IP or hostname |
| `VPS_USER` | `code` | The user to connect as |
| `TMUX_SESSION` | `claude-code` | The tmux session name |
| `REMOTE_HELPER` | `/usr/local/bin/${TMUX_SESSION}-session` | The helper executed on the VPS |

```console
$ VPS_HOST=203.0.113.10 VPS_USER=code TMUX_SESSION=claude-code ./scripts/connect-cloud-code.sh
```

**First login.** The first time `claude` starts, it prints a URL. Open the URL
in a browser, sign in, and paste the code it shows back into the terminal.

## License

GPL-2.0-or-later

## Author Information

https://kirill-zak.ru