const std = @import("std");
const w4 = @import("w4");

var mouse = w4.Mouse{};

const Ray = @Vector(3, f32);

fn cmpRayAngle(_: void, a: Ray, b: Ray) bool {
    return a[0] >= b[0];
}

const Edge = struct {
    sx: i32 = 0,
    sy: i32 = 0,
    ex: i32 = 0,
    ey: i32 = 0,
};

const Cell = struct {
    edge_id: [4]usize = .{0} ** 4,
    edge_exist: [4]bool = .{false} ** 4,
    exist: bool = false,
};

const NORTH = 0;
const SOUTH = 1;
const EAST = 2;
const WEST = 3;

const BLACK = 0x11;
const RED = 0x22;
const WHITE = 0x33;
const BLUE = 0x44;

const blockSize = 8;

const worldWidth = 20;
const worldHeight = worldWidth;

var world: [worldWidth * worldHeight]Cell = .{.{}} ** (worldWidth * worldHeight);

var edges = std.BoundedArray(Edge, 128).init(0) catch {};
var rays = std.BoundedArray(Ray, 384).init(0) catch {};

export fn start() void {
    w4.palette(.{
        0x000000, // BLACK
        0xFF0000, // RED
        0xFFFFFF, // WHITE
        0x0000FF, // BLUE
    });

    for (1..(worldWidth - 1)) |x| {
        world[1 * worldWidth + x].exist = true;
        world[(worldHeight - 2) * worldWidth + x].exist = true;
    }

    for (1..(worldHeight - 1)) |y| {
        world[y * worldHeight + 1].exist = true;
        world[y * worldHeight + (worldWidth - 2)].exist = true;
    }

    toggle(80, 80);
    toggle(80, 88);
    toggle(80, 80);
    toggle(80, 88);

    toggle(30, 40);
    toggle(100, 70);

    updateEdges(0, 0, worldWidth);
}

fn toggle(x: i32, y: i32) void {
    const i = blockIndex(x, y);
    world[i].exist = !world[i].exist;
}

export fn update() void {
    mouse.update();

    if (mouse.held(w4.MOUSE_RIGHT)) {
        castRays(mouse.x, mouse.y, 1000);
    }

    if (mouse.released(w4.MOUSE_LEFT)) {
        const i = blockIndex(mouse.x, mouse.y);
        world[i].exist = !world[i].exist;

        updateEdges(0, 0, worldWidth);
    }

    draw();
}

fn triangle(x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32) void {
    w4.line(x1, y1, x2, y2);
    w4.line(x1, y1, x3, y3);
    w4.line(x2, y2, x3, y3);
}

fn draw() void {
    w4.clear(1);

    if (mouse.held(w4.MOUSE_RIGHT) and rays.len > 1) {
        w4.color(WHITE);
        w4.circle(mouse.x, mouse.y, 4);

        w4.color(WHITE);
        for (0..(rays.len - 1)) |i| {
            const p1 = rays.get(i);
            const p2 = rays.get(i + 1);

            const p1x: i32 = @intFromFloat(p1[1]);
            const p1y: i32 = @intFromFloat(p1[2]);
            const p2x: i32 = @intFromFloat(p2[1]);
            const p2y: i32 = @intFromFloat(p2[2]);

            triangle(mouse.x, mouse.y, p1x, p1y, p2x, p2y);
        }

        const p0 = rays.get(0);
        const pl = rays.get(rays.len - 1);

        const p0x: i32 = @intFromFloat(p0[1]);
        const p0y: i32 = @intFromFloat(p0[2]);
        const plx: i32 = @intFromFloat(pl[1]);
        const ply: i32 = @intFromFloat(pl[2]);

        triangle(mouse.x, mouse.y, p0x, p0y, plx, ply);
    }

    for (0..worldWidth) |x| {
        for (0..worldHeight) |y| {
            if (world[y * worldWidth + x].exist) {
                w4.color(BLUE);
                w4.rect(@intCast(x * blockSize), @intCast(y * blockSize), blockSize, blockSize);
            }
        }
    }

    for (edges.slice()) |e| {
        w4.color(RED);
        w4.pixel(e.sx, e.sy);
        w4.pixel(e.ex, e.ey);
    }
}

fn blockIndex(x: i32, y: i32) usize {
    return @intCast(
        @divFloor(y, blockSize) * worldWidth + @divFloor(x, blockSize),
    );
}

