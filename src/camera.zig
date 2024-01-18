const std = @import("std");
const c = @import("c.zig");

const pi = std.math.pi;
const sin = std.math.sin;
const cos = std.math.cos;

fn normalize(vec: [3]f32) [3]f32 {
    const mag = std.math.sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2]);
    return .{
        vec[0] / mag,
        vec[1] / mag,
        vec[2] / mag
    };
}

fn cross(a: [3]f32, b: [3]f32) [3]f32 {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0]
    };
}

pub const Camera = struct {
    world_up:   [3]f32,
    cam_pos:    [3]f32,
    cam_dir:    [3]f32,
    cam_right:  [3]f32,
    cam_up:     [3]f32,
    yaw:        f32,
    pitch:      f32,

    pub fn init(pos: [3]f32, pitch: f32, yaw: f32) Camera {
        var camera = Camera{
            .world_up   = .{0.0, 1.0, 0.0},
            .cam_pos    = pos,
            .cam_dir    = .{0.0, 0.0, -1.0},
            .cam_right  = undefined,
            .cam_up     = undefined,
            .yaw        = yaw,
            .pitch      = pitch
        };
        camera.update();
        return camera;
    }

    pub fn update(self: *Camera) void {
        var dir: [3]f32 = undefined;
        dir[0] = cos(self.yaw / 180.0 * pi) * cos(self.pitch / 180.0 * pi);
        dir[1] = sin(self.pitch / 180.0 * pi);
        dir[2] = sin(self.yaw / 180.0 * pi) * cos(self.pitch / 180.0 * pi);
        self.cam_dir = normalize(dir);
        self.cam_right = normalize(cross(self.cam_dir, self.world_up));
        self.cam_up = normalize(cross(self.cam_right, self.cam_dir));
    }
};