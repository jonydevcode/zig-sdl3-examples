const std = @import("std");
const sdl = @import("sdl3");
const sdlx = @import("sdlx.zig");

// This demo uses a simulated CHIP-8 screen
const chip8_screen_width = 64;
const chip8_screen_height = 32;
const chip8_screen_pixels = chip8_screen_width * chip8_screen_height;
var chip8_screen = [_]bool{false} ** chip8_screen_pixels;

// How big each CHIP-8 screen pixel should be on the display
const window_scale = 20;

// How often to move the hot pixel in milliseconds
const update_interval_ms = 30;
const update_interval_ns = update_interval_ms * 1_000_000;

// `chip8_frame` is the RGBA representation of the CHIP-8 screen
const RGBA = packed struct(u32) { r: u8, g: u8, b: u8, a: u8 };
const black = RGBA{ .r = 0, .g = 0, .b = 0, .a = 0 };
const white = RGBA{ .r = 255, .g = 255, .b = 255, .a = 255 };
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

fn loadShader(
    gpu: *sdl.SDL_GPUDevice,
    path: [:0]const u8,
    entry_point: [:0]const u8,
    format: sdl.SDL_GPUShaderFormat,
    stage: sdl.SDL_GPUShaderStage,
    samplers: u32,
) !*sdl.SDL_GPUShader {
    var size: usize = 0;
    const raw = sdl.SDL_LoadFile(path, &size) orelse return error.ShaderLoadFileFailed;
    defer sdl.SDL_free(raw);

    const code: []const u8 = @as([*]const u8, @ptrCast(raw))[0..size];

    const create_info = sdl.SDL_GPUShaderCreateInfo{
        .code = code.ptr,
        .code_size = code.len,
        .entrypoint = entry_point,
        .format = format,
        .stage = stage,
        .num_samplers = samplers,
    };
    const shader = sdl.SDL_CreateGPUShader(gpu, &create_info) orelse return error.CreateGPUShaderFailed;
    return shader;
}

const ShaderConfig = struct {
    shader_format: sdl.SDL_GPUShaderFormat,
    vertex_path: [:0]const u8,
    fragment_path: [:0]const u8,
    vertex_entry: [:0]const u8,
    fragment_entry: [:0]const u8,
};

