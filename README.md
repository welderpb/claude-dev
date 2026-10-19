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
  -v "$HOME/.config/git":/home/node/.config/git:ro,z \
  -v /srv/podman-builder/podman.sock:/run/podman/podman.sock \
  -v claude-box-config:/home/node/.claude \
  -e CLAUDE_CONFIG_DIR=/home/node/.claude \
  -e CLAUDE_CODE_OAUTH_TOKEN="$(pass show claude | head -n1)" \
  -e GH_TOKEN="$(gh auth token)" \
  -e TERM \
  -w "$PWD" \
  ghcr.io/welderpb/claude-dev:latest claude'
```

Apply it with `source ~/.zshrc`.

## Building images from the container

The image contains `podman-remote` (available as `podman`). It talks to a
rootless Podman of a separate host user, `builder`, which has no access
to your home directory. Never mount your own Podman socket here: it
would give the container full access to your user.

One-time setup on the host (run as root, e.g. with sudo):

    useradd --create-home --shell /usr/bin/nologin builder
    # if useradd did not allocate subuid/subgid ranges:
    # usermod --add-subuids 200000-265535 --add-subgids 200000-265535 builder
    loginctl enable-linger builder

    # directory for the socket: only builder and you can enter it
    install -d -o builder -g builder -m 0750 /srv/podman-builder
    setfacl -m u:YOUR_LOGIN:x /srv/podman-builder  # replace YOUR_LOGIN, do not leave it empty

    # put the socket there and make it connectable
    sudo -u builder install -d /home/builder/.config/systemd/user/podman.socket.d
    sudo -u builder tee /home/builder/.config/systemd/user/podman.socket.d/override.conf <<'EOF'
    [Socket]
    ListenStream=
    ListenStream=/srv/podman-builder/podman.sock
    SocketMode=0666
    EOF
    systemctl --user -M builder@ daemon-reload
    systemctl --user -M builder@ enable --now podman.socket

Check that `/srv/podman-builder/podman.sock` exists. If `-M builder@`
complains about a missing session, make sure lingering is enabled:
`loginctl show-user builder | grep Linger`.

Inside the container `podman build` now works: the build context is
sent through the socket. Images are stored by `builder`, not by you;
to use one on the host, copy it:

    CONTAINER_HOST=unix:///srv/podman-builder/podman.sock podman save IMAGE | podman load

Mounts of your directories (`podman run -v ...`) do not work with this
setup, since `builder` cannot read your files. This is intentional.

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

The Podman socket belongs to the separate `builder` user, so Claude can
build images but cannot reach your home directory through it. It can
still use the `builder` account: run containers there, use its network
and CPU. Do not give `builder` access to anything valuable.

The container has no network restrictions. With
`--dangerously-skip-permissions` Claude can send the project contents
and both tokens anywhere. Use this mode only with projects you trust.
The GitHub token gives access to all your repositories; if you prefer,
replace it with a fine-grained token with limited access.
