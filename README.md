# veriCue examples

Example Qt applications instrumented with [veriCue](https://vericue.dev) -
a test automation framework for Qt 5 and Qt 6. Each app embeds the veriCue
server and demonstrates one feature area:

| App | Toolkit | Shows |
|---|---|---|
| `demo_app` | QWidgets | Basic embedding: login form driven by tests |
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

Run any app and talk to it, e.g.:

```bash
./build/gl_app/vericue-gl-app --port 4242 &
pip install vericue
python -m vericue --port 4242 inspect
```

Driving the GL camera from Python:

```python
async with VeriCueClient() as c:
    await c.connect("127.0.0.1", 4242)
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
