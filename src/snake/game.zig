const Self = @This();
const std = @import("std");

pub const game_width = 24;
pub const game_height = 18;
pub const matrix_size = game_width * game_height;

fn wrapInc(val: usize, max: usize) usize {
    return if (val + 1 >= max) 0 else val + 1;
}

fn wrapDec(val: usize, max: usize) usize {
    return if (val == 0) max - 1 else val - 1;
}

pub const Cell = enum {
    nothing,
    body_moving_right, // at this cell, snake was moving right
    body_moving_up,
    body_moving_left,
    body_moving_down,
    food,

    fn toDirection(self: Cell) ?Direction {
        return switch (self) {
            .body_moving_right => .right,
            .body_moving_left => .left,
            .body_moving_down => .down,
            .body_moving_up => .up,
            else => null,
        };
    }
};

pub const Direction = enum {
    right,
    up,
    left,
    down,

    fn toCell(self: Direction) Cell {
        return switch (self) {
            .right => .body_moving_right,
            .up => .body_moving_up,
            .left => .body_moving_left,
            .down => .body_moving_down,
        };
    }

    fn opposite(self: Direction) Direction {
        return switch (self) {
            .right => .left,
            .left => .right,
            .up => .down,
            .down => .up,
        };
    }

    fn forward(self: Direction, pos: Position) Position {
        var next = pos;
        switch (self) {
            .right => next.x = wrapInc(next.x, game_width),
            .up => next.y = wrapDec(next.y, game_height),
            .left => next.x = wrapDec(next.x, game_width),
            .down => next.y = wrapInc(next.y, game_height),
        }
        return next;
    }
};

pub const GameResult = enum {
    game_continues,
    game_ends,
};

pub const Position = struct {
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
    const cur_dir = self.getCell(self.head.x, self.head.y).toDirection() orelse return;
    if (dir != cur_dir.opposite()) {
        self.next_dir = dir;
    }
}

pub fn step(self: *Self) GameResult {
    // move tail forward
    self.inhibit_tail_step -= 1;
    if (self.inhibit_tail_step == 0) {
        self.inhibit_tail_step = 1;
        const tail_cell = self.getCell(self.tail.x, self.tail.y);
        self.putCell(self.tail.x, self.tail.y, .nothing);
        if (tail_cell.toDirection()) |dir| {
            self.tail = dir.forward(self.tail);
        }
    }

    // move head forward
    const prev_head = self.head;
    self.head = self.next_dir.forward(self.head);

    // collisions
    const cell = self.getCell(self.head.x, self.head.y);
    if (cell != .nothing and cell != .food) {
        return .game_ends;
    }
    self.putCell(prev_head.x, prev_head.y, self.next_dir.toCell());
    self.putCell(self.head.x, self.head.y, self.next_dir.toCell());
    if (cell == .food) {
        if (self.isCellsFull()) return .game_ends;
        self.newFoodPos();
        self.inhibit_tail_step += 1;
        self.occupied_cells += 1;
    }

    return .game_continues;
}
