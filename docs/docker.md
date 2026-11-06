# `rig tool docker`

Start, stop or restart the Docker daemon, or see whether it runs.

```bash
rig tool docker status   # running or not, and how many containers are up
rig tool docker stop     # stop the daemon, its socket and every container
rig tool docker start    # start it now, after a stop
rig tool docker restart  # for a stuck daemon or a changed config
```

The daemon isn't started at boot (`enableOnBoot = false`). It's socket-activated:
the first `docker` command starts it. That's why `start` is only a convenience,
for after you stopped it yourself.

`stop` is the one worth having. An idle daemon, and whatever containers it still
runs, holds on to memory the WSL VM doesn't hand back to Windows. Stopping only
`docker.service` doesn't stick, because the next `docker` call goes through
`docker.socket` and starts it again. So `stop` stops both, then re-arms the
socket, so the daemon still starts on demand the next time you need it.

`status` only asks Docker for the container count when the daemon is already
running, so checking never starts it. `rig sys doctor` does the same.

`restart` restarts the service. Containers without a restart policy stay
stopped afterwards, as with any daemon restart.
