#!/usr/bin/env bash
# 4-worker probe suite plus wrk load tests against probe_server.
# Run from WSL: bash /mnt/e/dodo/research/flare-audit/run_w4_and_load.sh
cd ~/flare-audit
cp /mnt/e/dodo/research/flare-audit/*.py .
WRK=~/src/flare/.pixi/envs/bench/bin/wrk
ulimit -n 65536

wait_up() {
  for i in $(seq 1 60); do
    if python3 -c "import socket;socket.create_connection(('127.0.0.1',8099),timeout=1)" 2>/dev/null; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

server_stat() {
  local alive="NO"
  if kill -0 "$SP" 2>/dev/null; then
    alive="yes"
  fi
  echo "server alive: $alive rss_kb=$(ps -o rss= -p "$SP") fds=$(ls /proc/$SP/fd 2>/dev/null | wc -l)"
}

fuzz() {
  # Wait on the fuzzers only. A bare `wait` would also wait on the server.
  local pids=""
  for s in 41 42 43 44; do
    python3 -u net_fuzz.py 2500 "$s" > "fuzz_4_$s.txt" 2>&1 &
    pids="$pids $!"
  done
  wait $pids
  tail -q -n 3 fuzz_4_*.txt
}

{
  echo "################ workers=4"
  ./probe_server 4 > server_4.log 2>&1 &
  SP=$!
  wait_up || echo "SERVER DID NOT START"
  python3 -u probe.py
  python3 -u extra_probes.py
  python3 -u rst.py
  python3 -u probe2.py
  fuzz
  server_stat
  echo "--- server log tail"
  tail -5 server_4.log
  kill "$SP"
  sleep 2
} > results_w4.txt 2>&1

{
  for w in 1 4; do
    echo "################ load, workers=$w"
    ./probe_server "$w" > "server_load_$w.log" 2>&1 &
    SP=$!
    wait_up || echo "SERVER DID NOT START"
    server_stat
    for c in 1 10 50 1000; do
      t=$c
      if [ "$t" -gt 8 ]; then
        t=8
      fi
      echo "--- c=$c"
      "$WRK" -t"$t" -c"$c" -d15s --latency http://127.0.0.1:8099/ | grep -E "Requests/sec|Latency|50%|99%|errors|Socket"
    done
    server_stat
    kill "$SP"
    sleep 2
  done
} > results_load.txt 2>&1

cp results_w4.txt results_load.txt fuzz_4_*.txt server_4.log /mnt/e/dodo/research/flare-audit/
echo done
