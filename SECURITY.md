# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems that could put user
VPS instances at risk (for example, a flaw in the SSH hardening, firewall
rules, or the remote-dev setup).

Instead, report privately:

- GitHub private vulnerability reporting (preferred):
  use the **"Report a vulnerability"** button on the repo's **Security** tab.
- Or email the maintainer directly (see
  [Author Information](https://kirill-zak.ru)).

We'll acknowledge the report as soon as possible, keep you updated on the fix,
and credit you (if you wish) once the issue is resolved.

## Scope

This role runs with elevated privileges (it disables root SSH login, changes
the firewall, and installs software) on user-managed VPS instances. Reports
that could lead to:

- unauthorised access to a deployed VPS,
- privilege escalation inside the role's hardening,
- or breakage of the security controls the role applies,

are in scope. Documentation typos or feature requests are better filed as
regular issues.

## Supported versions

| Version | Support |
| ------- | ------- |
| latest | Active |

Only the latest released version is actively supported. Releases are published
to Ansible Galaxy from version tags; see the Release workflow and the
`meta/main.yml` in the role.