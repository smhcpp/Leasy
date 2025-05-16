const rl = @import("raylib");
const std = @import("std");
const print = std.debug.print;
const Point = struct { x: i16 = 1, y: i16 = 0 };

const Game = struct {
    direction: Point = Point{},
    allocator: std.mem.Allocator,
    W: i16,
    H: i16,
    snake: std.ArrayList(Point),
    food: Point = Point{},

    pub fn init(allocator: std.mem.Allocator, W: i16, H: i16) !*Game {
        const game = try allocator.create(Game);
        game.* = Game{
            .W = W,
            .H = H,
            .snake = std.ArrayList(Point).init(allocator),
            .allocator = allocator,
        };

        try game.snake.append(Point{ .x = 20, .y = 15 });
        game.freshFood();

        return game;
    }

    pub fn move(game: *Game) !void {
        var i = game.snake.items.len - 1;
        const tailx = game.snake.items[i].x;
        const taily = game.snake.items[i].y;

        while (i > 0) : (i -= 1) {
            game.snake.items[i].x = game.snake.items[i - 1].x;
            game.snake.items[i].y = game.snake.items[i - 1].y;
        }
        game.snake.items[0].x += game.direction.x;
        game.snake.items[0].y += game.direction.y;

        if (game.food.x == game.snake.items[0].x and game.snake.items[0].y == game.food.y) {
            try game.snake.append(Point{ .x = tailx, .y = taily });
            game.freshFood();
        }
    }

    pub fn freshFood(game: *Game) void {
        const seed: u64 = @intCast(std.time.nanoTimestamp());
        var prng = std.Random.DefaultPrng.init(seed);
        var rng = prng.random();
        game.food.x = rng.intRangeAtMost(i16, 0, game.W - 1);
        game.food.y = rng.intRangeAtMost(i16, 0, game.H - 1);
    }

    pub fn crashed(game: *Game) bool {
        var i = game.snake.items.len - 1;
        while (i > 0) : (i -= 1) {
            const it = game.snake.items[i];
            if (it.x == game.snake.items[0].x and it.y == game.snake.items[0].y) {
                return true;
            }
        }

        if (game.snake.items[0].x < 0 or game.snake.items[0].y < 0 or game.snake.items[0].x >= game.W or game.snake.items[0].y >= game.H) {
            return true;
        }
        return false;
    }

    pub fn deinit(game: *Game) void {
        game.snake.deinit();
    }
};

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;
    const cellsize: i16 = 20;
    const frametime: u64 = 200_000_000;
    var game = try Game.init(std.heap.page_allocator, 40, 30);
    defer game.deinit();

    rl.initWindow(screenWidth, screenHeight, "snake game");
    defer rl.closeWindow(); // Close window and OpenGL context

    var previoustime = std.time.nanoTimestamp();

    rl.setTargetFPS(30); // Set our game to run at 60 frames-per-second
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        if (rl.isKeyDown(.q)) break;

        if (rl.isKeyDown(.h)) {
            game.direction.x = -1;
            game.direction.y = 0;
        }

        if (rl.isKeyDown(.j)) {
            game.direction.x = 0;
            game.direction.y = 1;
        }

        if (rl.isKeyDown(.k)) {
            game.direction.x = 0;
            game.direction.y = -1;
        }

        if (rl.isKeyDown(.l)) {
            game.direction.x = 1;
            game.direction.y = 0;
        }

        const now = std.time.nanoTimestamp();
        if (now - previoustime >= frametime) {
            previoustime = now;
            try game.move();
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        rl.drawCircle(@intCast(game.food.x * cellsize + cellsize / 2), @intCast(game.food.y * cellsize + cellsize / 2), @floatFromInt(cellsize / 2), rl.Color.red);
        for (game.snake.items) |it| {
            rl.drawRectangle(@intCast(it.x * cellsize), @intCast(it.y * cellsize), @intCast(cellsize), @intCast(cellsize), rl.Color.green);
        }

        if (game.crashed()) break;
    }
    print("****************************\n", .{});
    print("****************************\n", .{});
    print("Your final point is {}\n", .{game.snake.items.len});
    print("****************************\n", .{});
    print("****************************\n", .{});
}
