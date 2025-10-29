const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    // var allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    // try lex(allocator.allocator(), "");
}

const Token = union(enum) { Semicolon, ParenOpen, ParenClose };

fn lex(allocator: Allocator, chars: []const u8) ![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    var lines_it = std.mem.splitScalar(u8, chars, '\n');
    while (lines_it.next()) |line| {
        if (line.len == 0) continue;
        var words_it = std.mem.splitAny(u8, line, " ");
        while (words_it.next()) |word| {
            if (word.len == 0) continue;
            if (std.mem.eql(u8, word, ";")) {
                try tokens.append(allocator, Token.Semicolon);
            }
        }
    }
    return try tokens.toOwnedSlice(allocator);
}

test "basic lexing" {
    const allocator = std.testing.allocator;
    try std.testing.expectEqualSlices(Token, &.{}, try lex(allocator, ""));
    try std.testing.expectEqualSlices(Token, &.{}, try lex(allocator, "\n\n\n"));
    const result = try lex(allocator, ";");
    try std.testing.expectEqualSlices(Token, &.{Token.Semicolon}, result);
    allocator.free(result);
}
