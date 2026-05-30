const std = @import("std");
const sdl = @import("sdl3");
const Io = std.Io;

const step_rate_in_milliseconds = 125;
const block_size_in_pixels = 24;

const game_width = 24;
const game_height = 18;
const matrix_size = game_width * game_height;

const window_width = block_size_in_pixels * game_width;
const window_height = block_size_in_pixels * game_height;

fn setRectXY(r: *sdl.SDL_FRect, x: f32, y: f32) void {
    r.x = x * @as(f32, @floatFromInt(block_size_in_pixels));
    r.y = y * @as(f32, @floatFromInt(block_size_in_pixels));
}

fn wrapInc(val: usize, max: usize) usize {
    return if (val + 1 >= max) 0 else val + 1;
}

fn wrapDec(val: usize, max: usize) usize {
    return if (val == 0) max - 1 else val - 1;
}

const SdlError = error{
    SdlFailure,
};

const Cell = enum {
    nothing,
    body_moving_right, // at this cell, snake was moving right
    body_moving_up,
    body_moving_left,
    body_moving_down,
    food,

    pub fn fromDirection(d: Direction) Cell {
        switch (d) {
            .right => return .body_moving_right,
            .up => return .body_moving_up,
            .left => return .body_moving_left,
            .down => return .body_moving_down,
        }
    }
};

const Direction = enum {
    right,
    up,
    left,
    down,
};

const GameResult = enum {
    game_continues,
    game_ends,
};

const Position = struct {
    x: usize,
    y: usize,
};

const SnakeContext = struct {
    cells: [matrix_size]Cell,
    head: Position = .{ .x = 0, .y = 0 },
    tail: Position = .{ .x = 0, .y = 0 },
    next_dir: Direction = .right,
    inhibit_tail_step: usize = 4,
    occupied_cells: usize = 4,
    rng: std.Random,

    pub fn init(rng: std.Random) SnakeContext {
        var ctx = SnakeContext{
            .cells = [_]Cell{.nothing} ** matrix_size,
            .rng = rng,
        };
        ctx.reset();
        return ctx;
    }

    pub fn reset(self: *SnakeContext) void {
        @memset(&self.cells, Cell.nothing);
        self.head.x = game_width / 2;
        self.tail.x = game_width / 2;
        self.head.y = game_height / 2;
        self.tail.y = game_height / 2;
        self.next_dir = .right;
        self.inhibit_tail_step = 4;
        self.occupied_cells = 4;
        self.putCell(self.tail.x, self.tail.y, .body_moving_right);
        self.occupied_cells -= 1;
        for (0..4) |_| {
            self.newFoodPos();
        }
    }

    pub fn getCell(self: *const SnakeContext, x: usize, y: usize) Cell {
        return self.cells[y * game_width + x];
    }

    pub fn putCell(self: *SnakeContext, x: usize, y: usize, cell: Cell) void {
        self.cells[y * game_width + x] = cell;
    }

    pub fn isCellsFull(self: *SnakeContext) bool {
        return self.occupied_cells == game_width * game_height;
    }

    pub fn newFoodPos(self: *SnakeContext) void {
        while (true) {
            const x = self.rng.uintLessThan(usize, game_width);
            const y = self.rng.uintLessThan(usize, game_height);
            if (self.getCell(x, y) == .nothing) {
                self.putCell(x, y, .food);
                self.occupied_cells += 1;
                break;
            }
        }
    }

    pub fn setDirection(self: *SnakeContext, dir: Direction) void {
        const cell = self.getCell(self.head.x, self.head.y);
        if ((dir == .right and cell != .body_moving_left) or
            (dir == .up and cell != .body_moving_down) or
            (dir == .left and cell != .body_moving_right) or
            (dir == .down and cell != .body_moving_up))
        {
            self.next_dir = dir;
        }
    }

    pub fn step(self: *SnakeContext) GameResult {
        // move tail forward
        self.inhibit_tail_step -= 1;
        if (self.inhibit_tail_step == 0) {
            self.inhibit_tail_step = 1;
            const ct = self.getCell(self.tail.x, self.tail.y);
            self.putCell(self.tail.x, self.tail.y, .nothing);
            switch (ct) {
                .body_moving_right => self.tail.x = wrapInc(self.tail.x, game_width),
                .body_moving_up => self.tail.y = wrapDec(self.tail.y, game_height),
                .body_moving_left => self.tail.x = wrapDec(self.tail.x, game_width),
                .body_moving_down => self.tail.y = wrapInc(self.tail.y, game_height),
                else => {},
            }
        }

        // move head forward
        const prev_xpos: usize = self.head.x;
        const prev_ypos: usize = self.head.y;
        switch (self.next_dir) {
            .right => self.head.x = wrapInc(self.head.x, game_width),
            .up => self.head.y = wrapDec(self.head.y, game_height),
            .left => self.head.x = wrapDec(self.head.x, game_width),
            .down => self.head.y = wrapInc(self.head.y, game_height),
        }

        // collisions
        const cell = self.getCell(self.head.x, self.head.y);
        if (cell != .nothing and cell != .food) {
            return .game_ends;
        }
        self.putCell(prev_xpos, prev_ypos, Cell.fromDirection(self.next_dir));
        self.putCell(self.head.x, self.head.y, Cell.fromDirection(self.next_dir));
        if (cell == .food) {
            if (self.isCellsFull()) return .game_ends;
            self.newFoodPos();
            self.inhibit_tail_step += 1;
            self.occupied_cells += 1;
        }

        return .game_continues;
    }
};

