"""Benchmark: `dodo.json` loads (simdjson) and dumps.

Build and run from the repo root:
    pixi run mojo build -I . -O3 research/json-bench/bench_json.mojo -o /tmp/bench_json
    /tmp/bench_json
"""

from std.time import perf_counter_ns

import dodo.json as json

comptime RUNS = 9


def small_payload() -> String:
    var s = String('{"id": 4182, "user": "alice.smith", "email": "alice@example.com", ')
    s += '"active": true, "plan": "pro", "tags": ["a", "bb", "ccc", 4, 5], '
    s += '"note": "hello \\"world\\"", "score": 12}'
    return s^


def medium_payload() -> String:
    var s = String('{"id": 1, "items": [')
    var i = 0
    while i < 95:
        if i > 0:
            s += ", "
        s += '{"id": ' + String(i) + ', "name": "item number ' + String(i)
        s += '", "price": ' + String(i) + ".25, "
        s += '"ok": true, "tags": ["x", "y"]}'
        i += 1
    s += "]}"
    return s^


def large_payload() -> String:
    var s = String('{"id": 1, "items": [')
    var i = 0
    while i < 6500:
        if i > 0:
            s += ", "
        s += '{"id": ' + String(i * 7919) + ', "name": "record number ' + String(i)
        s += ' with some text \\u00e9\\n", "price": ' + String(i) + ".3125, "
        s += '"ratio": ' + String(i) + ".123456789e-3, "
        s += '"ok": ' + ("true" if i % 2 == 0 else "false") + ", "
        s += '"nested": {"a": [1, 2, 3, ' + String(i) + '], "b": {"c": "deep", "d": null}}}'
        i += 1
    s += "]}"
    return s^


def median(mut times: List[Float64]) -> Float64:
    # Insertion sort; the list has only a handful of entries.
    var n = len(times)
    for i in range(1, n):
        var key = times[i]
        var j = i - 1
        while j >= 0 and times[j] > key:
            times[j + 1] = times[j]
            j -= 1
        times[j + 1] = key
    return times[n // 2]


def iterations_for(size: Int) -> Int:
    # About 20 MB of work per run, at least 2 iterations.
    var n = 20_000_000 // size
    if n < 2:
        return 2
    return n


def report(
    payload: String, label: String, op: String, ns_per_op: Float64, size: Int
):
    var mb_per_s = Float64(size) * 1000.0 / ns_per_op
    print(payload, label, op, Int(ns_per_op), "ns/op", Int(mb_per_s), "MB/s")


def bench_loads(text: String, iters: Int) raises -> Float64:
    var times = List[Float64]()
    var sink = 0
    for run in range(RUNS + 1):
        var start = perf_counter_ns()
        for _ in range(iters):
            var v = json.loads(text.copy())
            sink += Int(v["id"].int_value())
        var elapsed = perf_counter_ns() - start
        if run > 0:
            times.append(Float64(elapsed) / Float64(iters))
    if sink == 0:
        print("sink")
    return median(times)


def bench_dumps(text: String, iters: Int) raises -> Float64:
    var value = json.loads(text.copy())
    var times = List[Float64]()
    var sink = 0
    for run in range(RUNS + 1):
        var start = perf_counter_ns()
        for _ in range(iters):
            sink += json.dumps(value).byte_length()
        var elapsed = perf_counter_ns() - start
        if run > 0:
            times.append(Float64(elapsed) / Float64(iters))
    if sink == 0:
        print("sink")
    return median(times)


def bench_payload(name: String, text: String) raises:
    var size = text.byte_length()
    var iters = iterations_for(size)
    print("--", name, "bytes:", size, "iters/run:", iters)
    report(name, "dodo", "loads", bench_loads(text, iters), size)
    report(name, "dodo", "dumps", bench_dumps(text, iters), size)


def main() raises:
    bench_payload("small", small_payload())
    bench_payload("medium", medium_payload())
    bench_payload("large", large_payload())
