const std = @import("std");
const Allocator = std.mem.Allocator;

const lexer = @import("lexer.zig");

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
        const tokens = try lexer.lex(allocator, writer.written());
        defer allocator.free(tokens);

        std.debug.print("{any}\n", .{tokens});
    } else {
        return error.NoFilenameProvided;
    }
}

test {
    _ = @import("lexer.zig");
}
