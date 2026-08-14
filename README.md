# veriCue examples

Example Qt applications and runnable end-to-end flows for
[veriCue](https://vericue.dev) - a test automation framework for Qt 5 and Qt 6.

veriCue runs as the **veriCue Runtime** inside your Qt application. Clients
(Python, C++, C#) connect to it over one of two transports:

- **local IPC** - a user-private UNIX socket, no network presence. Supported on
  **Linux and macOS**. The right choice when the tests run on the same machine
  as the application.
- **TCP** - reachable from other hosts. The choice for another host, a
  container or a device, and **the transport to use on Windows**, where local
  IPC is not supported.

Both speak the identical protocol and enforce the identical authentication and
licensing rules, so a scenario is written once and runs over either.

## Version requirement - read this first

All three flows run against **v0.4.0**, the current package on
<https://dl.vericue.dev>.

| Flow | Transport | v0.4.0 | v0.3.5 |
|---|---|---|---|
| [flows/01-embedded-local-ipc](flows/01-embedded-local-ipc/) | local IPC | yes | no |
| [flows/02-inject-plain-app](flows/02-inject-plain-app/) | local IPC via `vericue-inject` | yes | no |
| [flows/03-tcp-explicit](flows/03-tcp-explicit/) | TCP | yes | yes |

`VeriCueServer::startLocal()`, the `VERICUE_ENDPOINT=<path>` announcement and
the local-IPC default of `vericue-inject` arrived in v0.4.0. If you are still on
v0.3.5, run flow 3 and upgrade for the other two. Nothing breaks quietly:
building against v0.3.5 configures `demo_app` as TCP-only and says so, and
`--endpoint` then tells you which build you need.

## Flows

Each flow starts an application, discovers the endpoint or port it is listening
on from the application's own stdout, connects a client and drives the real UI.
No fixed ports, no fixed socket paths, no sleeping.

```bash
flows/01-embedded-local-ipc/run.sh   # embed VeriCueServer, startLocal(), connect_local()
flows/02-inject-plain-app/run.sh     # vericue-inject against an app with zero veriCue code
flows/03-tcp-explicit/run.sh         # explicit TCP: ephemeral port + auth token
```

See [flows/README.md](flows/README.md) for prerequisites, environment variables
and troubleshooting.

`vericue-inject` (flow 2) is a **zero-build-change** way to acquire the Runtime:
it preloads a probe that starts the veriCue Runtime *inside* the target process -
the same runtime flow 1 embeds explicitly, loaded a different way. On its
documented configurations - **Linux x64, dynamically linked Qt, Qt major version
matching the package variant** - this is a **supported** path, not a demo: the
same server, the same command surface, the same authentication and the same
licensing you get from embedding. Everything else - a statically linked Qt, other
platforms, setuid/setgid targets, wrapper scripts - is refused before launch by
the launcher's preflight, with the reason; embed `VeriCueServer` there, and in
any build where you want the Runtime compiled out of release binaries. Injection
is **not** a serverless mechanism: veriCue code runs inside your process either
way, injection only changes how it gets there.

## Example applications

Every app except `plain_app` embeds the veriCue Runtime and demonstrates one
feature area. `demo_app` is the host for flows 1 and 3; `plain_app` is the
victim for flow 2.

| App | Toolkit | Shows |
|---|---|---|
| `demo_app` | QWidgets | Embedding: local IPC (`--endpoint`), TCP (`--port`), auth (`--token`) |
| `test_app` | QWidgets | The fixture app used by veriCue's own integration suites |
| `qml_app` | Qt Quick | QML object resolution and interaction |
| `touch_app` | Qt Quick | Touch: tap, long-press, swipe, pinch |
| `table_app` | QWidgets | Model/view data access (`get_model_info`, `get_model_data`) |
| `gl_app` | QOpenGLWidget | OpenGL viewport with an orbit/pan/zoom camera driven by drag/scroll/pinch; camera state exposed as Q_PROPERTYs |
| `plain_app` | QWidgets | Deliberately veriCue-free - the victim app for `vericue-inject` |

## Build

Requires Qt 5.15 or Qt 6.x and an installed veriCue SDK
([download](https://dl.vericue.dev), [installation guide](https://vericue.dev/docs/installation)):

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH="/path/to/Qt/6.7/gcc_64;/path/to/vericue"
cmake --build build --parallel
```

Run an app and talk to it. On Linux/macOS, same machine:

```bash
./build/demo_app/vericue-demo-app --endpoint       # prints VERICUE_ENDPOINT=<path>
pip install vericue
python -m vericue --endpoint <path> inspect
```

Anywhere else, and on Windows:

```bash
./build/gl_app/vericue-gl-app --port 0             # prints VERICUE_PORT=<n>
python -m vericue --port <n> inspect
```

Driving the GL camera from Python:

```python
async with VeriCueClient() as c:
    await c.connect("127.0.0.1", port)                        # or: await c.connect_local(endpoint)
    await c.drag("GLWindow/glViewport", 100, 100, 220, 160)   # orbit
    await c.scroll("GLWindow/glViewport", dy=2)               # zoom in
    print(await c.get_properties("GLWindow/glViewport", ["yaw", "distance"]))
```

Full documentation: https://vericue.dev/docs/

## Note

This repository is also embedded as the `examples/` git submodule of the
main (proprietary) veriCue repository and is built there in-tree as part of
CI. Contributions and issue reports are welcome.

## License

The example code in this repository is MIT-licensed (see LICENSE).
veriCue itself is a commercial product - see https://vericue.dev/docs/licensing/tiers.
