# claude-dev: Claude Code in a Podman container

## Image

The image is built by GitHub Actions and published to GHCR:

    podman pull ghcr.io/welderpb/claude-dev:latest

## Build locally

    podman build -t claude-dev .
    # a specific Claude Code version:
    podman build -t claude-dev --build-arg CLAUDE_CODE_VERSION=X.Y.Z .

## ~/.zshrc setup

```zsh
# needed so pinentry can ask for the GPG passphrase in the terminal
export GPG_TTY=$(tty)

alias claude-podman='podman run --rm -it --init \
  --userns=keep-id:uid=1000,gid=1000 \
  --security-opt=no-new-privileges \
  -v "$PWD":"$PWD":Z \
  -v "$HOME/.config/gh":/home/node/.config/gh:ro,z \
  -v claude-box-config:/home/node/.claude \
  -e CLAUDE_CONFIG_DIR=/home/node/.claude \
  -e CLAUDE_CODE_OAUTH_TOKEN="$(pass show claude | head -n1)" \
  -e GH_TOKEN="$(gh auth token)" \
  -e TERM \
  -w "$PWD" \
  ghcr.io/welderpb/claude-dev:latest claude'
```

Apply it with `source ~/.zshrc`.

## Usage

Go to a project directory and run `claude-podman`. Arguments are passed
through to claude:

    claude-podman --continue
    claude-podman --dangerously-skip-permissions

Do not run it from your home directory: the whole home would be mounted
into the container.

## Authentication

**Claude.** Create a token on the host with `claude setup-token` (valid
for about a year) and store it in pass under the name `claude`:

    pass insert claude

If the token is empty (you cancelled the GPG passphrase prompt), Claude
will offer to log in through the browser. Close it and run
`claude-podman` again.

**GitHub.** The token is taken from `gh auth token` on every launch.
`~/.config/gh` is mounted read-only, only for the gh settings.

## GPG passphrase cache

By default gpg-agent remembers the passphrase for 10 minutes (2 hours
at most). To enter it about once a day, add this to
`~/.gnupg/gpg-agent.conf`:

    default-cache-ttl 28800
    max-cache-ttl 86400

and restart the agent: `gpg-connect-agent reloadagent /bye`.

## Where things are stored

- The project is mounted at the same path as on the host, so Claude
  sessions are stored separately for each project.
- Claude settings and session history live in the `claude-box-config`
  volume. Reset it with `podman volume rm claude-box-config`.

## Security

The container has no network restrictions. With
`--dangerously-skip-permissions` Claude can send the project contents
and both tokens anywhere. Use this mode only with projects you trust.
The GitHub token gives access to all your repositories; if you prefer,
replace it with a fine-grained token with limited access.
