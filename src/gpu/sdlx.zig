const std = @import("std");
const sdl = @import("sdl3");

pub const SdlError = error{
    SdlFailure,
};

/// Utility to help make good use of SDL_GetError()
pub fn check(comptime name: []const u8, ok: bool) SdlError!void {
    if (!ok) {
        std.log.err("{s} failed: {s}", .{ name, std.mem.span(sdl.SDL_GetError()) });
        return error.SdlFailure;
    }
}

pub fn die(comptime name: []const u8) SdlError {
    std.log.err("{s} failed: {s}", .{ name, std.mem.span(sdl.SDL_GetError()) });
    return error.SdlFailure;
}
