# Configuration

Configuration files contain `KEY=VALUE` data; they are never sourced as shell code.
The load order is built-in defaults, project configuration, user configuration, then supported environment overrides.

Locations:

- project: `.smartslurmcommands` in the current directory
- user: `${XDG_CONFIG_HOME:-$HOME/.config}/smartslurmcommands/config`

Supported keys:

| Key | Type | Default | Behavior |
|---|---|---|---|
| `confirm` | boolean | `true` | Ask before `smartcancel` performs cancellation. `--force` still skips the prompt. |
| `dry_run` | boolean | `false` | Make `smartcancel` display commands without executing them. |
| `smartcancel.include_dependents` | boolean | `true` | Recursively include dependent jobs. The complete expanded set is shown before confirmation. |

Boolean values accept `true/false`, `yes/no`, `on/off`, and `1/0`, case-insensitively.
Whitespace around keys, `=`, and values is allowed, as are matching single or double quotes around values.
Malformed and unknown entries are ignored with a warning.

Environment overrides are explicit:

- `SSC_CONFIRM`
- `SSC_DRY_RUN`
- `SSC_SMARTCANCEL_INCLUDE_DEPENDENTS`
