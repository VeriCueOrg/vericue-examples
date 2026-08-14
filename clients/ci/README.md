# CI and report artifacts

[`run.sh`](run.sh) is the whole flow: start `demo_app`, discover the endpoint
it announces, run the [Python scenario](../python/) with the reporter that
ships in the `vericue` pytest plugin, and leave the artifacts in one directory.

```bash
clients/ci/run.sh
```

```
artifacts/
├── junit.xml             pytest's own JUnit XML (--junitxml)
├── vericue-report.xml    veriCue's JUnit XML   (the shipped pytest plugin)
├── vericue-report.html   veriCue's HTML report (the shipped pytest plugin)
└── demo_app-python.png   the screenshot captured by the scenario
```

Both XML files are JUnit format - take whichever your CI already ingests;
they are produced by two independent reporters so you can compare them. The
HTML report is the human-readable one: per-test status, durations and, for a
failure, the failure text.

All four files are written whether the run passed or failed, and the script
exits with pytest's status, so a job that runs it fails when the scenario
fails and still has the evidence to upload.

| Variable | Meaning |
|---|---|
| `VERICUE_ARTIFACT_DIR` | where everything is written (default: `clients/ci/artifacts`, wiped at the start of each run) |
| `VERICUE_TRANSPORT` | `local` (default) or `tcp` - `tcp` is the one to use on Windows or when the tests are not on the application's machine |
| `VERICUE_DEMO_APP` | use a specific `demo_app` binary |
| `PYTHON` | interpreter that can `import vericue` |

## Why the GitHub Actions workflow is manual

[`../../.github/workflows/client-scenarios.yml`](../../.github/workflows/client-scenarios.yml)
runs exactly this script on `ubuntu-latest` and uploads the artifact
directory, but it is triggered by `workflow_dispatch` only.

The reason is `dl.vericue.dev`. It sits behind a Cloudflare managed challenge,
and a GitHub-hosted runner is challenged, so the download fails before
anything is built. Measured from `ubuntu-latest` on 2026-08-14:

```
$ curl -sS -o /dev/null -D - https://dl.vericue.dev/v0.4.0/vericue-0.4.0-qt5.15-linux-x64.tar.gz
HTTP/2 403
cf-mitigated: challenge
server: cloudflare
```

The same answer comes back for the Qt 6 tarball, for `install.sh`, and with a
browser user agent. The identical request from a developer machine succeeds -
this is about where the request comes from, not about authentication, and
nothing in this repository can work around it.

Everything else the job needs is public and was verified on the same runner:
Ubuntu 24.04 provides `qtbase5-dev` 5.15.13, and
`pip install vericue==0.4.0 pytest pytest-asyncio` installs and imports
cleanly. No secrets and no licence file are involved: the veriCue Runtime
falls back to its built-in 30-day trial, and a fresh runner starts a fresh
one.

So the workflow is checked in, complete and honest about when it works:

- run it on a **self-hosted runner** (or any runner that can reach
  `dl.vericue.dev`) with *Run workflow*;
- or pass **`sdk_url`** pointing at your own mirror of the release tarball -
  the one input the workflow takes;
- or just run `clients/ci/run.sh` locally, which is where it was verified.
