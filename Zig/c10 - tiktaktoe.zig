const std = @import("std");
const print = std.debug.print;
const GameStatus = enum { n, w1, w2, d };

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    var status: GameStatus = .n;
    var board: [3][3]u8 = .{ .{ '1', '2', '3' }, .{ '4', '5', '6' }, .{ '7', '8', '9' } };
    var turn: bool = true;

    defer {
        if (status == .w1) print("\n\nPlayer 1 is the winner of this game!\n", .{});
        if (status == .w2) print("\n\nPlayer 2 is the winner of this game!\n", .{});
        if (status == .d) print("\n\nThe game was a draw!\n", .{});
    }

    while (status == .n) {
        printBoard(board);
        var buffer: [8]u8 = undefined;
        const player: u8 = if (turn) 1 else 2;

        print("Player {}, Please enter your choice:", .{player});
        const input = try stdin.readUntilDelimiter(&buffer, '\n');

        if (input[0] > '0' and input[0] <= '9') {
            const char: u8 = if (turn) 'X' else 'O';
            const num = try std.fmt.parseInt(u8, input[0..1], 10);
            const row = @as(usize, (num - 1) / 3);
            const col = @as(usize, (num - 1) % 3);
            if (board[row][col] != 'X' and board[row][col] != 'O') {
                board[row][col] = char;
                turn = !turn;
                status = checkStatus(board);
            } else {
                print("Please enter a valid number\n", .{});
            }
        } else {
            print("Please enter a valid number\n", .{});
        }
    }
}

fn printBoard(b: [3][3]u8) void {
    for (b) |row| {
        for (row, 0..) |elem, i| {
            print("{c}", .{elem});
            if (i != 2) print(" | ", .{});
        }
        print("\n", .{});
    }
}

fn checkStatus(b: [3][3]u8) GameStatus {
    var row: usize = 0;
    const chars: [2]u8 = .{ 'X', 'O' };
    for (chars) |char| {
        const status: GameStatus = if (char == 'X') .w1 else .w2;
        while (row < 3) : (row += 1) {
            if (b[row][0] == b[row][1] and b[row][0] == b[row][2] and b[row][0] == char) return status;
            if (b[0][row] == b[1][row] and b[0][row] == b[2][row] and b[0][row] == char) return status;
        }

        if (b[0][0] == b[1][1] and b[0][0] == b[2][2] and b[0][0] == char) return status;
        if (b[0][2] == b[1][1] and b[0][2] == b[2][0] and b[0][2] == char) return status;
    }

    var draw: bool = true;
    for (b) |r| {
        for (r) |el| {
            if (el != 'X' and el != 'O') draw = false;
        }
    }

    if (draw) return .d;
    return .n;
}
