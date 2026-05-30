const Self = @This();
const std = @import("std");
const sdl = @import("sdl3");
const sdl_adapter = @import("sdl_adapter.zig");

pub const game_width = 24;
pub const game_height = 18;
pub const matrix_size = game_width * game_height;

fn wrapInc(val: usize, max: usize) usize {
    return if (val + 1 >= max) 0 else val + 1;
}

fn wrapDec(val: usize, max: usize) usize {
    return if (val == 0) max - 1 else val - 1;
}

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

cells: [matrix_size]Cell,
head: Position = .{ .x = 0, .y = 0 },
tail: Position = .{ .x = 0, .y = 0 },
next_dir: Direction = .right,
inhibit_tail_step: usize = 4,
occupied_cells: usize = 4,
rng: std.Random,

pub fn init(rng: std.Random) Self {
    var ctx = Self{
        .cells = [_]Cell{.nothing} ** matrix_size,
        .rng = rng,
    };
    ctx.reset();
    return ctx;
}

pub fn reset(self: *Self) void {
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

pub fn getCell(self: *const Self, x: usize, y: usize) Cell {
    return self.cells[y * game_width + x];
}

pub fn putCell(self: *Self, x: usize, y: usize, cell: Cell) void {
    self.cells[y * game_width + x] = cell;
}

pub fn isCellsFull(self: *Self) bool {
    return self.occupied_cells == game_width * game_height;
}

pub fn newFoodPos(self: *Self) void {
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

pub fn setDirection(self: *Self, dir: Direction) void {
    const cell = self.getCell(self.head.x, self.head.y);
    if ((dir == .right and cell != .body_moving_left) or
        (dir == .up and cell != .body_moving_down) or
        (dir == .left and cell != .body_moving_right) or
        (dir == .down and cell != .body_moving_up))
    {
        self.next_dir = dir;
    }
}

pub fn step(self: *Self) GameResult {
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
