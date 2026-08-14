# Flow 3 - explicit TCP, ephemeral port, authenticated

> **Runs on every released version.** It uses no local IPC, so it is also the
> only flow available on the legacy v0.3.5 package.

TCP has not been replaced by local IPC - it is the transport for every case
where the client is not on the same machine as the application:

- a test runner on another host, or in another container;
- an application running on a device on the bench;
- **Windows**, where local IPC is not supported.

## What the application does

`demo_app/main.cpp`:

```cpp
vericue::VeriCueServer server(&window);
server.setAuthToken(opts.token);        // required in the client handshake
if (!server.start(opts.port))           // --port 0: the OS picks a free port
    return 1;
printf("VERICUE_PORT=%d\n", server.serverPort());
fflush(stdout);
```

Two habits worth copying:

- **Do not hard-code a port.** `start(0)` binds an ephemeral port and
  `serverPort()` reports the real one, which the app prints as
  `VERICUE_PORT=<n>`. Parallel jobs on one machine stop colliding, and no
  harness has to keep a port registry. Use a fixed port only when something
  outside the process has to reach a known address - a container port mapping,
  a device on a fixed address - and then it is a deliberate choice.
- **Always set a token on TCP.** The port is reachable by anything that can
  route to the host, and the protocol drives the UI, reads properties and takes
  screenshots. The flow generates a fresh random token per run; the scenario
  first shows an unauthenticated client being refused, then does real work with
  the token. Never commit a token, and pass it through your CI secret store.

Containers and other hosts additionally need the port published and the address
reachable - for example `docker run -p 4242:4242` with the application started
as `--port 4242`, which is the case where a fixed port is the right answer.

## Run it

```bash
# once
cmake -B build -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH="/path/to/Qt/6.7/gcc_64;/path/to/vericue"
cmake --build build --parallel

flows/03-tcp-explicit/run.sh
```

By hand:

```bash
TOKEN=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
./build/demo_app/vericue-demo-app --port 0 --token "$TOKEN"   # prints VERICUE_PORT=<n>
python -m vericue --port <n> --token "$TOKEN" ping
python flows/03-tcp-explicit/scenario.py --port <n> --token "$TOKEN"
```

From another host, add `--host <address>` on the client side - nothing else in
the scenario changes.

## Verified output

Captured on Linux x64, Qt 6.7.1, `QT_QPA_PLATFORM=offscreen`, trial licensing:

```text
=== Starting .../build/demo_app/vericue-demo-app on an ephemeral TCP port, token required
Port: 32991 (chosen by the OS, announced by the application)

=== CLI over TCP: python -m vericue --port <n> --token <token> ping
{
  "pong": true
}

=== Python client scenario (auth refusal, lookup, interaction, assertion)
1. A TCP port is reachable by anything that can route to this host,
   so the port is useless without the token:
  PASS  rejected without a token: error 1008 ([1008] Invalid authentication token)

2. Authenticated over TCP: 127.0.0.1:32991

3. Object lookup
  PASS  enableCheck class: 'QCheckBox'

4. Interaction and property assertion
  PASS  inputField text after typing: 'over-tcp'
  PASS  checkbox checked after the click: True

Scenario passed

=== Flow 3 finished successfully
```
