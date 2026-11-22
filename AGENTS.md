# AGENTS.md

Guidance for AI coding agents working in this repository. Used together with
`.context/context.md`, which keeps the higher-level project context.

## Project

`ansible-cloude-code-vps` is an Ansible role that hardens a small VPS and sets
it up to host Cloud Code for remote development, running inside `tmux`. See
`README.md` for full documentation.

- Role FQCN: `kirill_zak.cloude_code_vps`
- Main branch: `master`
- Remote: `git@github.com:kirill-zak/ansible-cloude-code-vps.git`

## Local environment

The repository uses an isolated Python virtual environment (`.ansible/`) for
Ansible and its dependencies. Everything is driven through the top-level
`Makefile`, which includes `scripts/*.mk`.

| Command | Purpose |
| ------- | ------- |
| `make create-venv` | Create `.ansible/` venv and install Ansible + collections |
| `make update-venv` | Upgrade packages and collections inside the venv |
| `make activate` | Open a new shell with the venv on `PATH` (exit to leave) |
| `make test-molecule` | Run the Molecule test suite |

Direct venv activation: `source .ansible/bin/activate`.

- `requirements.txt` — Python deps (`ansible==9.13.0`, `ansible-lint`,
  `molecule`, `molecule-plugins[podman]`, `yamllint`).
- `requirements.yml` — Ansible collections (`ansible.posix`,
  `community.general`).
- Collections are installed into `.ansible/collections` and referenced via
  `ANSIBLE_COLLECTIONS_PATH` set by the Makefile.

End users do **not** need to clone this repository. The README's
"Quick start (from scratch, no clone)" section documents the user-facing flow:
create a venv, `pip install ansible`, then
`ansible-galaxy role install kirill_zak.cloude_code_vps` and run their own
playbook. The Makefile targets above are for development and testing of the
role in this repo.

## Commands to run

Always activate the venv first (`make activate`) or call binaries with the
`.ansible/bin` prefix (`make create-venv` first).

```console
$ make create-venv
$ source .ansible/bin/activate
(ansible) $ ansible --version
(ansible) $ ansible-lint          # lint the role (profile production)
(ansible) $ yamllint .            # lint YAML files
(ansible) $ make test-molecule    # run Molecule tests (uses Podman)
```

## Testing

- Tests use Molecule with Podman as the test engine.
- Test images (see `molecule/`): `kirillzak/docker-{almalinux,rockylinux,alpine,debian,fedora,ubuntu}-ansible`.
- Podman images are pruned after use; re-pulling is expected before a rerun.

## Conventions

- Documentation and code comments are written in **English**.
- Keep `yamllint .` and `ansible-lint` (profile production) clean.
- Commit message prefixes: `feat`, `fix`, `doc` — one commit per action, short
  body, title under 70 characters. Commit only after confirmation.
- **Before every push**, show a concise table of the changes being pushed
  (file → what changed), so the author can review what is about to go out.
- Do not edit without being asked; keep changes consistent with the existing
  Makefile/role/test/CI structure.