const std = @import("std");
const c = @import("c.zig");
const Shader = @import("shader.zig").Shader;
const ComputeShader = @import("shader.zig").ComputeShader;
const Camera = @import("camera.zig").Camera;

const panic = std.debug.panic;
const print = std.log.info;

const Vertex = struct {
    pos: [2]f32,
    uv:  [2]f32
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const ok = c.glfwInit();
    if(ok == 0)
        panic("GLFW couldn't init...\n", .{});
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 6);   
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_COMPAT_PROFILE);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GL_FALSE);

    var window = c.glfwCreateWindow(1280, 720, "Ray Tracer", null, null);
    if(window == null)
        panic("Couldn't create window...\n", .{});

    c.glfwMakeContextCurrent(window);
    if(c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == 0)
        panic("GLAD couldn't init...\n", .{});
    c.glViewport(0, 0, 1280, 720);
    
    const quad = [6]Vertex {
        .{ .pos = .{ 1.0,  1.0}, .uv = .{ 1.0, 1.0 } },
        .{ .pos = .{ 1.0, -1.0}, .uv = .{ 1.0, 0.0 } },
        .{ .pos = .{-1.0, -1.0}, .uv = .{ 0.0, 0.0 } },

        .{ .pos = .{-1.0, -1.0}, .uv = .{ 0.0, 0.0 } },
        .{ .pos = .{-1.0,  1.0}, .uv = .{ 0.0, 1.0 } },
        .{ .pos = .{ 1.0,  1.0}, .uv = .{ 1.0, 1.0 } }
    };

    var VAO: c_uint = undefined;
    var VBO: c_uint = undefined;
    var quad_texture: c_uint = undefined;
    
    c.glGenVertexArrays(1, &VAO);
    defer c.glDeleteVertexArrays(1, &VAO);
    c.glGenBuffers(1, &VBO);
    defer c.glDeleteBuffers(1, &VBO);
    c.glGenTextures(1, &quad_texture);
    defer c.glDeleteTextures(1, &quad_texture);

    c.glBindVertexArray(VAO);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, quad.len * @sizeOf(Vertex), &quad, c.GL_STATIC_DRAW);

    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.glEnableVertexAttribArray(1);
    c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "uv")));

    c.glActiveTexture(c.GL_TEXTURE0);
    c.glBindTexture(c.GL_TEXTURE_2D, quad_texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA32F, 1280, 720, 0, c.GL_RGBA, c.GL_FLOAT, null);
    c.glBindImageTexture(0, quad_texture, 0, c.GL_FALSE, 0, c.GL_READ_WRITE, c.GL_RGBA32F);

    c.glActiveTexture(c.GL_TEXTURE0);
    c.glBindTexture(c.GL_TEXTURE_2D, quad_texture);
    
    const draw_shader = try Shader.init(&allocator, "shaders/draw.vert", "shaders/draw.frag");
    const trace_shader = try ComputeShader.init(&allocator, "shaders/trace.comp");
    var camera = Camera.init(.{0.0, 0.0, 5.0}, 0.0, -90.0);
    var time_last: f32 = 0.0;

    print("\nWalk around -> WASD\nLook around -> Arrow keys", .{});

    while(c.glfwWindowShouldClose(window) == 0) {
        const time_now: f32 = @floatCast(c.glfwGetTime());
        const dt = time_now - time_last;
        time_last = time_now;

        try handle_keyboard(window, &dt, &camera);
        camera.update();

        c.glClearColor(0.9, 0.2, 0.9, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        trace_shader.use();
        trace_shader.set_vec3("look_dir", camera.cam_dir);
        trace_shader.set_vec3("up_dir", camera.cam_up);
        trace_shader.set_vec3("right_dir", camera.cam_right);
        trace_shader.set_vec3("cam_pos", camera.cam_pos);
        trace_shader.set_float("time", time_now);
        c.glDispatchCompute(80, 45, 1);
        c.glMemoryBarrier(c.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        draw_shader.use();
        draw_shader.set_int("tex", 0);
        c.glBindVertexArray(VAO);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}

pub fn handle_keyboard(window: ?*c.GLFWwindow, dt: *const f32, camera: *Camera) !void {
    if(c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);

    if(c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) {
        const fac = 1.0 / std.math.sqrt(camera.cam_dir[0] * camera.cam_dir[0] + camera.cam_dir[2] * camera.cam_dir[2]);
        camera.cam_pos[0] += camera.cam_dir[0] * fac * 2.0 * dt.*;
        camera.cam_pos[2] += camera.cam_dir[2] * fac * 2.0 * dt.*;
    }

    if(c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS) {
        const fac = 1.0 / std.math.sqrt(camera.cam_dir[0] * camera.cam_dir[0] + camera.cam_dir[2] * camera.cam_dir[2]);
        camera.cam_pos[0] -= camera.cam_dir[0] * fac * 2.0 * dt.*;
        camera.cam_pos[2] -= camera.cam_dir[2] * fac * 2.0 * dt.*;
    }

    if(c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS) {
        const fac = 1.0 / std.math.sqrt(camera.cam_right[0] * camera.cam_right[0] + camera.cam_right[2] * camera.cam_right[2]);
        camera.cam_pos[0] += camera.cam_right[0] * fac * 2.0 * dt.*;
        camera.cam_pos[2] += camera.cam_right[2] * fac * 2.0 * dt.*;
    }

    if(c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS) {
        const fac = 1.0 / std.math.sqrt(camera.cam_right[0] * camera.cam_right[0] + camera.cam_right[2] * camera.cam_right[2]);
        camera.cam_pos[0] -= camera.cam_right[0] * fac * 2.0 * dt.*;
        camera.cam_pos[2] -= camera.cam_right[2] * fac * 2.0 * dt.*;
    }

    if(c.glfwGetKey(window, c.GLFW_KEY_SPACE) == c.GLFW_PRESS) {
        camera.cam_pos[1] += camera.world_up[1] * 2.0 * dt.*;
    }

    if(c.glfwGetKey(window, c.GLFW_KEY_LEFT_SHIFT) == c.GLFW_PRESS) {
        camera.cam_pos[1] -= camera.world_up[1] * 2.0 * dt.*;
    }
    
    if(c.glfwGetKey(window, c.GLFW_KEY_UP) == c.GLFW_PRESS) {
        camera.pitch = std.math.clamp(camera.pitch + 70.0 * dt.*, -85.0, 85.0);
    }

    if(c.glfwGetKey(window, c.GLFW_KEY_DOWN) == c.GLFW_PRESS) {
        camera.pitch = std.math.clamp(camera.pitch - 70.0 * dt.*, -85.0, 85.0);
    }

    if(c.glfwGetKey(window, c.GLFW_KEY_RIGHT) == c.GLFW_PRESS) {
        camera.yaw = try std.math.mod(f32, camera.yaw + 70.0 * dt.*, 360.0);
    }

    if(c.glfwGetKey(window, c.GLFW_KEY_LEFT) == c.GLFW_PRESS) {
        camera.yaw = try std.math.mod(f32, camera.yaw - 70.0 * dt.*, 360.0);
    }
}