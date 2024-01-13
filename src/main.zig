const rl = @import("raylib");
const std = @import("std");

const screen_size = 1000;

const color = rl.Color;

// The map coordinates are allowed to be negative so that we wont get overflows when trying to hit the left or top wall
const MapPosition = struct { x: i16, y: i16 };
const Direction = enum { up, down, left, right };

// just make the death from collision into an error
const SnakeMovementError = error{ OutOfMemory, Collision };

pub fn main() anyerror!void {
    rl.initWindow(screen_size, screen_size, "Snake Game");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpaAllocator = gpa.allocator();

    var snake = std.ArrayList(MapPosition).init(gpaAllocator);
    var apple = MapPosition{ .x = 15, .y = 10 };
    defer snake.deinit();
    try snake.append(MapPosition{ .x = 10, .y = 10 });

    var dt: f64 = 0;

    var current_direction = Direction.right;

    while (!rl.windowShouldClose()) {
        // this variable checks if the snake should be appended in the next frame, thus not being cut off after the next step forward
        var snake_append: bool = false;
        dt += rl.getFrameTime();
        // Get input, has to be outside the actual movement part so that any frame detects a keystroke
        current_direction = switch (rl.getKeyPressed()) {
            rl.KeyboardKey.key_down => if (current_direction != Direction.up) Direction.down else current_direction,
            rl.KeyboardKey.key_up => if (current_direction != Direction.down) Direction.up else current_direction,
            rl.KeyboardKey.key_left => if (current_direction != Direction.right) Direction.left else current_direction,
            rl.KeyboardKey.key_right => if (current_direction != Direction.left) Direction.right else current_direction,
            else => current_direction,
        };

        // Each time we want to move our little friend
        if (dt > 0.2) {
            const fx = snake.items[0].x;
            const fy = snake.items[0].y;
            switch (current_direction) {
                .down => {
                    try moveSnake(MapPosition{ .x = fx, .y = fy + 1 }, &snake);
                },
                .up => {
                    try moveSnake(MapPosition{ .x = fx, .y = fy - 1 }, &snake);
                },
                .left => {
                    try moveSnake(MapPosition{ .x = fx - 1, .y = fy }, &snake);
                },
                .right => {
                    try moveSnake(MapPosition{ .x = fx + 1, .y = fy }, &snake);
                },
            }
            if (fx == apple.x and fy == apple.y) {
                snake_append = true;
                apple = makeApplePosition(&snake);
                std.debug.print("Apple captured at {d} {d},\n new apple placed at {d} {d}\n", .{ fx, fy, apple.x, apple.y });
            }
            // reset our variables
            dt = 0;
            if (!snake_append) {
                _ = snake.pop();
            } else snake_append = false;
        }
        rl.beginDrawing();
        defer rl.endDrawing();
        // Drawing part
        rl.drawRectangle(apple.x * 50, apple.y * 50, 50, 50, color.red);

        rl.drawRectangle(50 * snake.items[0].x, 50 * snake.items[0].y, 50, 50, color.black);
        for (snake.items[1..]) |snake_element| {
            rl.drawRectangle(50 * snake_element.x, 50 * snake_element.y, 50, 50, color.dark_blue);
        }

        // score is just the lenght of our snake so this is fine
        const score = try std.fmt.allocPrintZ(gpaAllocator, "{d}", .{snake.items.len});
        rl.drawText(score, 5, 5, 20, color.light_gray);

        rl.clearBackground(color.dark_green);
    }
}

fn moveSnake(to: MapPosition, snake: *std.ArrayList(MapPosition)) SnakeMovementError!void {
    const cx: i16 = to.x;
    const cy: i16 = to.y;
    if ((cx > 19) or (cx < 0) or (cy > 19) or (cy < 0)) return SnakeMovementError.Collision;

    // we have to loop through the entire snake to see if the head collides with any part of the tail, crashing the program is fine as death
    for (snake.items) |part| {
        if (part.x == cx and part.y == cy) return SnakeMovementError.Collision;
    }
    try snake.*.insert(0, MapPosition{ .x = cx, .y = cy });
}

fn makeApplePosition(snake: *std.ArrayList(MapPosition)) MapPosition {
    const seed: u64 = @intCast(std.time.microTimestamp());
    var rand = std.rand.DefaultPrng.init(seed);
    const x: u8 = rand.random().intRangeAtMost(u8, 0, 19);
    const y: u8 = rand.random().intRangeAtMost(u8, 0, 19);

    // recursively call this function until it has generated an apple which is not inside the snake anywhere
    for (snake.items) |part| {
        if (part.x == x and part.y == y) return makeApplePosition(snake);
    }
    return MapPosition{ .x = x, .y = y };
}
