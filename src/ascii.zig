const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

pub const ParticleParams = struct {
    pub const acc: f32 = 3.0;
    pub const hz: f32 = 30;
    pub const dt: f32 = 1 / hz;
    pub const particle_lifetime: f32 = 5.0;

    spawn_stdev: f32,
    max_particles: u32,
};

const Particle = struct {
    x: f32,
    y: f32,
    vel_x: f32,
    vel_y: f32,
    lifetime: f32,

    const Self = @This();
    pub fn init(x: f32, y: f32, lifetime: f32) Self {
        return .{
            .x = x,
            .y = y,
            .vel_x = 0,
            .vel_y = 0,
            .lifetime = lifetime,
        };
    }

    pub fn move(self: *Self) void {
        self.lifetime += ParticleParams.dt;
        self.vel_x += 0.01 * self.y * (System.WIDTH / 2 - self.x);
        // self.vel_y += ParticleParams.acc * ParticleParams.dt;
        self.vel_y += 0.001 * (System.HEIGHT / 2 - self.y);
        self.x += self.vel_x * ParticleParams.dt;
        self.y += self.vel_y * ParticleParams.dt;
    }

    pub fn reset(self: *Self, rand1: f32, rand2: f32, stdev: f32, width: f32, max_lifetime: f32) void {
        const pi = std.math.pi;
        const z0 = @sqrt(-2.0 * std.math.log(f32, rand1, std.math.e)) * std.math.cos(2.0 * pi * rand2);
        var x = (width / 2) + z0 * stdev;

        x = @max(0, @min(width - 1e-4, x));

        const lifetime = (self.x - std.math.floor(self.x)) * max_lifetime;
        self.x = x;
        self.y = 0;
        self.lifetime = lifetime;
        self.vel_x = 0;
        self.vel_y = 5 * rand2;
    }
};

const Ascii = struct {
    const characters: []const u8 = " .:!|||}]%&#";
    const err = error{index_out_of_range};
    const Self = @This();

    pub fn getChar(idx: usize) !u8 {
        if (idx < 0 or idx >= Self.characters.len) return Self.err.index_out_of_range;
        return Self.characters[idx];
    }
};

pub const System = struct {
    particles: std.ArrayList(Particle),
    params: ParticleParams,
    values: [System.WIDTH][System.HEIGHT]u8,

    num_reseted: u32,

    const WIDTH = 116;
    const HEIGHT = 30;

    const Self = @This();
    pub fn init(alloc: Allocator, stdev: f32, max_num_particles: u32) !Self {
        const params = ParticleParams{ .spawn_stdev = stdev, .max_particles = max_num_particles };

        const nx = Self.WIDTH;
        const ny = Self.HEIGHT;
        var values: [nx][ny]u8 = undefined;
        for (0..nx) |x| {
            for (0..ny) |y| {
                values[x][y] = 0;
            }
        }

        var particles = std.ArrayList(Particle).init(alloc);
        for (0..max_num_particles) |i| {
            const fi: f32 = @floatFromInt(i / max_num_particles);
            const numb = fi * std.math.pi;
            const dec = numb - std.math.floor(numb);
            const particle = Particle.init(-1, -1, dec * ParticleParams.particle_lifetime);
            try particles.append(particle);
        }

        return .{
            .particles = particles,
            .params = params,
            .values = values,
            .num_reseted = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.particles.deinit();
    }

    pub fn update(self: *Self) !void {
        self.num_reseted = 0;

        const nx = Self.WIDTH;
        const ny = Self.HEIGHT;
        var values: [nx][ny]u8 = undefined;
        for (0..nx) |x| {
            for (0..ny) |y| {
                values[x][y] = 0;
            }
        }
        self.values = values;

        var prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();

        for (self.particles.items) |*p| {
            p.move();

            var outside: bool = p.x < 0 or p.x >= Self.WIDTH or p.y < 0 or p.y >= Self.HEIGHT;
            while (p.lifetime > ParticleParams.particle_lifetime or outside) {
                outside = p.x < 0 or p.x >= Self.WIDTH or p.y < 0 or p.y >= Self.HEIGHT;
                const r1 = rand.float(f32);
                const r2: f32 = @floatCast(rand.float(f64));
                p.reset(r1, r2, self.params.spawn_stdev, Self.WIDTH, ParticleParams.particle_lifetime);

                self.num_reseted += 1;
            }

            const x: usize = @intFromFloat(std.math.floor(p.x));
            const y: usize = @intFromFloat(std.math.floor(p.y));

            self.values[x][y] += 1;
        }
    }

    pub fn display(self: Self) !void {
        var y: usize = Self.HEIGHT - 1;
        while (y >= 0) {
            var slice_row: [Self.WIDTH]u8 = [_]u8{' '} ** Self.WIDTH;
            for (0..Self.WIDTH) |x| {
                const item = self.values[x][y];
                const val = @min(Ascii.characters.len - 1, item);
                if (val == 0) continue;
                const char = try Ascii.getChar(val);
                slice_row[x] = char;
            }
            print("{s}\n", .{slice_row});
            if (y == 0) break;
            y -= 1;
        }
    }
};
