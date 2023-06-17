const std = @import("std");
const List = std.ArrayList;
const Writer = List(u8).Writer;

const types = @import("types.zig");

pub fn token(t: types.Token, writer: Writer) !void {
    switch (t) {
        .symbol => |s| try writer.print("(symbol {})", .{s.value}),
        .int => |i| try writer.print("(int {})", .{i.value}),
        .float => |f| try writer.print("(float {})", .{f.value}),
        .string => |s| try writer.print("(string {})", .{s.value}),
        .bool => |b| try writer.print("(bool {})", .{b.value}),
        .equal => try writer.writeAll("(operator =)"),
        .equal_equal => try writer.writeAll("(operator ==)"),
        .dot => try writer.writeAll("(operator .)"),
        .colon => try writer.writeAll("(operator :)"),
        .plus => try writer.writeAll("(operator +)"),
        .plus_equal => try writer.writeAll("(operator +=)"),
        .minus => try writer.writeAll("(operator -)"),
        .times => try writer.writeAll("(operator *)"),
        .times_equal => try writer.writeAll("(operator *=)"),
        .slash => try writer.writeAll("(operator /)"),
        .percent => try writer.writeAll("(operator %)"),
        .caret => try writer.writeAll("(operator ^)"),
        .greater => try writer.writeAll("(operator >)"),
        .less => try writer.writeAll("(operator <)"),
        .left_paren => try writer.writeAll("(delimiter '(')"),
        .right_paren => try writer.writeAll("(delimiter ')')"),
        .left_brace => try writer.writeAll("(delimiter '{')"),
        .right_brace => try writer.writeAll("(delimiter '}')"),
        .left_bracket => try writer.writeAll("(delimiter '[')"),
        .right_bracket => try writer.writeAll("(delimiter ']')"),
        .comma => try writer.writeAll("(delimiter ',')"),
        .if_ => try writer.writeAll("(keyword if)"),
        .else_ => try writer.writeAll("(keyword else)"),
        .or_ => try writer.writeAll("(keyword or)"),
        .fn_ => try writer.writeAll("(keyword fn)"),
        .mut => try writer.writeAll("(keyword mut)"),
        .undefined => try writer.writeAll("(keyword undefined)"),
        .new_line => try writer.writeAll("(new_line)"),
    }
}

pub fn tokens(ts: []const types.Token, writer: Writer) !void {
    for (ts, 0..) |t, i| {
        if (i != 0) try writer.writeAll("\n");
        try token(t, writer);
    }
}
