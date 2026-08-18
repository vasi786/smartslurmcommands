# ssc

`ssc` reports the installed semantic version and updates SmartSlurmCommands from the canonical public GitHub repository.

## Usage

```text
ssc --version
ssc --update
ssc --update --tag TAG
ssc --update --help
```

## Update sources

`ssc --update` resolves and installs the latest commit on `vasi786/smartslurmcommands` branch `main`.
This allows small fixes committed after a release to be installed without creating another version or tag.

`ssc --update --tag v0.2.5` resolves and installs that specific tagged revision.
The existing explicit-tag workflow remains available for installing, reinstalling, or returning to a tagged version.

The updater does not inspect Git remotes in the current directory.
GitHub repository `vasi786/smartslurmcommands` is explicitly defined as the public update source.

## Version and commit

Version and commit are intentionally separate:

- `VERSION` contains the semantic release version, such as `0.2.5`.
- `BUILD_COMMIT` contains the full 40-character SHA of the exact installed source, including unreleased `main` commits.

The installed metadata file is located under the shared installation root, normally:

```text
~/.local/share/smartslurmcommands/BUILD_COMMIT
```

Custom-prefix installations store it in `PREFIX/share/smartslurmcommands/BUILD_COMMIT`.
An older installation without commit metadata is treated as having an unknown revision; the update proceeds and creates the file.

`ssc --version` remains unchanged and prints only the semantic version for compatibility with scripts.
Update output shows both version and abbreviated commit.

## Update process and safety

For a normal main update, `ssc`:

1. Queries the GitHub commit endpoint for `main` and validates the returned full SHA.
2. Compares that SHA with installed `BUILD_COMMIT` when available.
3. Optionally queries GitHub's compare endpoint for a concise commit summary.
4. Downloads the repository tar archive for the exact checked SHA, not a moving `main` reference.
5. Checks that the archive is non-empty and readable, extracts it in a temporary directory, and validates required project files and `VERSION`.
6. Runs the normal installer using the current custom prefix when detected, otherwise `~/.local`.
7. Stages the new shared tree beside the installed tree and renames it into place.
8. Restores the previous shared tree if a later installer step fails.
9. Verifies the installed `BUILD_COMMIT` and removes temporary files.

Network, HTTP, rate-limit, malformed-response, download, archive, validation, and installer failures return a nonzero status.
Failures are not reported as “already up to date.”
Commit-summary failure is informational and does not prevent an otherwise valid update.

The updater preserves its existing unattended behavior and does not add a confirmation prompt.

## Network requests

The updater uses the minimum requests needed for the selected operation:

- `GET /repos/vasi786/smartslurmcommands/commits/main` (or the requested tag) resolves the target SHA.
- `GET /repos/vasi786/smartslurmcommands/compare/INSTALLED...TARGET` supplies the optional concise summary when the installed SHA is known.
- `GET /repos/vasi786/smartslurmcommands/tarball/TARGET` downloads the exact target snapshot.

An already-current main installation performs only the commit lookup.
A legacy installation skips the compare request because its base commit is unknown.
Public requests require no token; setting `GITHUB_TOKEN` allows authenticated GitHub API requests when needed.

The updater requires Bash, `curl`, and `tar` plus standard Unix tools already used by SmartSlurmCommands.
It does not require Git, GitHub CLI, `jq`, Python, or Node.js.

## Examples

Already current:

```text
SmartSlurmCommands is already up to date.

Version : 0.2.5
Commit  : f87a331
```

Same semantic version with a newer main commit:

```text
Update available.

Installed:
  Version : 0.2.5
  Commit  : c26b955

Latest main:
  Version : 0.2.5
  Commit  : f87a331
```

Main containing a newer release version:

```text
Update available.

Installed:
  Version : 0.2.5
  Commit  : c26b955

Latest main:
  Version : 0.2.6
  Commit  : 91fb827
```
