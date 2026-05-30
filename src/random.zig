//! Shows 4 ways to generate random numbers in Zig.
//! For game development, the Hybrid approach is probably best.
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // Using Random.IoSource (cryptographically secure)
    var rng_source: std.Random.IoSource = .{ .io = io };
    const rng = rng_source.interface();
    const f1: f64 = rng.float(f64);
    const f2: f32 = rng.float(f32);
    std.debug.print("Using Random.IoSource: {}, {}\n", .{ f1, f2 });

    // Using Prng
    var prng_default: std.Random.DefaultPrng = .init(12345);
    const prng = prng_default.random();
    const f3: f64 = prng.float(f64);
    const f4: f32 = prng.float(f32);
    std.debug.print("Using Random.DefaultPrng(12345): {}, {}\n", .{ f3, f4 });

    // Hybrid - secure entropy to seed a Prng
    var seed: u64 = undefined;
    try io.randomSecure(std.mem.asBytes(&seed));
    var prng_seeded: std.Random.DefaultPrng = .init(seed);
    const prng2 = prng_seeded.random();
    const f5: f64 = prng2.float(f64);
    const f6: f32 = prng2.float(f32);
    std.debug.print("Using Random.DefaultPrng({d}): {}, {}\n", .{ seed, f5, f6 });

    // Csprng - slower than prng but cryptographically secure
    var csprng_seed: [std.Random.DefaultCsprng.secret_seed_length]u8 = undefined;
    try io.randomSecure(&csprng_seed);
    var csprng: std.Random.DefaultCsprng = .init(csprng_seed);
    const rng_csprng = csprng.random();
    const f7: f64 = rng_csprng.float(f64);
    const f8: f32 = rng_csprng.float(f32);
    std.debug.print("Using Random.DefaultCsprng: {}, {}\n", .{ f7, f8 });
}
