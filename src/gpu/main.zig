const std = @import("std");
const sdl = @import("sdl");
const sdlx = @import("sdlx.zig");
const SdlGpu = @import("SdlGpu.zig");
const RGBA = SdlGpu.RGBA;

// This demo uses a simulated CHIP-8 screen
const chip8_screen_width = 64;
const chip8_screen_height = 32;
const chip8_screen_pixels = chip8_screen_width * chip8_screen_height;
var chip8_screen = [_]bool{false} ** chip8_screen_pixels;

// How big each CHIP-8 screen pixel should be on the display
const window_scale = 10;

// How often to move the hot pixel in milliseconds
const update_interval_ms = 16;
const update_interval_ns = update_interval_ms * 1_000_000;

// `chip8_frame` is the RGBA representation of the CHIP-8 screen
pub const black = RGBA{ .r = 0, .g = 0, .b = 0, .a = 0 };
pub const white = RGBA{ .r = 255, .g = 255, .b = 255, .a = 255 };
var chip8_frame = [_]RGBA{black} ** chip8_screen_pixels;

fn setHotPixel(screen: []bool, index: usize) void {
    @memset(screen, false);
    screen[index] = true;
}

fn buildRGBAFrame(source_screen: []bool, dest_frame: []RGBA) void {
    for (source_screen, 0..) |p, i| {
        const color = if (p) white else black;
        dest_frame[i] = color;
    }
}

const EventResult = enum { app_continue, app_quit };

/// Effectively to capture ESCAPE to quit
fn handleEvent(event: *sdl.SDL_Event) EventResult {
    switch (event.type) {
        sdl.SDL_EVENT_QUIT => return .app_quit,
        sdl.SDL_EVENT_KEY_DOWN => {
            switch (event.key.scancode) {
                sdl.SDL_SCANCODE_ESCAPE => return .app_quit,
                else => {},
            }
        },
        else => {},
    }
    return .app_continue;
}

pub fn main() !void {
    try sdlx.check("SDL_Init", sdl.SDL_Init(sdl.SDL_INIT_VIDEO));
    defer sdl.SDL_Quit();

    sdlx.printVersionToDebug();

    const window = sdl.SDL_CreateWindow(
        "SDL3 GPU API Test",
        chip8_screen_width * window_scale,
        chip8_screen_height * window_scale,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
    ) orelse return sdlx.die("SDL_CreateWindow");
    defer sdl.SDL_DestroyWindow(window);

    var sdlgpu = try SdlGpu.init(window, chip8_screen_width, chip8_screen_height, &chip8_frame);
    defer sdlgpu.deinit();

    var hot_index: usize = 0;
    var needs_present = true;
    var next_update_ns: u64 = sdl.SDL_GetTicksNS() + update_interval_ns;
    var running = true;

    while (running) {
        var event: sdl.SDL_Event = undefined;
        var now = sdl.SDL_GetTicksNS();
        if (!needs_present and now < next_update_ns) {
            const sleep_ns = next_update_ns - now;
            const timeout_ms: i32 = if (sleep_ns / 1_000_000 >= 1) @intCast(sleep_ns / 1_000_000) else 1;

            if (sdl.SDL_WaitEventTimeout(&event, timeout_ms)) {
                switch (handleEvent(&event)) {
                    .app_continue => {},
                    .app_quit => running = false,
                }
            }
        }

        // Drain all pending events
        while (sdl.SDL_PollEvent(&event)) {
            switch (handleEvent(&event)) {
                .app_continue => {},
                .app_quit => running = false,
            }
        }

        now = sdl.SDL_GetTicksNS();
        if (now >= next_update_ns) {
            hot_index = (hot_index + 1) % chip8_screen_pixels;
            setHotPixel(chip8_screen[0..], hot_index);
            buildRGBAFrame(&chip8_screen, &chip8_frame);
            sdlgpu.markFramebufferDirty();
            needs_present = true;
            // skip ahead of now by `update_interval_ns`
            while (now >= next_update_ns) {
                next_update_ns = now + update_interval_ns;
            }
        }

        if (needs_present) {
            try sdlgpu.present();
            needs_present = false;
        }
    }

    // Wait for the GPU to finish any queued work.
    try sdlgpu.waitForGPUIdle();
}
