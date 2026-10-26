from max.gpu import global_idx
from max.gpu.host import DeviceContext
from std.sys import has_accelerator
from std.time import perf_counter_ns

comptime N = 1 << 20


def main() raises:
    print("has_accelerator:", has_accelerator())
    var ctx = DeviceContext()
    print("device:", ctx.name())
    var a = ctx.enqueue_create_buffer[DType.float32](N)
    var b = ctx.enqueue_create_buffer[DType.float32](N)
    var c = ctx.enqueue_create_buffer[DType.float32](N)
    with a.map_to_host() as ha, b.map_to_host() as hb:
        for i in range(N):
            ha[i] = Float32(i)
            hb[i] = Float32(2 * i)
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var pc = c.unsafe_ptr()

    def kernel() register_passable {var pa, var pb, var pc}:
        var i = global_idx.x
        if i < N:
            pc[unsafe_offset=i] = pa[unsafe_offset=i] + pb[unsafe_offset=i]

    var t0 = perf_counter_ns()
    ctx.enqueue_function(kernel, grid_dim=(N + 255) // 256, block_dim=256)
    ctx.synchronize()
    var t1 = perf_counter_ns()
    with c.map_to_host() as hc:
        print("c[12345] =", hc[12345], "(expect", 3 * 12345, ")")
    print("first launch incl. JIT, us:", (t1 - t0) // 1000)