pub fn handle_key_event(snake: *SnakeContext, key_code: sdl.SDL_Scancode) AppStatus {
    switch (key_code) {
        // quit
        sdl.SDL_SCANCODE_ESCAPE, sdl.SDL_SCANCODE_Q => {
            return .quit_success;
        },
        // restart the game as if the program was launched
        sdl.SDL_SCANCODE_R => {
            snake.reset();
        },
        // decide new direction of the snake
        sdl.SDL_SCANCODE_RIGHT => snake.setDirection(.right),
        sdl.SDL_SCANCODE_UP => snake.setDirection(.up),
        sdl.SDL_SCANCODE_LEFT => snake.setDirection(.left),
        sdl.SDL_SCANCODE_DOWN => snake.setDirection(.down),
        else => {},
    }
    return .app_continue;
}

pub fn handle_hat_event(snake: *SnakeContext, hat: u8) AppStatus {
    switch (hat) {
        sdl.SDL_HAT_RIGHT => snake.setDirection(.right),
        sdl.SDL_HAT_UP => snake.setDirection(.up),
        sdl.SDL_HAT_LEFT => snake.setDirection(.left),
        sdl.SDL_HAT_DOWN => snake.setDirection(.down),
        else => {},
    }
    return .app_continue;
}

const AppStatus = enum {
    app_continue,
    quit_success,
    quit_failure,
};

const AppState = struct {
    window: *sdl.SDL_Window,
    renderer: *sdl.SDL_Renderer,
    snake_ctx: SnakeContext,
    last_step: u64,
};

