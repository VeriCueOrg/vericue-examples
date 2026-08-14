# The same scenario, from every veriCue SDK

One small scenario against one example application - [`demo_app`](../demo_app/) -
written three times, once per shipped client SDK, plus the CI flow that turns
it into report artifacts.

| | Runner | Files | Run it |
|---|---|---|---|
| [Python](python/) | pytest | [`test_demo_scenario.py`](python/test_demo_scenario.py), [`conftest.py`](python/conftest.py) | `clients/python/run.sh` |
| [C++](cpp/) | GoogleTest | [`demo_scenario_test.cpp`](cpp/demo_scenario_test.cpp), [`CMakeLists.txt`](cpp/CMakeLists.txt) | `clients/cpp/run.sh` |
| [C#](csharp/) | xUnit | [`DemoScenarioTests.cs`](csharp/DemoScenarioTests.cs), [`VeriCue.Examples.DemoScenario.csproj`](csharp/VeriCue.Examples.DemoScenario.csproj) | `clients/csharp/run.sh` |
| [CI / reporting](ci/) | pytest + the shipped reporter | [`ci/run.sh`](ci/run.sh), [workflow](../.github/workflows/client-scenarios.yml) | `clients/ci/run.sh` |

The [`flows/`](../flows/) directory answers a different question: how the
veriCue Runtime is started and reached (local IPC, injection, TCP). These
scenarios start where a flow ends - an endpoint exists, now drive the UI from
a real test runner.

## The scenario

Four steps, identical in all three languages, against widgets that
[`demo_app/main.cpp`](../demo_app/main.cpp) gives explicit object names to -
which is what makes the paths stable:

| Step | Command | Assertion |
|---|---|---|
| 1. address an object | `find_object` on `DemoMainWindow/centralWidget/enableCheck` | it resolves, and it is a `QCheckBox` |
| 2. type into an input | `set_property` (clear), `type_text`, `get_properties` | `inputField.text == "vericue"` |
| 3. click and check the state changed | `get_properties`, `mouse_click`, `get_properties` | `enableCheck.checked` flipped |
| 4. capture evidence | `screenshot` | valid PNG, written to the artifact directory |

Step 3 asserts against the value read *before* the click rather than a
hard-coded `true`, so the test is independent of the order it runs in and of
anything that ran before it. Step 4 exists because a screenshot is what makes
a failed CI run diagnosable - the same call is what you would hook to a test
failure in your own suite.

## Connection: no hard-coded ports, no hard-coded transport

Every scenario reads its connection from the environment, using the same
variable names in all three SDKs (they are also the ones the shipped
GoogleTest fixture already used):

| Variable | Meaning |
|---|---|
| `VERICUE_ENDPOINT` | local IPC socket path - takes precedence when set |
| `VERICUE_HOST`, `VERICUE_PORT` | TCP |
| `VERICUE_TOKEN` | authentication token (required for TCP here, optional on local IPC) |
| `VERICUE_ARTIFACT_DIR` | where screenshots/reports are written (default: `artifacts/` next to the scenario) |

Each `run.sh` starts `demo_app` twice - once with `--endpoint` (local IPC) and
once with `--port 0 --token <fresh random token>` (TCP) - reads the
`VERICUE_ENDPOINT=` / `VERICUE_PORT=` line the application prints, and runs the
same scenario against both. Nothing sleeps and nothing guesses a port. Set
`VERICUE_TRANSPORTS=tcp` (or `local`) to run only one.

SDK support for the two transports as of **v0.4.0**:

| SDK | local IPC | TCP |
|---|---|---|
| Python | `connect_local(endpoint, token=...)` | `connect(host, port, token=...)` |
| C++ | `VeriCueClient::connectToLocalServer(endpoint, token)` | `connectToServer(host, port, token)`, and the shipped `vericue::VeriCueTest` fixture |
| C# | `ConnectLocalAsync(endpoint, token)` | `ConnectAsync(host, port, token)` |

The one asymmetry worth knowing about: the GoogleTest fixture shipped in
`<vericue/gtest_fixture.h>` connects over TCP only. The C++ example therefore
carries a second, ~40-line fixture built directly on `VeriCueClient` for the
local endpoint, and runs the identical scenario steps through both. Local IPC
is Linux/macOS only in any SDK; on Windows use TCP.

## Prerequisites

1. Qt 5.15 or Qt 6.x, and **veriCue v0.4.0** (<https://dl.vericue.dev>).
2. The example applications built once (from the repository root):

   ```bash
   cmake -B build -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_PREFIX_PATH="/path/to/Qt/6.7/gcc_64;/path/to/vericue"
   cmake --build build --parallel
   ```

3. Per SDK:
   - Python: `pip install vericue pytest pytest-asyncio`
   - C++: a C++17 compiler and CMake. GoogleTest is used from the system if
     installed, otherwise `clients/cpp/CMakeLists.txt` fetches v1.14.0 (needs
     network on the first configure).
   - C#: the .NET 8 SDK. The client comes from NuGet
     (`dotnet add package VeriCue`); `clients/csharp/run.sh` restores it.
4. A veriCue licence, or the built-in 30-day trial. The trial allows one
   automation session at a time - which is why each scenario shares one
   connection across its test cases instead of reconnecting per test. A run
   that fails with error 1009 or 1010-1012 is a licensing answer, not a bug in
   the example.

Point `CMAKE_PREFIX_PATH` at Qt and veriCue for the C++ scenario too, and put
your Qt `lib/` and the veriCue `lib/` on `LD_LIBRARY_PATH` when they are not
installed system-wide:

```bash
export CMAKE_PREFIX_PATH="$HOME/Qt/6.7.1/gcc_64;/opt/vericue"
export LD_LIBRARY_PATH="$HOME/Qt/6.7.1/gcc_64/lib:/opt/vericue/lib"
clients/cpp/run.sh
```

## Headless

The `run.sh` scripts fall back to `QT_QPA_PLATFORM=offscreen` when no display
is present, and that is how these examples were verified on Linux. Treat it as
what it is - one environment-specific configuration that works for these
QWidget applications. Other stacks (Qt Quick with a real scene graph, OpenGL,
platform plugins that need a compositor) may need a real display or an X server
such as `xvfb-run -a`; a screenshot taken offscreen is also not necessarily
pixel-identical to one taken on a desktop. Nothing here is a promise that every
Qt application renders without a display server.

## CI and report artifacts

[`clients/ci/run.sh`](ci/) runs the Python scenario with the reporter that
ships in the `vericue` pytest plugin and leaves four files in one directory:

```
junit.xml             pytest's own JUnit XML
vericue-report.xml    veriCue's JUnit XML
vericue-report.html   veriCue's HTML report
demo_app-python.png   the screenshot captured by step 4
```

They are written whether the run passed or failed - a failing run is exactly
when they matter - and the script exits with pytest's status.

[`.github/workflows/client-scenarios.yml`](../.github/workflows/client-scenarios.yml)
does the same on `ubuntu-latest` and uploads that directory as a build
artifact, but it is **manual (`workflow_dispatch`), not run on every public
PR**: `dl.vericue.dev` sits behind a Cloudflare managed challenge and answers
`403` (`cf-mitigated: challenge`) to GitHub-hosted runners, so the SDK cannot
be downloaded there. See [`ci/README.md`](ci/) for the measurement and the
ways around it. The flow itself needs no secrets and no licence file.
