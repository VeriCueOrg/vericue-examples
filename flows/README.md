# veriCue flows

Three runnable end-to-end flows. Each one starts a Qt application, discovers
the endpoint or port the veriCue Runtime is listening on, connects a client and
drives the real UI. No fixed ports, no fixed socket paths, no sleeping: every
script reads the announcement the application prints on stdout and fails with a
clear message if it does not arrive.

## Which veriCue build do you need?

| Flow | Transport | Works with the released v0.3.5 package? |
|---|---|---|
| [01-embedded-local-ipc](01-embedded-local-ipc/) | local IPC (UNIX socket) | **No - needs a build newer than v0.3.5** |
| [02-inject-plain-app](02-inject-plain-app/) | local IPC, via `vericue-inject` | **No - needs a build newer than v0.3.5** |
| [03-tcp-explicit](03-tcp-explicit/) | TCP | **Yes - this one runs today** |

`VeriCueServer::startLocal()`, the `VERICUE_ENDPOINT=<path>` announcement and
the local-IPC default of `vericue-inject` landed after v0.3.5, the current
package on <https://dl.vericue.dev>. Flows 1 and 2 need a newer build; flow 3
works with v0.3.5 as it is. Flow 1 fails at build time in a friendly way: the
CMake configure step reports `demo_app is TCP-only` and `--endpoint` then tells
you the same thing instead of misbehaving at runtime.

## Which transport should I use?

- **Same machine, Linux or macOS**: local IPC. A user-private UNIX socket
  (0600) with no network presence at all - nothing to firewall, nothing to scan.
- **Anywhere else** (another host, a container, a device on the bench) **and on
  Windows**: TCP with `setAuthToken()`. Local IPC is not supported on Windows.
- **Driving an application you do not want to rebuild**: `vericue-inject`, on
  Linux x64 with a dynamically linked Qt of the same major version as the
  package. It preloads a probe that starts the veriCue Runtime *inside* the
  target process - a supported way to acquire the Runtime on those
  configurations, with the same protocol, authentication and licensing as an
  embedded server. Embedding `VeriCueServer` (flow 1 or flow 3) is the fallback
  where injection cannot reach - static Qt, other platforms, setuid/setgid
  targets, wrapper scripts - and where the Runtime must be compiled out of
  release builds.

Both transports speak the same protocol and enforce the same authentication and
licensing rules, so a scenario written against one runs unchanged on the other -
only the connect call differs.

## Prerequisites

1. Qt 5.15 or Qt 6.x, and a veriCue package (see the note about versions above).
2. The examples built once:

   ```bash
   cmake -B build -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_PREFIX_PATH="/path/to/Qt/6.7/gcc_64;/path/to/vericue"
   cmake --build build --parallel
   ```

3. The Python client: `pip install vericue`.
4. A veriCue license, or the built-in 30-day trial (the trial allows one
   automation session at a time, which is all these flows use). A flow that
   fails with error 1010-1012 or 1009 is a licensing answer, not a bug in the
   flow.

Run a flow from anywhere:

```bash
flows/01-embedded-local-ipc/run.sh
flows/02-inject-plain-app/run.sh
flows/03-tcp-explicit/run.sh
```

Useful environment variables (all optional):

| Variable | Meaning |
|---|---|
| `PYTHON` | Interpreter that can `import vericue` (default `python3`) |
| `VERICUE_DEMO_APP`, `VERICUE_PLAIN_APP` | Use a specific example binary |
| `VERICUE_INJECT` | Path to `bin/vericue-inject` if it is not on `PATH` |
| `VERICUE_INJECT_LIB` | Path to `libvericue-inject.so` when running from a build tree |
| `QT_QPA_PLATFORM` | Forced Qt platform; the scripts default to `offscreen` when no display is present |

## Troubleshooting

- *The application exits before announcing anything* - the script prints the
  application's own output; a Qt library mismatch (mixing a system Qt with a
  downloaded one) shows up here. Put your Qt `lib/` directory on
  `LD_LIBRARY_PATH`.
- *`vericue-inject: probe not found`* - point `VERICUE_INJECT_LIB` at
  `libvericue-inject.so` in your build or package tree.
- *`vericue-inject` refuses the target* - it needs Linux x64 and a dynamically
  linked Qt of the same major version as the probe. A statically linked Qt
  application cannot be injected (there is no dynamic loader step to preload
  into), and neither can a set-user-ID / set-group-ID binary or a wrapper
  script. Every one of these is refused before launch with the reason; embed
  `VeriCueServer` instead.
