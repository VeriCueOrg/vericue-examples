# Flow 4 - `vericue run` and `vericue inspect` on an existing application

The flow to start with. An application with **no veriCue code in it** is launched
with the Runtime inside, and driven from a normal Python test.

```bash
flows/04-run-and-inspect-existing-app/run.sh
```

## What it demonstrates

```bash
vericue run ./vericue-plain-app        # automate it
vericue inspect ./vericue-plain-app    # find elements, copy their paths
```

`plain_app` is the target on purpose: no veriCue include, no veriCue link, no
veriCue code path. Nothing about it changes for this flow - `ldd` on it shows Qt
and no veriCue at all, which the script prints before it starts.

The scenario then does what a real test does: find an element by path, ask what
that element supports, type into a field and read the property back, click and
prove the click arrived by the widget's own `clicked()` signal, take a
screenshot, and close the application cleanly.

`--announce` writes the endpoint to a file, so the script never parses the
application's stdout. Your application may print whatever it likes.

## `vericue inspect` is where the paths come from

The Inspector opens the same application, lets you point at an element, and
shows its canonical path plus the code that drives it in Python, C++ and C#.
This flow runs unattended, so it uses those paths directly instead of opening a
window - but that is where `PlainWindow/centralWidget/plainButton` came from.

The Inspector is a **separate application in its own process**. Its package
carries its own Qt so it runs on a machine with no Qt installed. That Qt never
enters the application under test.

## What your application must provide

The Runtime uses **your application's Qt** - veriCue does not bring a second Qt
into your process, and you should never copy veriCue's Qt libraries into your
deployment to make this work.

| Module | Needed |
|---|---|
| Qt Core, Qt Gui, **Qt Network** | always - QtNetwork included, even if your application never uses it: the Runtime links it for its own transport |
| Qt Widgets | only if your application already uses it |
| Qt Quick | only if your application already uses it |

The two toolkit backends load only when the module is already in the process, so
a Widgets application never gains a Qt Quick dependency from veriCue, and a QML
application never gains QtWidgets.

## Where this works

| | |
|---|---|
| **Linux x64** | supported, on documented dynamically linked Qt configurations. Local IPC by default |
| **Windows x64** | supported, on documented normal-import dynamically linked Qt configurations. **TCP only** |
| **macOS** | no injection path - [embed the Runtime](../01-embedded-local-ipc) instead |

This flow script runs the Linux path. Compatibility is decided by a preflight
before anything starts, and refused with a diagnosis rather than failing inside
your application.

## Requirements

- the veriCue Python client **v0.5.0 or newer** (`pip install -U vericue`) -
  that is where `vericue run` arrived. The script checks and says so.
- the veriCue package on `$PATH` / `$VERICUE_HOME` so the launcher can find the
  Runtime.

## The layer underneath

[Flow 2](../02-inject-plain-app) drives `bin/vericue-inject` directly. It is the
same mechanism `vericue run` uses on Linux and remains supported - useful when
you want the launcher's own flags, or when you are not installing the Python
client at all.