fn castRays(ox: i32, oy: i32, radius: f32) void {
    const fx: f32 = @floatFromInt(ox);
    const fy: f32 = @floatFromInt(oy);

    rays.len = 0;

    for (edges.slice()) |e1| {
        for (0..2) |i| {
            var rdx: f32 = @floatFromInt((if (i == 0) e1.sx else e1.ex) - ox);
            var rdy: f32 = @floatFromInt((if (i == 0) e1.sy else e1.ey) - oy);

            const base_ang = std.math.atan2(f32, rdy, rdx);

            var ang: f32 = 0;

            for (0..3) |j| {
                ang = switch (j) {
                    0 => base_ang - 0.0001,
                    1 => base_ang,
                    2 => base_ang + 0.0001,
                    else => unreachable,
                };

                rdx = radius * std.math.cos(ang);
                rdy = radius * std.math.sin(ang);

                var min_t1: f32 = std.math.inf(f32);
                var min_px: f32 = 0;
                var min_py: f32 = 0;
                var min_ang: f32 = 0;
                var is_valid = false;

                for (edges.slice()) |e2| {
                    const sdx: f32 = @floatFromInt(e2.ex - e2.sx);
                    const sdy: f32 = @floatFromInt(e2.ey - e2.sy);

                    if (@abs(sdx - rdx) > 0 and @abs(sdy - rdy) > 0) {
                        const t2: f32 = (rdx * (@as(f32, @floatFromInt(e2.sy)) - fy) + (rdy * (fx - @as(f32, @floatFromInt(e2.sx))))) / (sdx * rdy - sdy * rdx);
                        const t1: f32 = (@as(f32, @floatFromInt(e2.sx)) + sdx * t2 - fx) / rdx;

                        if (t1 > 0 and t2 >= 0 and t2 <= 1) {
                            if (t1 < min_t1) {
                                min_t1 = t1;
                                min_px = fx + rdx * t1;
                                min_py = fy + rdy * t1;
                                min_ang = std.math.atan2(f32, min_py - fy, min_px - fx);
                                is_valid = true;
                            }
                        }
                    }
                }

                if (is_valid) {
                    _ = rays.append(.{ min_ang, min_px, min_py }) catch {};
                }
            }
        }
    }

    var x = rays.slice();

    std.sort.insertion(Ray, x, {}, cmpRayAngle);
}

fn updateEdges(sx: usize, sy: usize, size: usize) void {
    edges.len = 0;

    for (0..size) |x| {
        for (0..size) |y| {
            const i = (y + sy) * size + (x + sx);

            for (0..4) |j| {
                world[i].edge_exist[j] = false;
                world[i].edge_id[j] = 0;
            }
        }
    }

    for (1..(size - 1)) |x| {
        for (1..(size - 1)) |y| {
            const i = (y + sy) * size + (x + sx); // This
            const n = (y + sy - 1) * size + (x + sx); // Northern Neighbour
            const s = (y + sy + 1) * size + (x + sx); // Southern Neighbour
            const w = (y + sy) * size + (x + sx - 1); // Western Neighbour
            const e = (y + sy) * size + (x + sx + 1); // Eastern Neighbour

            if (world[i].exist) {
                if (!world[w].exist) {
                    if (world[n].edge_exist[WEST]) {
                        edges.buffer[world[n].edge_id[WEST]].ey += blockSize;
                        world[i].edge_id[WEST] = world[n].edge_id[WEST];
                        world[i].edge_exist[WEST] = true;
                    } else {
                        var edge = Edge{
                            .sx = @intCast(sx + x * blockSize),
                            .sy = @intCast(sy + y * blockSize),
                        };

                        edge.ex = edge.sx;
                        edge.ey = edge.sy + blockSize;

                        world[i].edge_id[WEST] = edges.len;
                        world[i].edge_exist[WEST] = true;

                        edges.append(edge) catch {};
                    }
                }

                if (!world[e].exist) {
                    if (world[n].edge_exist[EAST]) {
                        edges.buffer[world[n].edge_id[EAST]].ey += blockSize;
                        world[i].edge_id[EAST] = world[n].edge_id[EAST];
                        world[i].edge_exist[EAST] = true;
                    } else {
                        var edge = Edge{
                            .sx = @intCast((sx + x + 1) * blockSize),
                            .sy = @intCast(sy + y * blockSize),
                        };

                        edge.ex = edge.sx;
                        edge.ey = edge.sy + blockSize;

                        world[i].edge_id[EAST] = edges.len;
                        world[i].edge_exist[EAST] = true;

                        edges.append(edge) catch {};
                    }
                }

                if (!world[n].exist) {
                    if (world[w].edge_exist[NORTH]) {
                        edges.buffer[world[w].edge_id[NORTH]].ex += blockSize;
                        world[i].edge_id[NORTH] = world[w].edge_id[NORTH];
                        world[i].edge_exist[NORTH] = true;
                    } else {
                        var edge = Edge{
                            .sx = @intCast(sx + x * blockSize),
                            .sy = @intCast(sy + y * blockSize),
                        };

                        edge.ex = edge.sx + blockSize;
                        edge.ey = edge.sy;

                        world[i].edge_id[NORTH] = edges.len;
                        world[i].edge_exist[NORTH] = true;

                        edges.append(edge) catch {};
                    }
                }

                if (!world[s].exist) {
                    if (world[w].edge_exist[SOUTH]) {
                        edges.buffer[world[w].edge_id[SOUTH]].ex += blockSize;
                        world[i].edge_id[SOUTH] = world[w].edge_id[SOUTH];
                        world[i].edge_exist[SOUTH] = true;
                    } else {
                        var edge = Edge{
                            .sx = @intCast(sx + x * blockSize),
                            .sy = @intCast((sy + y + 1) * blockSize),
                        };

                        edge.ex = edge.sx + blockSize;
                        edge.ey = edge.sy;

                        world[i].edge_id[SOUTH] = edges.len;
                        world[i].edge_exist[SOUTH] = true;

                        edges.append(edge) catch {};
                    }
                }
            }
        }
    }
}