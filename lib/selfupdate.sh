SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/util.sh"

ssc::self_update() {
    require_cmd curl
    require_cmd tar

    local current new tarball tmp

    current="$(util::version)"
    echo "Current version: $current"

    echo "Checking latest release..."
    new="$(curl -s https://api.github.com/repos/vasi786/smartslurmcommands/releases/latest \
        | grep -Po '"tag_name":\s*"\K[^"]+')"
    new="${new#v}"

    if [[ -z "$new" ]]; then
        echo "ERROR: Could not fetch latest version." >&2
        return 2
    fi

    echo "Latest available: $new"

    if [[ "$new" == "$current" ]]; then
        echo "Already up to date."
        return 0
    fi

    tarball="https://github.com/vasi786/smartslurmcommands/releases/download/v${new}/smartslurmcommands-${new}.tar.gz"

    echo "Downloading $tarball"
    tmp="$(mktemp -d)"
    curl -L "$tarball" -o "$tmp/new.tgz" || {
        echo "Download failed." >&2; return 2;
    }

    echo "Extracting..."
    mkdir -p "$HOME/.local/share"
    tar -xzf "$tmp/new.tgz" -C "$HOME/.local/share" || {
        echo "Extraction failed." >&2; return 2;
    }

    # Install new wrapper
    mkdir -p "$HOME/.local/bin"
    cp "$HOME/.local/share/smartslurmcommands-${new}/cmd/ssc/ssc.sh" "$HOME/.local/bin/ssc"
    chmod +x "$HOME/.local/bin/ssc"

    # Replace old version
    rm -rf "$HOME/.local/share/smartslurmcommands"
    mv "$HOME/.local/share/smartslurmcommands-${new}" \
       "$HOME/.local/share/smartslurmcommands"

    echo "Updated to version $new successfully."
    echo "Run 'ssc --version' to verify."

    rm -rf "$tmp"
}