const EventResult = enum { app_continue, app_quit };

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

    const window = sdl.SDL_CreateWindow(
        "SDL3 GPU API Test",
        chip8_screen_width * window_scale,
        chip8_screen_height * window_scale,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
    ) orelse return sdlx.die("SDL_CreateWindow");
    defer sdl.SDL_DestroyWindow(window);

    const gpu = sdl.SDL_CreateGPUDevice(
        sdl.SDL_GPU_SHADERFORMAT_SPIRV | sdl.SDL_GPU_SHADERFORMAT_MSL,
        true,
        null,
    ) orelse return sdlx.die("SDL_CreateGPUDevice");
    defer sdl.SDL_DestroyGPUDevice(gpu);

    try sdlx.check(
        "SDL_ClaimWindowForGPUDevice",
        sdl.SDL_ClaimWindowForGPUDevice(gpu, window),
    );
    defer sdl.SDL_ReleaseWindowFromGPUDevice(gpu, window);

    const supported_formats = sdl.SDL_GetGPUShaderFormats(gpu);
    const shader_config: ShaderConfig = if (supported_formats & sdl.SDL_GPU_SHADERFORMAT_MSL > 0)
        ShaderConfig{
            .shader_format = sdl.SDL_GPU_SHADERFORMAT_MSL,
            .vertex_path = "shaders/fullscreen.vert.msl",
            .fragment_path = "shaders/chip8.frag.msl",
            .vertex_entry = "FullscreenVS",
            .fragment_entry = "Chip8FS",
        }
    else if (supported_formats & sdl.SDL_GPU_SHADERFORMAT_SPIRV > 0)
        ShaderConfig{
            .shader_format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .vertex_path = "shaders/fullscreen.vert.spv",
            .fragment_path = "shaders/chip8.frag.spv",
            .vertex_entry = "main",
            .fragment_entry = "main",
        }
    else
        return error.NoSupportedShaderFormat;

    const frame_tex = sdl.SDL_CreateGPUTexture(
        gpu,
        &sdl.SDL_GPUTextureCreateInfo{
            .type = sdl.SDL_GPU_TEXTURETYPE_2D,
            .format = sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
            .usage = sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
            .width = chip8_screen_width,
            .height = chip8_screen_height,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .sample_count = sdl.SDL_GPU_SAMPLECOUNT_1,
        },
    ) orelse return sdlx.die("SDL_CreateGPUTexture");
    defer sdl.SDL_ReleaseGPUTexture(gpu, frame_tex);

    const upload = sdl.SDL_CreateGPUTransferBuffer(
        gpu,
        &sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = chip8_frame.len * @sizeOf(RGBA),
        },
    ) orelse return sdlx.die("SDL_CreateGPUTransferBuffer");
    defer sdl.SDL_ReleaseGPUTransferBuffer(gpu, upload);

    const nearest = sdl.SDL_CreateGPUSampler(
        gpu,
        &sdl.SDL_GPUSamplerCreateInfo{
            .min_filter = sdl.SDL_GPU_FILTER_NEAREST,
            .mag_filter = sdl.SDL_GPU_FILTER_NEAREST,
            .mipmap_mode = sdl.SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,
            .address_mode_u = sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            .address_mode_v = sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            .address_mode_w = sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
        },
    ) orelse return sdlx.die("SDL_CreateGPUSampler");
    defer sdl.SDL_ReleaseGPUSampler(gpu, nearest);

    const vs = try loadShader(
        gpu,
        shader_config.vertex_path,
        shader_config.vertex_entry,
        shader_config.shader_format,
        sdl.SDL_GPU_SHADERSTAGE_VERTEX,
        0,
    );
    defer sdl.SDL_ReleaseGPUShader(gpu, vs);
    const fs = try loadShader(
        gpu,
        shader_config.fragment_path,
        shader_config.fragment_entry,
        shader_config.shader_format,
        sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
        1,
    );
    defer sdl.SDL_ReleaseGPUShader(gpu, fs);

    // Create the graphics pipeline
    const color_target = sdl.SDL_GPUColorTargetDescription{
        .format = sdl.SDL_GetGPUSwapchainTextureFormat(gpu, window),
    };
    const pipeline = sdl.SDL_CreateGPUGraphicsPipeline(
        gpu,
        &sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = vs,
            .fragment_shader = fs,
            .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = .{
                .fill_mode = sdl.SDL_GPU_FILLMODE_FILL,
                .cull_mode = sdl.SDL_GPU_CULLMODE_NONE,
                .front_face = sdl.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
            },
            .target_info = .{
                .color_target_descriptions = &color_target,
                .num_color_targets = 1,
            },
        },
    ) orelse return sdlx.die("SDL_CreateGPUGraphicsPipeline");
    defer sdl.SDL_ReleaseGPUGraphicsPipeline(gpu, pipeline);

    var hot_index: usize = 0;
    var framebuffer_dirty = true;
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
            framebuffer_dirty = true;
            needs_present = true;
            // skip ahead of now by about 1 sec
            while (now >= next_update_ns) {
                next_update_ns = now + update_interval_ns;
            }
        }

        if (needs_present) {
            // Command buffer is like a GPU "to-do list".
            // First, we "write down" the commands on this to-do list.
            const cmd = sdl.SDL_AcquireGPUCommandBuffer(gpu) orelse return sdlx.die("SDL_AcquireGPUCommandBuffer");

            if (framebuffer_dirty) {
                buildRGBAFrame(&chip8_screen, &chip8_frame);

                // Copy the 64x32 internal buffer to an upload buffer.
                // `upload` is SDL_CreateGPUTransferBuffer created earlier.
                const dst = sdl.SDL_MapGPUTransferBuffer(gpu, upload, true) orelse return sdlx.die("SDL_MapGPUTransferBuffer");
                _ = sdl.SDL_memcpy(dst, &chip8_frame, chip8_frame.len * @sizeOf(RGBA));
                sdl.SDL_UnmapGPUTransferBuffer(gpu, upload);

                // Record a GPU copy operation into the command buffer
                // i.e. copy the image bytes from `upload` into `frame_tex`.
                const copy = sdl.SDL_BeginGPUCopyPass(cmd);
                sdl.SDL_UploadToGPUTexture(
                    copy,
                    &sdl.SDL_GPUTextureTransferInfo{
                        .transfer_buffer = upload,
                        .pixels_per_row = chip8_screen_width,
                        .rows_per_layer = chip8_screen_height,
                    },
                    &sdl.SDL_GPUTextureRegion{
                        .texture = frame_tex,
                        .w = chip8_screen_width,
                        .h = chip8_screen_height,
                        .d = 1,
                    },
                    true,
                );
                sdl.SDL_EndGPUCopyPass(copy);
                framebuffer_dirty = false;
            }

            // Acquire the next window image to draw into, also known as the
            // `swapchain` texture. This is like the next blank page that will become
            // visible in the window
            var maybe_swapchain: ?*sdl.SDL_GPUTexture = null;
            var out_w: u32 = 0;
            var out_h: u32 = 0;
            try sdlx.check("SDL_WaitAndAcquireGPUSwapchainTexture", sdl.SDL_WaitAndAcquireGPUSwapchainTexture(
                cmd,
                window,
                &maybe_swapchain,
                &out_w,
                &out_h,
            ));
            if (maybe_swapchain) |swapchain| {
                // If a window image was acquired, record the draw commands.
                const pass = sdl.SDL_BeginGPURenderPass(
                    cmd,
                    &sdl.SDL_GPUColorTargetInfo{
                        .texture = swapchain,
                        .clear_color = sdl.SDL_FColor{ .r = 0, .g = 0, .b = 0, .a = 1 },
                        .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
                        .store_op = sdl.SDL_GPU_STOREOP_STORE,
                    },
                    1,
                    null,
                );
                sdl.SDL_BindGPUGraphicsPipeline(pass, pipeline);
                sdl.SDL_BindGPUFragmentSamplers(
                    pass,
                    0,
                    &sdl.SDL_GPUTextureSamplerBinding{
                        .texture = frame_tex,
                        .sampler = nearest,
                    },
                    1,
                );
                sdl.SDL_DrawGPUPrimitives(pass, 6, 1, 0, 0);
                sdl.SDL_EndGPURenderPass(pass);
            }

            // Submit the recorded GPU commands. After this, the CPU continues while the GPU
            // works asynchronously.
            sdlx.check("SDL_SubmitGPUCommandBuffer", sdl.SDL_SubmitGPUCommandBuffer(cmd)) catch {};
            needs_present = false;
        }
    }

    // Wait for the GPU to finish any queued work.
    try sdlx.check("SDL_WaitForGPUIdle", sdl.SDL_WaitForGPUIdle(gpu));
}
