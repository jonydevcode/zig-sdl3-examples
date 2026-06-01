const std = @import("std");
const sdl = @import("sdl.zig").c;

const Io = std.Io;

pub fn main(init: std.process.Init) void {
    const io = init.io;
    var prng: std.Random.DefaultPrng = .init(123456);
    const rng = prng.random();

    _ = sdl.SDL_SetAppMetadata("Example Renderer Primitives", "1.0", "com.example.renderer-primitives");

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.panic("{s}", .{sdl.SDL_GetError()});
    }
    defer sdl.SDL_Quit();

    std.debug.print("video driver: {s}\n", .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")});

    // Create a window and renderer
    var window: ?*sdl.SDL_Window = null;
    var renderer: ?*sdl.SDL_Renderer = null;
    if (!sdl.SDL_CreateWindowAndRenderer(
        "examples/renderer/primitives",
        640,
        480,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    )) {
        std.debug.panic("{s}", .{sdl.SDL_GetError()});
    }
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    _ = sdl.SDL_SetRenderLogicalPresentation(renderer, 640, 480, sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX);

    // setup some random points
    var points: [500]sdl.SDL_FPoint = undefined;
    for (0..points.len) |i| {
        points[i].x = (rng.float(f32) * 440.0) + 100.0;
        points[i].y = (rng.float(f32) * 280.0) + 100.0;
    }

    // Main loop
    while (true) {
        // Poll events
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            if (event.type == sdl.SDL_EVENT_QUIT) {
                std.process.cleanExit(io);
                return;
            }
        }

        var rect: sdl.SDL_FRect = undefined;

        // as you can see from this, rendering draws over whatever was drawn before it.
        _ = sdl.SDL_SetRenderDrawColor(renderer, 33, 33, 33, sdl.SDL_ALPHA_OPAQUE);
        _ = sdl.SDL_RenderClear(renderer);

        // draw a filled rectangle in the middle of the canvas.
        _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 255, sdl.SDL_ALPHA_OPAQUE); // blue, full alpha
        rect.x = 100;
        rect.y = 100;
        rect.w = 440;
        rect.h = 280;
        _ = sdl.SDL_RenderFillRect(renderer, &rect);

        // draw some points across the canvas.
        _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 0, 0, sdl.SDL_ALPHA_OPAQUE); // red, full alpha
        _ = sdl.SDL_RenderPoints(renderer, &points, points.len);

        // draw a unfilled rectangle in-set a little bit.
        _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 255, 0, sdl.SDL_ALPHA_OPAQUE); // green, full alpha
        rect.x += 30;
        rect.y += 30;
        rect.w -= 60;
        rect.h -= 60;
        _ = sdl.SDL_RenderRect(renderer, &rect);

        // draw two lines in an X across the whole canvas.
        _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 255, 0, sdl.SDL_ALPHA_OPAQUE); // yellow, full alpha
        _ = sdl.SDL_RenderLine(renderer, 0, 0, 640, 480);
        _ = sdl.SDL_RenderLine(renderer, 0, 480, 640, 0);

        _ = sdl.SDL_RenderPresent(renderer);
    }
}
