# veriCue examples

Example Qt applications and runnable end-to-end flows for
[veriCue](https://vericue.dev) - a test automation framework for Qt 5 and Qt 6.

```bash
vericue run ./MyApplication        # automate an existing application
vericue inspect ./MyApplication    # find elements and copy their paths
```

On supported dynamically linked Qt applications that needs **no source change
and no rebuild** - start with
[flows/04-run-and-inspect-existing-app](flows/04-run-and-inspect-existing-app/).
Where injection is unsuitable or unsupported (macOS, statically linked Qt), the
Runtime is **embedded** in your own build instead; same server, same protocol,
same commands.

veriCue code runs as the **veriCue Runtime** inside your Qt application, however
it got there. Clients (Python, C++, C#) connect to it over one of two
transports:

- **local IPC** - a user-private UNIX socket, no network presence. Supported on
  **Linux and macOS**. The right choice when the tests run on the same machine
  as the application.
- **TCP** - reachable from other hosts. The choice for another host, a
  container or a device, and **the transport to use on Windows**, where local
  IPC is not supported.

Both speak the identical protocol and enforce the identical authentication and
licensing rules, so a scenario is written once and runs over either.

## Which release each flow needs

The current package is whatever <https://dl.vericue.dev/latest> names - the same
marker `install.sh` reads. Install it with `curl -fsSL https://dl.vericue.dev/install.sh | sh`
and the Python client with `pip install -U vericue`.

| Flow | Transport | Needs |
|---|---|---|
| [flows/04-run-and-inspect-existing-app](flows/04-run-and-inspect-existing-app/) | local IPC via `vericue run` | client **0.5.0+** (that is where `vericue run` arrived) |
| [flows/01-embedded-local-ipc](flows/01-embedded-local-ipc/) | local IPC | 0.4.0+ |
| [flows/02-inject-plain-app](flows/02-inject-plain-app/) | local IPC via `bin/vericue-inject` | 0.4.0+ |
| [flows/03-tcp-explicit](flows/03-tcp-explicit/) | TCP | any |

Nothing breaks quietly: each flow checks what it needs and says which version
adds it. On 0.3.5, flow 3 is the one that runs.

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

## Client scenarios - the same test from every SDK

[`clients/`](clients/) takes over where a flow ends: an endpoint exists, now
drive the UI from a real test runner. One small scenario against `demo_app` -
address an object, type into it, click a checkbox, assert the state changed,
capture a screenshot - written once per shipped SDK, plus the CI flow that
turns it into report artifacts.

```bash
clients/python/run.sh    # pytest         (clients/python/test_demo_scenario.py)
clients/cpp/run.sh       # GoogleTest     (clients/cpp/demo_scenario_test.cpp)
clients/csharp/run.sh    # xUnit          (clients/csharp/DemoScenarioTests.cs)
clients/ci/run.sh        # JUnit XML + the veriCue HTML report + the screenshot
```

Each of the three runs over **both** transports: the script starts `demo_app`
once with `--endpoint` and once with `--port 0 --token <random>`, and the
scenario picks up `VERICUE_ENDPOINT` or `VERICUE_HOST`/`VERICUE_PORT`/
`VERICUE_TOKEN` from the environment. See [clients/README.md](clients/README.md)
for the step-by-step comparison, prerequisites and the artifact layout.

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