pub fn gameTick(app_state: *AppState) AppStatus {
    const now = sdl.SDL_GetTicks();
    const renderer = app_state.renderer;

    while ((now - app_state.last_step) >= step_rate_in_milliseconds) {
        if (app_state.snake_ctx.step() == .game_ends) {
            app_state.snake_ctx.reset();
        }
        app_state.last_step += step_rate_in_milliseconds;
    }

    var r: sdl.SDL_FRect = undefined;
    r.w = block_size_in_pixels;
    r.h = block_size_in_pixels;
    _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, sdl.SDL_ALPHA_OPAQUE);
    _ = sdl.SDL_RenderClear(renderer);
    for (0..game_width) |x| {
        for (0..game_height) |y| {
            const cell = app_state.snake_ctx.getCell(@intCast(x), @intCast(y));
            if (cell == .nothing)
                continue;
            setRectXY(&r, @floatFromInt(x), @floatFromInt(y));
            if (cell == .food) {
                _ = sdl.SDL_SetRenderDrawColor(renderer, 80, 80, 255, sdl.SDL_ALPHA_OPAQUE);
            } else {
                _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 128, 0, sdl.SDL_ALPHA_OPAQUE);
            }
            _ = sdl.SDL_RenderFillRect(renderer, &r);
        }
    }
    _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 255, 0, sdl.SDL_ALPHA_OPAQUE);
    setRectXY(&r, @floatFromInt(app_state.snake_ctx.head.x), @floatFromInt(app_state.snake_ctx.head.y));
    _ = sdl.SDL_RenderFillRect(renderer, &r);
    _ = sdl.SDL_RenderPresent(renderer);
    return .app_continue;
}

pub fn main(init: std.process.Init) void {
    const io = init.io;
    var prng: std.Random.DefaultPrng = .init(123456);
    const rng = prng.random();

    _ = sdl.SDL_SetAppMetadata("Example Snake Game", "1.0", "com.example.Snake");

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_JOYSTICK)) {
        std.debug.panic("Couldn't initialize SDL: {s}", .{sdl.SDL_GetError()});
    }
    defer sdl.SDL_Quit();

    std.debug.print("video driver: {s}\n", .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")});

    // Create a window and renderer
    var window: ?*sdl.SDL_Window = null;
    var renderer: ?*sdl.SDL_Renderer = null;
    if (!sdl.SDL_CreateWindowAndRenderer(
        "examples/demo/snake",
        window_width,
        window_height,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    )) {
        std.debug.panic("{s}", .{sdl.SDL_GetError()});
    }
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    _ = sdl.SDL_SetRenderLogicalPresentation(renderer, window_width, window_height, sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX);

    var app_state = AppState{
        .snake_ctx = .init(rng),
        .last_step = sdl.SDL_GetTicks(),
        .renderer = renderer.?,
        .window = window.?,
    };

    var joystick: ?*sdl.SDL_Joystick = null;
    defer {
        if (joystick) |stick| {
            sdl.SDL_CloseJoystick(stick);
        }
    }

    var done = false;

    // Main loop
    while (!done) {
        // Poll events
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => {
                    done = true;
                },
                sdl.SDL_EVENT_JOYSTICK_ADDED => {
                    if (joystick == null) {
                        joystick = sdl.SDL_OpenJoystick(event.jdevice.which);
                        if (joystick == null) {
                            std.debug.print("Failed to open joystick ID {d}: {s}\n", .{
                                event.jdevice.which,
                                sdl.SDL_GetError(),
                            });
                        }
                    }
                },
                sdl.SDL_EVENT_JOYSTICK_REMOVED => {
                    if (joystick == null and (sdl.SDL_GetJoystickID(joystick) == event.jdevice.which)) {
                        sdl.SDL_CloseJoystick(joystick);
                        joystick = null;
                    }
                },
                sdl.SDL_EVENT_KEY_DOWN => {
                    switch (handle_key_event(&app_state.snake_ctx, event.key.scancode)) {
                        .app_continue => {},
                        else => done = true,
                    }
                },
                sdl.SDL_EVENT_JOYSTICK_HAT_MOTION => {
                    switch (handle_hat_event(&app_state.snake_ctx, event.jhat.value)) {
                        .app_continue => {},
                        else => done = true,
                    }
                },
                else => {},
            }
        }

        const status = gameTick(&app_state);
        switch (status) {
            .app_continue => {},
            else => {
                std.debug.print("Ending: {s}\n", .{@tagName(status)});
                done = true;
            },
        }
    }
    std.process.cleanExit(io);
}
