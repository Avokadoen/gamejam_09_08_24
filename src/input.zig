const std = @import("std");

const rl = @import("raylib");
const ecez = @import("ecez");
const zm = @import("zmath");

const components = @import("components.zig");
const GameTextureRepo = @import("GameTextureRepo.zig");

const delta_time: f32 = 1.0 / 60.0;

pub fn CreateInput(Storage: type) type {
    return struct {
        fn moveUp(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            _ = staff_entity;
            const vel = storage.getComponent(player_entity, *components.Velocity) catch unreachable;

            vel.vec[1] -= 10;
            if (vel.vec[1] > -500) {
                vel.vec[1] -= 100;
            }
        }

        fn moveDown(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            _ = staff_entity;
            const vel = storage.getComponent(player_entity, *components.Velocity) catch unreachable;

            if (vel.vec[1] < 500) {
                vel.vec[1] += 100;
            }
        }

        fn moveRight(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            _ = staff_entity;
            const vel = storage.getComponent(player_entity, *components.Velocity) catch unreachable;

            if (vel.vec[0] < 500) {
                vel.vec[0] += 100;
            }
        }

        fn moveLeft(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            _ = staff_entity;
            const vel = storage.getComponent(player_entity, *components.Velocity) catch unreachable;

            if (vel.vec[0] > -500) {
                vel.vec[0] -= 100;
            }
        }

        fn shootUp(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const vel = storage.getComponent(player_entity, components.Velocity) catch unreachable;

            const projectile_vel = vel.vec + zm.f32x4(
                0,
                -1000,
                0,
                0,
            );
            fireProjectile(projectile_vel, storage, player_entity, staff_entity);
        }

        fn shootDown(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const vel = storage.getComponent(player_entity, components.Velocity) catch unreachable;

            const projectile_vel = vel.vec + zm.f32x4(
                0,
                1000,
                0,
                0,
            );
            fireProjectile(projectile_vel, storage, player_entity, staff_entity);
        }

        fn shootRight(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const vel = storage.getComponent(player_entity, components.Velocity) catch unreachable;

            const projectile_vel = vel.vec + zm.f32x4(
                1000,
                0,
                0,
                0,
            );
            fireProjectile(projectile_vel, storage, player_entity, staff_entity);
        }

        fn shootLeft(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const vel = storage.getComponent(player_entity, components.Velocity) catch unreachable;

            const projectile_vel = vel.vec + zm.f32x4(
                -1000,
                0,
                0,
                0,
            );
            fireProjectile(projectile_vel, storage, player_entity, staff_entity);
        }

        fn fireProjectile(vel: zm.Vec, storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const Projectile = struct {
                pos: components.Position,
                rot: components.Rotation,
                vel: components.Velocity,
                collider: components.CircleCollider,
                texture: components.Texture,
                anim: components.AnimTexture,
                tag: components.DrawCircleTag,
                life_time: components.LifeTime,
                projectile: components.Projectile,
            };

            const ProjectileQuery = Storage.Query(struct {
                entity: ecez.Entity,
                pos: *components.Position,
                rot: *components.Rotation,
                vel: *components.Velocity,
                collider: *components.CircleCollider,
                texture: *components.Texture,
                anim: *components.AnimTexture,
                life_time: *components.LifeTime,
                _: components.InactiveTag,
                projectile: *components.Projectile,
            }, .{});

            const fire_rate = storage.getComponent(staff_entity, *components.FireRate) catch unreachable;
            if (fire_rate.cooldown_fire_rate == 0) {
                const pos = storage.getComponent(player_entity, components.Position) catch unreachable;
                const staff_comp_ptr = storage.getComponent(staff_entity, *components.Staff) catch unreachable;
                const next_projectile = findNextStaffProjectile(staff_comp_ptr) orelse return;

                const start_frame, const frame_count = switch (next_projectile.type) {
                    .bolt => .{
                        @intFromEnum(GameTextureRepo.which_projectile.Bolt_01),
                        @intFromEnum(GameTextureRepo.which_projectile.Bolt_05) - @intFromEnum(GameTextureRepo.which_projectile.Bolt_01),
                    },
                    .red_gem => .{
                        @intFromEnum(GameTextureRepo.which_projectile.Red_Gem_01),
                        @intFromEnum(GameTextureRepo.which_projectile.Red_Gem_10) - @intFromEnum(GameTextureRepo.which_projectile.Red_Gem_01),
                    },
                };

                const norm_vel = zm.normalize2(vel);
                const rotation = std.math.atan2(norm_vel[1], norm_vel[0]);
                const collider_offset_x: f32 = 50;
                const collider_offset_y: f32 = 33;

                const cs = @cos(rotation);
                const sn = @sin(rotation);

                const proj_offset = zm.normalize2(vel) * @as(zm.Vec, @splat(15));

                var projectile_iter = ProjectileQuery.submit(storage);
                if (projectile_iter.next()) |projectile| {
                    projectile.pos.* = components.Position{ .vec = pos.vec + proj_offset };
                    projectile.rot.* = components.Rotation{ .value = 0 };
                    projectile.vel.* = components.Velocity{ .vec = vel, .drag = 0.98 };
                    projectile.collider.* = components.CircleCollider{
                        .x = @floatCast(collider_offset_x * cs - collider_offset_y * sn),
                        .y = @floatCast(collider_offset_x * sn + collider_offset_y * cs),
                        .radius = 10,
                    };
                    projectile.texture.* = components.Texture{
                        .type = @intFromEnum(GameTextureRepo.texture_type.projectile),
                        .index = start_frame,
                        .draw_order = .o3,
                    };
                    projectile.anim.* = components.AnimTexture{
                        .start_frame = start_frame,
                        .current_frame = 0,
                        .frame_count = frame_count,
                        .frames_per_frame = 4,
                        .frames_drawn_current_frame = 0,
                    };
                    projectile.life_time.* = components.LifeTime{
                        .value = 1.3,
                    };
                    projectile.projectile.* = next_projectile.attrs;

                    storage.removeComponent(projectile.entity, components.InactiveTag) catch unreachable;
                } else {
                    _ = storage.createEntity(Projectile{
                        .pos = components.Position{ .vec = pos.vec + proj_offset },
                        .rot = components.Rotation{ .value = 0 },
                        .vel = components.Velocity{ .vec = vel, .drag = 0.98 },
                        .collider = components.CircleCollider{
                            .x = @floatCast(collider_offset_x * cs - collider_offset_y * sn),
                            .y = @floatCast(collider_offset_x * sn + collider_offset_y * cs),
                            .radius = 10,
                        },
                        .texture = components.Texture{
                            .type = @intFromEnum(GameTextureRepo.texture_type.projectile),
                            .index = start_frame,
                            .draw_order = .o3,
                        },
                        .anim = components.AnimTexture{
                            .start_frame = start_frame,
                            .current_frame = 0,
                            .frame_count = frame_count,
                            .frames_per_frame = 4,
                            .frames_drawn_current_frame = 0,
                        },
                        .tag = components.DrawCircleTag{},
                        .life_time = components.LifeTime{
                            .value = 1.3,
                        },
                        .projectile = next_projectile.attrs,
                    }) catch (@panic("rip projectiles"));
                }

                fire_rate.cooldown_fire_rate = fire_rate.base_fire_rate;
            }
        }

        const action = struct {
            key: rl.KeyboardKey,
            callback: fn (storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void,
        };

        pub const key_down_actions = [_]action{
            .{
                .key = .key_w,
                .callback = moveUp,
            },
            .{
                .key = .key_s,
                .callback = moveDown,
            },
            .{
                .key = .key_d,
                .callback = moveRight,
            },
            .{
                .key = .key_a,
                .callback = moveLeft,
            },
            .{
                .key = .key_up,
                .callback = shootUp,
            },
            .{
                .key = .key_down,
                .callback = shootDown,
            },
            .{
                .key = .key_right,
                .callback = shootRight,
            },
            .{
                .key = .key_left,
                .callback = shootLeft,
            },
        };
    };
}

pub fn findNextStaffProjectile(staff: *components.Staff) ?components.Staff.ProjectileAttribs {
    var slots_checked: u8 = 0;
    while (staff.slots[staff.slot_cursor] != .projectile and slots_checked < staff.used_slots) {
        slots_checked += 1;
        staff.slot_cursor = @mod((staff.slot_cursor + 1), staff.used_slots);
    }

    // If we found our next projectile
    if (staff.slots[staff.slot_cursor] == .projectile) {
        staff.slot_cursor = @mod((staff.slot_cursor + 1), staff.used_slots);
        return staff.slots[staff.slot_cursor].projectile;
    }

    return null;
}
