# Flow 2 - zero-build-change evaluation with `vericue-inject`

> **Needs a veriCue build newer than v0.3.5.** The local-IPC default of
> `vericue-inject` and its `VERICUE_ENDPOINT=<path>` announcement are not in the
> v0.3.5 package on <https://dl.vericue.dev>. With v0.3.5, evaluate over TCP
> with [flow 3](../03-tcp-explicit/) instead.
>
> **`vericue-inject` is an evaluation tool for Linux x64 applications that link
> Qt dynamically.** It is not a production deployment model, it is not
> available on macOS or Windows, and it cannot drive a statically linked Qt.

## What actually happens

`vericue-inject` preloads `libvericue-inject.so` into the target. During that
library's static initialisation it registers a Qt startup function, which Qt
calls the moment the application constructs its `QApplication`. That function
starts a veriCue Runtime **inside the application process** and prints the
endpoint it is listening on.

So veriCue code runs in the target process - the same code that flow 1 embeds
explicitly, just loaded a different way. Nothing observes the application from
the outside.

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
from master (post-v0.3.5), trial licensing:

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

## When to stop injecting

Injection is for the first hour: point it at an application nobody wants to
rebuild and see whether veriCue can drive it. For a test suite you keep, embed
`VeriCueServer` as in flow 1 (local IPC) or flow 3 (TCP) - explicit start-up,
explicit transport, explicit token, and no dependency on `LD_PRELOAD`.
