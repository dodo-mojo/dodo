# Lightbug audit harness

The scripts behind [docs/lightbug-audit.md](../../docs/lightbug-audit.md). Run them inside WSL against Lightbug `v26.2.0` (Mojo 0.26.2).

```bash
git clone https://github.com/Lightbug-HQ/lightbug_http ~/src/lightbug_http
cd ~/src/lightbug_http && pixi install -e unit-tests
pixi run -e unit-tests mojo build -I . /path/to/probe_server.mojo -o probe_server
./probe_server &          # listens on 127.0.0.1:8099
python3 probe.py          # 26 malformed/edge-case requests
python3 probe2.py         # slow client, disconnects, 50x40 concurrency
python3 rst.py            # resets before accept (crashes Lightbug)
pixi run -e unit-tests mojo build -g -D ASSERT=all -I . /path/to/fuzz.mojo -o fuzz && ./fuzz
```

These probes become dodo's regression suite, with the expected status codes listed in the design doc.
