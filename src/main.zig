const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    // var allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    // try lex(allocator.allocator(), "");
}

const Keywords = enum {
    @"fn",
    unsigned,
    @"return",
};

const Token = union(enum) { Semicolon, ParenOpen, ParenClose, Keyword: Keywords, BraceOpen, BraceClose };

fn lex(allocator: Allocator, chars: []const u8) ![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    var lines_it = std.mem.splitScalar(u8, chars, '\n');
    while (lines_it.next()) |line| {
        if (line.len == 0) continue;
        var words_it = std.mem.splitScalar(u8, line, ' ');
        while (words_it.next()) |word| {
            if (word.len == 0) continue;
            var i: usize = 0;
            while (i < word.len) : (i += 1) {
                switch (word[i]) {
                    ';' => try tokens.append(allocator, Token.Semicolon),
                    '(' => try tokens.append(allocator, Token.ParenOpen),
                    ')' => try tokens.append(allocator, Token.ParenClose),
                    '{' => try tokens.append(allocator, Token.BraceOpen),
                    '}' => try tokens.append(allocator, Token.BraceClose),
                    else => {},
                }
            }
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
    const result = try lex(allocator, ";;;");
    try std.testing.expectEqualSlices(Token, &.{ .Semicolon, .Semicolon, .Semicolon }, result);
    allocator.free(result);
}
