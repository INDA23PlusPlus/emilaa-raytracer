const std = @import("std");
const c = @import("c.zig");

const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

const ShaderStage = enum {
    VERTEX_STAGE,
    FRAGMENT_STAGE,
    COMPUTE_STAGE,
    PROGRAM
};

pub const Shader = struct {
    program_id: c_uint,

    pub fn init(allocator: *const Allocator, vert_path: []const u8, frag_path: []const u8) !Shader {
        const vert_file = try std.fs.cwd().openFile(vert_path, .{});
        defer vert_file.close();

        const frag_file = try std.fs.cwd().openFile(frag_path, .{});
        defer frag_file.close();

        const v_len: usize = try vert_file.getEndPos();
        const f_len: usize = try frag_file.getEndPos();

        var vert_source = try allocator.alloc(u8, v_len);
        @memset(vert_source, 0);
        defer allocator.free(vert_source);

        var frag_source = try allocator.alloc(u8, f_len);
        @memset(frag_source, 0);
        defer allocator.free(frag_source);

        _ = try vert_file.read(vert_source);
        _ = try frag_file.read(frag_source);

        const vert_stage = c.glCreateShader(c.GL_VERTEX_SHADER);
        const vert_source_ptr: ?[*]const u8 = vert_source.ptr;
        c.glShaderSource(vert_stage, 1, &vert_source_ptr, null);
        c.glCompileShader(vert_stage);
        check_errors(vert_stage, ShaderStage.VERTEX_STAGE);

        const frag_stage = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        const frag_source_ptr: ?[*]const u8 = frag_source.ptr;
        c.glShaderSource(frag_stage, 1, &frag_source_ptr, null);
        c.glCompileShader(frag_stage);
        check_errors(frag_stage, ShaderStage.FRAGMENT_STAGE);

        const program = c.glCreateProgram();
        c.glAttachShader(program, vert_stage);
        c.glAttachShader(program, frag_stage);
        c.glLinkProgram(program);
        check_errors(program, ShaderStage.PROGRAM);

        c.glDeleteShader(vert_stage);
        c.glDeleteShader(frag_stage);

        return Shader{ .program_id = program };
    }

    pub fn use(self: Shader) void {
        c.glUseProgram(self.program_id);
    }

    pub fn set_int(self: Shader, name: [:0]const u8, val: c_int) void {
        c.glUniform1i(c.glGetUniformLocation(self.program_id, name), val);
    }

    fn check_errors(program: c_uint, stage: ShaderStage) void {
        var success: c_int = undefined;
        var info_log: [1024]u8 = undefined;
        if(stage != ShaderStage.PROGRAM) {
            c.glGetShaderiv(program, c.GL_COMPILE_STATUS, &success);
            if(success == 0) {
                c.glGetShaderInfoLog(program, 1024, null, &info_log);
                panic("Stage: {s} | Compile error:\n{s}\n", .{ @tagName(stage), info_log });
            }
        } else {
            c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
            if(success == 0) {
                c.glGetProgramInfoLog(program, 1024, null, &info_log);
                panic("Stage: {s} | Compile error:\n{s}\n", .{ @tagName(stage), info_log });
            }
        }
    }
};

pub const ComputeShader = struct {
    program_id: c_uint,

    pub fn init(allocator: *const Allocator, comp_path: []const u8) !ComputeShader {
        const comp_file = try std.fs.cwd().openFile(comp_path, .{});
        defer comp_file.close();

        var comp_source = try allocator.alloc(u8, try comp_file.getEndPos());
        defer allocator.free(comp_source);

        _ = try comp_file.read(comp_source);

        const comp_stage = c.glCreateShader(c.GL_COMPUTE_SHADER);
        const comp_source_ptr: ?[*]const u8 = comp_source.ptr;
        c.glShaderSource(comp_stage, 1, &comp_source_ptr, null);
        c.glCompileShader(comp_stage);
        check_errors(comp_stage, ShaderStage.COMPUTE_STAGE);

        const program = c.glCreateProgram();
        c.glAttachShader(program, comp_stage);
        c.glLinkProgram(program);
        check_errors(program, ShaderStage.PROGRAM);

        c.glDeleteShader(comp_stage);

        return ComputeShader{ .program_id = program };
    }

    pub fn use(self: ComputeShader) void {
        c.glUseProgram(self.program_id);
    }

    pub fn set_vec3(self: ComputeShader, name: [:0]const u8, vec: [3]f32) void {
        c.glUniform3f(c.glGetUniformLocation(self.program_id, name), vec[0], vec[1], vec[2]);
    }

    pub fn set_float(self: ComputeShader, name: [:0]const u8, val: f32) void {
        c.glUniform1f(c.glGetUniformLocation(self.program_id, name), val);
    }

    fn check_errors(program: c_uint, stage: ShaderStage) void {
        var success: c_int = undefined;
        var info_log: [1024]u8 = undefined;
        if(stage != ShaderStage.PROGRAM) {
            c.glGetShaderiv(program, c.GL_COMPILE_STATUS, &success);
            if(success == 0) {
                c.glGetShaderInfoLog(program, 1024, null, &info_log);
                panic("Stage: {s} | Compile error:\n{s}\n", .{ @tagName(stage), info_log });
            }
        } else {
            c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
            if(success == 0) {
                c.glGetProgramInfoLog(program, 1024, null, &info_log);
                panic("Stage: {s} | Compile error:\n{s}\n", .{ @tagName(stage), info_log });
            }
        }
    }
};