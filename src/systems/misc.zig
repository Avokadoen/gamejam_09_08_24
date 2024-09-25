const tracy = @import("ztracy");
const ecez = @import("ecez");
const zm = @import("zmath");

const components = @import("../components.zig");
const Context = @import("Context.zig");

pub fn Create(Storage: type) type {
    return struct {
        const LifeTimetWriteView = Storage.Subset(
            .{components.InactiveTag},
            .read_and_write,
        );
        const LifetimeQuery = Storage.Query(struct {
            entity: ecez.Entity,
            life_time: *components.LifeTime,
        }, .{components.InactiveTag});
        pub fn lifeTime(
            lifetime: *LifetimeQuery,
            write_view: *LifeTimetWriteView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (lifetime.next()) |item| {
                if (item.life_time.value <= 0) {
                    write_view.setComponents(item.entity, .{components.InactiveTag{}}) catch (@panic("oom"));
                }
                item.life_time.value -= Context.delta_time;
            }
        }

        const PlayerCamView = Storage.Subset(
            .{
                components.Position,
                components.RectangleCollider,
            },
            .read_only,
        );
        const CameraUpdateView = Storage.Subset(
            .{
                components.Position,
                components.Scale,
                components.Camera,
            },
            .read_and_write,
        );
        pub fn updateCamera(
            camera_update_view: *CameraUpdateView,
            player_view: *PlayerCamView,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const camera = camera_update_view.getComponents(
                context.camera_entity,
                struct {
                    pos: *components.Position,
                    scale: components.Scale,
                    cam: components.Camera,
                },
            ) catch @panic("camera missing required comp");

            const player = player_view.getComponents(context.player_entity, struct {
                pos: components.Position,
                col: components.RectangleCollider,
            }) catch @panic("player entity missing");

            const camera_offset = zm.f32x4(
                (camera.cam.width * 0.5 - player.col.width * 0.5) / camera.scale.x,
                (camera.cam.height * 0.5 - player.col.height * 0.5) / camera.scale.y,
                0,
                0,
            );
            camera.pos.vec = player.pos.vec - camera_offset;
        }

        const OrientTextureQuery = Storage.Query(struct {
            velocity: components.Velocity,
            texture: *components.Texture,
            orientation_texture: components.OrientationTexture,
        }, .{components.InactiveTag});
        pub fn orientTexture(orient_textures: *OrientTextureQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (orient_textures.next()) |item| {
                {
                    // early out if velocity is none
                    const speed_estimate = zm.lengthSq2(item.velocity.vec)[0];
                    if (speed_estimate > -0.05 and speed_estimate < 0.05) {
                        continue;
                    }
                }

                var smalled_index: usize = 0;
                var smallest_dist = @import("std").math.floatMax(f32);
                for (&[_][2]f32{
                    .{ 0, -1 },
                    .{ -0.5, -0.5 },
                    .{ -1, 0 },
                    .{ -0.5, 0.5 },
                    .{ 0, 1 },
                    .{ 0.5, 0.5 },
                    .{ 1, 0 },
                    .{ 0.5, -0.5 },
                }, 0..) |direction_values, index| {
                    const move_dir = zm.normalize2(item.velocity.vec);
                    const direction = zm.f32x4(direction_values[0], direction_values[1], 0, 0);
                    const dist = zm.lengthSq2(move_dir - direction)[0];
                    if (dist < smallest_dist) {
                        smallest_dist = dist;
                        smalled_index = index;
                    }
                }

                item.texture.index = @intCast(item.orientation_texture.start_texture_index + smalled_index);
            }
        }

        const OrientDrawOrderQuery = Storage.Query(struct {
            texture: *components.Texture,
            orientation_draw_order: components.OrientationBasedDrawOrder,
            orientation_texture: components.OrientationTexture,
        }, .{components.InactiveTag});
        pub fn orientationBasedDrawOrder(orient_draw_order: *OrientDrawOrderQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (orient_draw_order.next()) |item| {
                const draw_order_index = item.texture.index - item.orientation_texture.start_texture_index;
                item.texture.draw_order = item.orientation_draw_order.draw_orders[draw_order_index];
            }
        }

        const AnimateQuery = Storage.Query(struct {
            texture: *components.Texture,
            anim: *components.AnimTexture,
        }, .{components.InactiveTag});
        pub fn animateTexture(animate: *AnimateQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (animate.next()) |item| {
                if (item.anim.frames_drawn_current_frame >= item.anim.frames_per_frame) {
                    item.anim.frames_drawn_current_frame = 0;
                    item.anim.current_frame = @mod((item.anim.current_frame + 1), item.anim.frame_count);
                    item.texture.index = item.anim.start_frame + item.anim.current_frame;
                }

                // TODO: if we split update and draw tick then this must be moved to draw
                item.anim.frames_drawn_current_frame += 1;
            }
        }
    };
}
