# Ansible Cloud Code VPS

An Ansible role that hardens a small VPS and sets it up to host Cloud Code
for remote development, with the session running inside `tmux`.

[![CI workflow](https://github.com/kirill-zak/ansible-cloude-code-vps/actions/workflows/ci.yml/badge.svg)](https://github.com/kirill-zak/ansible-cloude-code-vps/actions/workflows/ci.yml)
[![Ansible Galaxy](https://img.shields.io/badge/galaxy-kirill_zak.cloude_code_vps-660198.svg)](https://galaxy.ansible.com/kirill_zak/cloude_code_vps)

## What it does

- Creates two users:
  - `manager` — SSH + `sudo` access for administration;
  - `code` — restricted to its own home directory, used to run Cloud Code.
- Hardens SSH: disables remote root login, allows key-based auth only, and
  enables brute-force protection.
- Configures the firewall: all ports closed by default, only the SSH port open.
- Installs `tmux` and Cloud Code on the target distro, and deploys a helper
  script to (re)attach a persistent Cloud Code session.

## Requirements

* Ansible core 2.16 or newer.

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

## Quick start (local CLI)

The repository ships a `Makefile` that sets up an isolated Python virtual
environment (`.ansible/`) with Ansible and all required collections. This is
the simplest way to run the role during development or against your VPS.

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
(`ansible==9.13.0`, `ansible-lint`, `molecule`, `molecule-plugins[podman]`,
`yamllint`) plus the collections in `requirements.yml` (`ansible.posix`,
`community.general`) into `.ansible/`. To refresh everything to the latest
versions, run `make update-venv`.

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
| `manager_user` | Administrator user (SSH + sudo) | `manager` |
| `cloud_code_user` | Unprivileged Cloud Code user | `code` |
| `manager_ssh_public_keys` | Public keys installed for `manager` | `[]` |
| `cloud_code_ssh_public_keys` | Public keys installed for `code` | `[]` |
| `ssh_port` | SSH port (also opened in the firewall) | `22` |
| `ssh_disable_password_auth` | Disable password auth (keys only) | `true` |
| `ssh_disable_root_login` | Disable remote root login | `true` |
| `firewall_policy` | Firewall default policy | `drop` |
| `firewall_manage` | Manage the firewall | `true` |
| `protect_ssh_bruteforce` | Enable SSH brute-force protection | `true` |
| `manager_2fa_enabled` | Enable optional 2FA (TOTP) for `manager` | `false` |
| `cloud_code_command` | Command that launches Cloud Code | `cloude-code` |
| `tmux_session_name` | tmux session name | `cloude-code` |

## Dependencies

- `ansible.posix` — `authorized_key`, `firewalld`.
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

## Connecting and running Cloud Code

After the role has provisioned the VPS, SSH in via the `code` user and (re)attach
a Cloud Code session inside `tmux`, which keeps the session alive across
disconnects. Use the bundled helper script:

```console
$ VPS_HOST=203.0.113.10 ./scripts/connect-cloud-code.sh
```

What the script does:

```bash
ssh code@203.0.113.10 \
  -t "tmux new-session -A -s cloude-code cloude-code"
```

- `-t` forces a TTY, required for the interactive tmux session.
- `new-session -A -s cloude-code` attaches to the existing session, or creates
  it and starts Cloud Code if none exists.

Set the values via environment variables as needed:

```console
$ VPS_HOST=203.0.113.10 VPS_USER=code TMUX_SESSION=cloude-code ./scripts/connect-cloud-code.sh
```

## License

GPL-2.0-or-later

## Author Information

https://kirill-zak.ru