const std = @import("std");
const sdl = @import("sdl3");
const sdl_adapter = @import("sdl_adapter.zig");
const Game = @import("game.zig");
const Io = std.Io;

const step_rate_in_milliseconds = 125;
const block_size_in_pixels = 24;

const window_width = block_size_in_pixels * Game.game_width;
const window_height = block_size_in_pixels * Game.game_height;

const AppStatus = enum {
    app_continue,
    quit_success,
    quit_failure,
};

const AppState = struct {
    window: *sdl.SDL_Window,
    renderer: *sdl.SDL_Renderer,
    game: Game,
    last_step: u64,
    joystick: ?*sdl.SDL_Joystick,

    pub fn init(
        window: *sdl.SDL_Window,
        renderer: *sdl.SDL_Renderer,
        game: Game,
        last_step: u64,
        joystick: ?*sdl.SDL_Joystick,
    ) AppState {
        return AppState{
            .window = window,
            .renderer = renderer,
            .game = game,
            .last_step = last_step,
            .joystick = joystick,
        };
    }

    pub fn deinit(self: *AppState) void {
        if (self.joystick) |stick| {
            sdl.SDL_CloseJoystick(stick);
        }
    }
};

fn setRectXY(r: *sdl.SDL_FRect, x: f32, y: f32) void {
    r.x = x * @as(f32, @floatFromInt(block_size_in_pixels));
    r.y = y * @as(f32, @floatFromInt(block_size_in_pixels));
}

pub fn handleKeyEvent(game: *Game, key_code: sdl.SDL_Scancode) AppStatus {
    switch (key_code) {
        // quit
        sdl.SDL_SCANCODE_ESCAPE, sdl.SDL_SCANCODE_Q => {
            return .quit_success;
        },
        // restart the game as if the program was launched
        sdl.SDL_SCANCODE_R => {
            game.reset();
        },
        // decide new direction of the snake
        sdl.SDL_SCANCODE_RIGHT => game.setDirection(.right),
        sdl.SDL_SCANCODE_UP => game.setDirection(.up),
        sdl.SDL_SCANCODE_LEFT => game.setDirection(.left),
        sdl.SDL_SCANCODE_DOWN => game.setDirection(.down),
        else => {},
    }
    return .app_continue;
}

pub fn handleHatEvent(game: *Game, hat: u8) AppStatus {
    switch (hat) {
        sdl.SDL_HAT_RIGHT => game.setDirection(.right),
        sdl.SDL_HAT_UP => game.setDirection(.up),
        sdl.SDL_HAT_LEFT => game.setDirection(.left),
        sdl.SDL_HAT_DOWN => game.setDirection(.down),
        else => {},
    }
    return .app_continue;
}

pub fn handleEvent(event: *sdl.SDL_Event, app_state: *AppState) AppStatus {
    switch (event.type) {
        sdl.SDL_EVENT_QUIT => {
            return .quit_success;
        },
        sdl.SDL_EVENT_JOYSTICK_ADDED => {
            if (app_state.joystick == null) {
                app_state.joystick = sdl.SDL_OpenJoystick(event.jdevice.which);
                if (app_state.joystick == null) {
                    std.debug.print("Failed to open joystick ID {d}: {s}\n", .{
                        event.jdevice.which,
                        sdl.SDL_GetError(),
                    });
                }
            }
        },
        sdl.SDL_EVENT_JOYSTICK_REMOVED => {
            if (app_state.joystick) |stick| {
                if (sdl.SDL_GetJoystickID(stick) == event.jdevice.which) {
                    sdl.SDL_CloseJoystick(app_state.joystick);
                    app_state.joystick = null;
                }
            }
        },
        sdl.SDL_EVENT_KEY_DOWN => {
            switch (handleKeyEvent(&app_state.game, event.key.scancode)) {
                .app_continue => {},
                else => return .quit_failure,
            }
        },
        sdl.SDL_EVENT_JOYSTICK_HAT_MOTION => {
            switch (handleHatEvent(&app_state.game, event.jhat.value)) {
                .app_continue => {},
                else => return .quit_failure,
            }
        },
        else => {},
    }
    return .app_continue;
}

pub fn tick(app_state: *AppState) !AppStatus {
    const now = sdl.SDL_GetTicks();
    const renderer = app_state.renderer;

    while ((now - app_state.last_step) >= step_rate_in_milliseconds) {
        if (app_state.game.step() == .game_ends) {
            app_state.game.reset();
        }
        app_state.last_step += step_rate_in_milliseconds;
    }

    var r: sdl.SDL_FRect = undefined;
    r.w = block_size_in_pixels;
    r.h = block_size_in_pixels;
    try sdl_adapter.setRenderDrawColor(renderer, 0, 0, 0, sdl.SDL_ALPHA_OPAQUE);
    try sdl_adapter.renderClear(renderer);

    for (0..Game.game_width) |x| {
        for (0..Game.game_height) |y| {
            const cell = app_state.game.getCell(@intCast(x), @intCast(y));
            if (cell == .nothing)
                continue;
            setRectXY(&r, @floatFromInt(x), @floatFromInt(y));
            if (cell == .food) {
                try sdl_adapter.setRenderDrawColor(renderer, 80, 80, 255, sdl.SDL_ALPHA_OPAQUE);
            } else {
                try sdl_adapter.setRenderDrawColor(renderer, 0, 128, 0, sdl.SDL_ALPHA_OPAQUE);
            }
            try sdl_adapter.renderFillRect(renderer, &r);
        }
    }
    try sdl_adapter.setRenderDrawColor(renderer, 255, 255, 0, sdl.SDL_ALPHA_OPAQUE);
    setRectXY(&r, @floatFromInt(app_state.game.head.x), @floatFromInt(app_state.game.head.y));
    try sdl_adapter.renderFillRect(renderer, &r);
    try sdl_adapter.renderPresent(renderer);
    return .app_continue;
}

pub fn main(init: std.process.Init) !void {
    _ = init;
    var prng: std.Random.DefaultPrng = .init(123456);
    const rng = prng.random();

    try sdl_adapter.setAppMetadata("Example Snake Game", "1.0", "com.example.Snake");

    try sdl_adapter.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_JOYSTICK);
    defer sdl.SDL_Quit();

    std.debug.print(
        "video driver: {s}\n",
        .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")},
    );

    // Create a window and renderer
    var window: *sdl.SDL_Window = undefined;
    var renderer: *sdl.SDL_Renderer = undefined;
    const window_and_renderer = try sdl_adapter.createWindowAndRenderer(
        "examples/demo/snake",
        window_width,
        window_height,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
    );
    window = window_and_renderer.window;
    renderer = window_and_renderer.renderer;
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    try sdl_adapter.setRenderLogicalPresentation(
        renderer,
        window_width,
        window_height,
        sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX,
    );

    var app_state = AppState{
        .game = .init(rng),
        .last_step = sdl.SDL_GetTicks(),
        .renderer = renderer,
        .window = window,
        .joystick = null,
    };
    defer app_state.deinit();

    var done = false;

    // Main loop
    while (!done) {
        // Poll events
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (handleEvent(&event, &app_state)) {
                .quit_failure, .quit_success => done = true,
                else => {},
            }
        }

        const status = try tick(&app_state);
        switch (status) {
            .app_continue => {},
            else => {
                std.debug.print("Ending: {s}\n", .{@tagName(status)});
                done = true;
            },
        }
    }
}
