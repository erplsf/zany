const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // skip the binary name
    const maybe_filename = args.next();
    if (maybe_filename) |filename| {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        var read_buffer: [4096]u8 = undefined;
        var file_reader = file.reader(&read_buffer);
        const reader = &file_reader.interface;

        var writer = std.Io.Writer.Allocating.init(allocator);
        defer writer.deinit();

        _ = try reader.streamRemaining(&writer.writer);
        const tokens = try lex(allocator, writer.written());
        defer allocator.free(tokens);

        std.debug.print("{any}\n", .{tokens});
    } else {
        return error.NoFilenameProvided;
    }
}

const Keywords = enum {
    @"fn",
    unsigned,
    @"return",
};

const Token = union(enum) { Semicolon, ParenOpen, ParenClose, Keyword: Keywords, BraceOpen, BraceClose, Identifier: []const u8, Number: []const u8 };

fn process_identifier(allocator: Allocator, tokens: *std.ArrayList(Token), word: []const u8, start: *usize, end: *usize) !void {
    const identifier_len: usize = end.* - start.*;
    var maybe_token: ?Token = null;
    if (identifier_len > 0) {
        const identifier = word[start.*..end.*];
        if (std.meta.stringToEnum(Keywords, identifier)) |keyword| {
            maybe_token = .{ .Keyword = keyword };
        } else {
            if (std.mem.findAny(u8, identifier, "0123456789")) |_| {
                maybe_token = .{ .Number = identifier };
            } else {
                maybe_token = .{ .Identifier = identifier };
            }
        }
    }
    if (maybe_token) |token| {
        try tokens.append(allocator, token);
    }
    start.* = end.* + 1;
}

fn lex(allocator: Allocator, chars: []const u8) ![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    var lines_it = std.mem.splitScalar(u8, chars, '\n');
    while (lines_it.next()) |line| {
        if (line.len == 0) continue;
        var words_it = std.mem.splitScalar(u8, line, ' ');
        while (words_it.next()) |word| {
            if (word.len == 0) continue;
            var i: usize = 0;
            var identifier_start: usize = 0;
            while (i < word.len) : (i += 1) {
                switch (word[i]) {
                    ';' => {
                        try process_identifier(allocator, &tokens, word, &identifier_start, &i);
                        try tokens.append(allocator, Token.Semicolon);
                    },
                    '(' => {
                        try process_identifier(allocator, &tokens, word, &identifier_start, &i);
                        try tokens.append(allocator, Token.ParenOpen);
                    },
                    ')' => {
                        try process_identifier(allocator, &tokens, word, &identifier_start, &i);
                        try tokens.append(allocator, Token.ParenClose);
                    },
                    '{' => {
                        try process_identifier(allocator, &tokens, word, &identifier_start, &i);
                        try tokens.append(allocator, Token.BraceOpen);
                    },
                    '}' => {
                        try process_identifier(allocator, &tokens, word, &identifier_start, &i);
                        try tokens.append(allocator, Token.BraceClose);
                    },
                    else => {},
                }
            }
            try process_identifier(allocator, &tokens, word, &identifier_start, &i);
        }
    }
    return try tokens.toOwnedSlice(allocator);
}

test "basic lexing" {
    const allocator = std.testing.allocator;
    try std.testing.expectEqualSlices(Token, &.{}, try lex(allocator, ""));
    try std.testing.expectEqualSlices(Token, &.{}, try lex(allocator, "\n  \n"));
    const result = try lex(allocator, ";}{()");
    try std.testing.expectEqualSlices(Token, &.{ .Semicolon, .BraceClose, .BraceOpen, .ParenOpen, .ParenClose }, result);
    allocator.free(result);
}

test "more complex lexing" {
    const allocator = std.testing.allocator;
    {
        const result = try lex(allocator, ";;;");
        defer allocator.free(result);
        try std.testing.expectEqualSlices(Token, &.{ .Semicolon, .Semicolon, .Semicolon }, result);
    }
    {
        const result = try lex(allocator, "main()");
        defer allocator.free(result);
        try std.testing.expectEqual(3, result.len);
        try std.testing.expectEqualStrings("main", result[0].Identifier);
        try std.testing.expectEqualSlices(Token, &.{ .ParenOpen, .ParenClose }, result[1..]);
    }
    {
        const result = try lex(allocator, "return 42;");
        defer allocator.free(result);
        try std.testing.expectEqual(3, result.len);
        try std.testing.expectEqual(Token{ .Keyword = .@"return" }, result[0]);
        try std.testing.expectEqualStrings("42", result[1].Number);
        try std.testing.expectEqual(.Semicolon, result[2]);
    }
}

test "lex the whole program" {
    const allocator = std.testing.allocator;
    const program =
        \\fn main() unsigned {
        \\  return 42;
        \\}
    ;
    const result = try lex(allocator, program);
    defer allocator.free(result);
    try std.testing.expectEqual(10, result.len);
    try std.testing.expectEqual(Token{ .Keyword = .@"fn" }, result[0]);
    try std.testing.expectEqualStrings("main", result[1].Identifier);
    try std.testing.expectEqualSlices(Token, &.{ .ParenOpen, .ParenClose, .{ .Keyword = .unsigned }, .BraceOpen, .{ .Keyword = .@"return" } }, result[2..7]);
    try std.testing.expectEqualStrings("42", result[7].Number);
    try std.testing.expectEqualSlices(Token, &.{ .Semicolon, .BraceClose }, result[8..]);
}
