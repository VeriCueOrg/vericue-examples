# Flow 1 - embedded veriCue Runtime on a local IPC endpoint

> **Needs veriCue v0.4.0 or newer**, the current package on
> <https://dl.vericue.dev>. `VeriCueServer::startLocal()` is not in v0.3.5; if
> you are still on it, run [flow 3](../03-tcp-explicit/) - it does the same
> things over TCP.
>
> **Local IPC is supported on Linux and macOS only.** On Windows use TCP.

The production shape of veriCue on a developer machine or a same-host CI runner:
the application starts the veriCue Runtime itself, on a UNIX socket that only
the user running the application can open, with no network presence at all.

The host is the existing `demo_app` - no new example application was added for
this; `--endpoint` simply selects a different transport in the app you already
have.

## What the application does

`demo_app/main.cpp`:

```cpp
vericue::VeriCueServer server(&window);
if (!server.startLocal(opts.endpoint))   // empty path: veriCue picks one
    return 1;
printf("VERICUE_ENDPOINT=%s\n", qUtf8Printable(server.localEndpoint()));
fflush(stdout);
```

`startLocal()` with an empty path resolves a per-process endpoint under the
user's runtime directory (`$XDG_RUNTIME_DIR/vericue/vericue-<pid>.sock`). The
application prints the resolved path; that line is the whole discovery
mechanism - a harness never has to guess a path or a port.

## Run it

```bash
# once
cmake -B build -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH="/path/to/Qt/6.7/gcc_64;/path/to/vericue"
cmake --build build --parallel

flows/01-embedded-local-ipc/run.sh
```

By hand, the same three steps:

```bash
./build/demo_app/vericue-demo-app --endpoint          # prints VERICUE_ENDPOINT=<path>
python -m vericue --endpoint <path> find_object --path DemoMainWindow/centralWidget/okButton
python flows/01-embedded-local-ipc/scenario.py --endpoint <path>
```

In Python the transport is the only thing that changes:

```python
async with VeriCueClient() as client:
    await client.connect_local(endpoint)          # instead of connect(host, port)
    await client.type_text("DemoMainWindow/centralWidget/inputField", "local-ipc")
```

## Verified output

Captured on Linux x64, Qt 6.7.1, `QT_QPA_PLATFORM=offscreen`, veriCue built
from master (post-v0.3.5), trial licensing:

```text
=== Starting .../build/demo_app/vericue-demo-app with an embedded veriCue Runtime on local IPC
Endpoint: /run/user/1000/vericue/vericue-551920.sock
srwx------ 1 turaz turaz 0 sie 14 20:07 /run/user/1000/vericue/vericue-551920.sock

=== CLI over the same endpoint: python -m vericue --endpoint <path> find_object
{
  "address": "0x57544ed4df60",
  "className": "QPushButton",
  "objectName": "okButton",
  "path": "DemoMainWindow/centralWidget/okButton"
}

=== Python client scenario (lookup, interaction, property assertion)
Connected over local IPC: /run/user/1000/vericue/vericue-551920.sock

1. Object lookup
  DemoMainWindow/centralWidget/okButton is a QPushButton
  PASS  okButton class: 'QPushButton'
  PASS  okButton text: 'OK'

2. Interaction: type into the line edit
  PASS  inputField text after typing: 'local-ipc'

3. Interaction: click the checkbox, then verify its property
  PASS  checkbox starts unchecked: False
  PASS  checkbox checked after the click: True

4. Property write and read back
  PASS  progressBar value: 77

Scenario passed

=== Flow 1 finished successfully
```

Note the socket mode: `srwx------`, owner only.
