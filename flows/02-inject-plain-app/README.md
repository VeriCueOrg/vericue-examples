# Flow 2 - zero-source-change run with `vericue-inject`

> **Needs veriCue v0.4.0 or newer**, the current package on
> <https://dl.vericue.dev>. The local-IPC default of `vericue-inject` and its
> `VERICUE_ENDPOINT=<path>` announcement are not in v0.3.5; on that version drive
> the application over TCP with [flow 3](../03-tcp-explicit/) instead.
>
> **`vericue-inject` is supported on Linux x64, for applications that link Qt
> dynamically, with a Qt major version matching the package variant you
> downloaded.** On those configurations it is a supported way to acquire the
> Runtime, with the same server, the same command surface, the same
> authentication and the same licensing as embedding. It is not available on
> macOS or Windows, and it cannot drive a statically linked Qt - see
> [Compatibility](#compatibility).

## What actually happens

`vericue-inject` preloads `libvericue-inject.so` into the target. During that
library's static initialisation it registers a Qt startup function, which Qt
calls the moment the application constructs its `QApplication`. That function
starts a veriCue Runtime **inside the application process** and prints the
endpoint it is listening on.

So veriCue code runs in the target process - the same code that flow 1 embeds
explicitly, just loaded a different way. Nothing observes the application from
the outside: injection is not a serverless mechanism, it only changes how the
Runtime gets into the process.

The victim is the existing `plain_app`: it has no veriCue include, no veriCue
link and no veriCue code path, and this flow does not change that.

```console
$ ldd build/plain_app/vericue-plain-app | grep -E 'libQt6Core|vericue'
	libQt6Core.so.6 => /home/turaz/Qt/6.7.1/gcc_64/lib/libQt6Core.so.6
```

## Run it

```bash
# once
cmake -B build -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH="/path/to/Qt/6.7/gcc_64;/path/to/vericue"
cmake --build build --parallel

flows/02-inject-plain-app/run.sh
```

By hand:

```bash
vericue-inject -- ./build/plain_app/vericue-plain-app   # prints VERICUE_ENDPOINT=<path>
python flows/02-inject-plain-app/scenario.py --endpoint <path> --screenshot /tmp/plain-app.png
```

If `vericue-inject` is not on `PATH`, point `VERICUE_INJECT` at the `bin/`
script from the package; when running from a build tree also set
`VERICUE_INJECT_LIB` to `libvericue-inject.so`.

The scenario does object discovery, an input, a click, a property check, a
screenshot, and then asks the window to close itself (`invoke_method` on
`close()`) so the process shuts down normally. `run.sh` then checks that the
process is gone **and** that the endpoint has been removed from the filesystem -
a clean shutdown leaves nothing behind. Pass `--keep-running` to the scenario if
you want to keep poking at the application afterwards.

The click is not verified by "the request succeeded": the scenario subscribes to
the button's `clicked()` signal first, and waits for the pushed event. That is
proof the synthesized click reached the real widget.

## Verified output

Captured on Linux x64, Qt 6.7.1, `QT_QPA_PLATFORM=offscreen`, veriCue built
from the v0.4.0 sources, trial licensing:

```text
=== The victim links Qt, but nothing from veriCue
	libQt6Core.so.6 => /home/turaz/Qt/6.7.1/gcc_64/lib/libQt6Core.so.6 (0x000075e523000000)

=== Launching it under .../bin/vericue-inject (local IPC is the default transport)
Endpoint: /run/user/1000/vericue/vericue-552000.sock
srwx------ 1 turaz turaz 0 sie 14 20:07 /run/user/1000/vericue/vericue-552000.sock

=== Python client scenario against the un-instrumented application
Connected over local IPC: /run/user/1000/vericue/vericue-552000.sock

1. Object discovery inside an application with zero veriCue code
  PlainWindow [QMainWindow]
    PlainWindow/_layout [QMainWindowLayout]
    PlainWindow/centralWidget [QWidget]
      PlainWindow/centralWidget/QVBoxLayout#0 [QVBoxLayout]
      PlainWindow/centralWidget/plainInput [QLineEdit]
        PlainWindow/centralWidget/plainInput/QWidgetLineControl#0 [QWidgetLineControl]
      PlainWindow/centralWidget/plainButton [QPushButton]
  PASS  plainButton class: 'QPushButton'

2. Input: type into the line edit, then read the property back
  PASS  plainInput text after typing: 'injected'

3. Click: proven by the button's own clicked() signal
  event: signal_emitted {'args': [], 'signal': 'clicked'} from PlainWindow/centralWidget/plainButton
  PASS  event type: 'signal_emitted'
  PASS  signal that fired: 'clicked'
  PASS  object that emitted it: 'PlainWindow/centralWidget/plainButton'

4. Screenshot of the window
  saved 200x100 PNG to /tmp/vericue-flow-02-plain-app.png
  PASS  screenshot has pixels: True

5. Asking the application to close itself (clean shutdown)
  close() invoked

Scenario passed

=== Clean shutdown: the process exits and the endpoint disappears
Application exited.
Endpoint removed: /run/user/1000/vericue/vericue-552000.sock

=== Flow 2 finished successfully
Screenshot of the un-instrumented application: /tmp/vericue-flow-02-plain-app.png
```

## Compatibility

`vericue-inject` is supported on:

- **Linux x64** - it ships in the Linux packages, and x86-64 is the only
  architecture a Linux package is built, tested and distributed for.
- targets that link Qt **dynamically** (`libQt5Core.so` / `libQt6Core.so`).
- a target **Qt major version matching the package variant** you downloaded (a
  Qt 6 probe will not attach to a Qt 5 application).

Everything else is **refused before launch** by the launcher's preflight, with
the reason and a corrective action, rather than failing inside your application:
a statically linked Qt (there is no dynamic loader step to preload into),
platforms other than Linux x64, set-user-ID / set-group-ID binaries (the loader
drops `LD_PRELOAD` for them), and wrapper scripts (nothing about the binary they
eventually exec can be checked from the script). Run
`vericue-inject --check -- ./your-qt-app` to get the whole preflight report
without starting anything.

Embedding `VeriCueServer` - flow 1 (local IPC) or flow 3 (TCP) - is the fallback
in all of those cases, and the setup to pick when you want the Runtime compiled
out of release builds, or an explicit start-up with no dependency on
`LD_PRELOAD`. Both are supported; pick per situation. The full matrix is in
[Zero-source-change runs](https://vericue.dev/docs/guides/injector).
