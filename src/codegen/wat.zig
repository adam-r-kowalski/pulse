const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;

const interner = @import("../interner.zig");
const Intern = interner.Intern;
const Interned = interner.Interned;
const types = @import("../lower.zig");
const IR = types.IR;
const Function = types.Function;
const Import = types.Import;
const Export = types.Export;
const Type = types.Type;
const Expression = types.Expression;
const BinaryOp = types.BinaryOp;
const Call = types.Call;
const If = types.If;
const LocalSet = types.LocalSet;

const Indent = u64;

pub fn indent(writer: List(u8).Writer, n: Indent) !void {
    try writer.writeAll("\n");
    for (0..n) |_| try writer.writeAll("    ");
}

fn typeString(writer: List(u8).Writer, t: Type) !void {
    switch (t) {
        .i32 => try writer.writeAll("i32"),
        .i64 => try writer.writeAll("i64"),
        .f32 => try writer.writeAll("f32"),
        .f64 => try writer.writeAll("f64"),
        .void => try writer.writeAll("void"),
        .function => |f| {
            const last = f.len - 1;
            for (f[0..last], 0..) |arg, i| {
                if (i > 0) try writer.writeAll(" ");
                try writer.writeAll("(param ");
                try typeString(writer, arg);
                try writer.writeAll(")");
            }
            switch (f[last]) {
                .void => {},
                else => |k| {
                    try writer.writeAll(" (result ");
                    try typeString(writer, k);
                    try writer.writeAll(")");
                },
            }
        },
    }
}

fn localGet(writer: List(u8).Writer, intern: Intern, interned: Interned) !void {
    const value = intern.lookup(interned);
    try writer.print("(local.get ${s})", .{value});
}

fn localSet(writer: List(u8).Writer, intern: Intern, local_set: LocalSet, i: Indent) !void {
    const value = intern.lookup(local_set.name);
    try writer.print("(local.set ${s}", .{value});
    try indent(writer, i);
    try expression(writer, intern, local_set.value.*, i);
    try writer.writeAll(")");
}

fn i32Const(writer: List(u8).Writer, intern: Intern, interned: Interned) !void {
    const value = intern.lookup(interned);
    try writer.print("(i32.const {s})", .{value});
}

fn i64Const(writer: List(u8).Writer, intern: Intern, interned: Interned) !void {
    const value = intern.lookup(interned);
    try writer.print("(i64.const {s})", .{value});
}

fn f32Const(writer: List(u8).Writer, intern: Intern, interned: Interned) !void {
    const value = intern.lookup(interned);
    try writer.print("(f32.const {s})", .{value});
}

fn f64Const(writer: List(u8).Writer, intern: Intern, interned: Interned) !void {
    const value = intern.lookup(interned);
    try writer.print("(f64.const {s})", .{value});
}

fn binaryOp(writer: List(u8).Writer, intern: Intern, op: []const u8, b: BinaryOp, i: Indent) !void {
    try writer.print("({s}", .{op});
    try indent(writer, i);
    try expression(writer, intern, b.left.*, i);
    try indent(writer, i);
    try expression(writer, intern, b.right.*, i);
    try writer.writeAll(")");
}

fn block(writer: List(u8).Writer, intern: Intern, exprs: []const Expression, i: Indent) !void {
    for (exprs) |expr| {
        try indent(writer, i);
        try expression(writer, intern, expr, i);
    }
}

fn call(writer: List(u8).Writer, intern: Intern, c: Call, i: Indent) !void {
    const name = intern.lookup(c.function);
    try writer.print("(call ${s}", .{name});
    for (c.arguments) |arg| {
        try indent(writer, i);
        try expression(writer, intern, arg, i);
    }
    try writer.writeAll(")");
}

fn ifElse(writer: List(u8).Writer, intern: Intern, c: If, i: Indent) !void {
    try writer.writeAll("(if ");
    switch (c.result) {
        .void => {},
        else => |t| {
            try writer.writeAll("(result ");
            try typeString(writer, t);
            try writer.writeAll(")");
        },
    }
    try indent(writer, i);
    try expression(writer, intern, c.condition.*, i);
    try indent(writer, i);
    try writer.writeAll("(then");
    try block(writer, intern, c.then, i + 1);
    try writer.writeAll(")");
    if (c.else_.len > 0) {
        try indent(writer, i);
        try writer.writeAll("(else");
        try block(writer, intern, c.else_, i + 1);
        try writer.writeAll(")");
    }
    try writer.writeAll(")");
}

fn unaryOp(writer: List(u8).Writer, intern: Intern, op: []const u8, e: Expression, i: Indent) !void {
    try writer.print("({s}", .{op});
    try indent(writer, i);
    try expression(writer, intern, e, i);
    try writer.writeAll(")");
}

fn expression(writer: List(u8).Writer, intern: Intern, expr: Expression, i: Indent) error{OutOfMemory}!void {
    switch (expr) {
        .local_get => |interned| try localGet(writer, intern, interned),
        .local_set => |local_set| try localSet(writer, intern, local_set, i + 1),
        .i32_const => |interned| try i32Const(writer, intern, interned),
        .i32_add => |b| try binaryOp(writer, intern, "i32.add", b, i + 1),
        .i32_sub => |b| try binaryOp(writer, intern, "i32.sub", b, i + 1),
        .i32_mul => |b| try binaryOp(writer, intern, "i32.mul", b, i + 1),
        .i32_div_s => |b| try binaryOp(writer, intern, "i32.div_s", b, i + 1),
        .i32_eq => |b| try binaryOp(writer, intern, "i32.eq", b, i + 1),
        .i32_rem_s => |b| try binaryOp(writer, intern, "i32.rem_s", b, i + 1),
        .i32_or => |b| try binaryOp(writer, intern, "i32.or", b, i + 1),
        .i32_gt_s => |b| try binaryOp(writer, intern, "i32.gt_s", b, i + 1),
        .i32_lt_s => |b| try binaryOp(writer, intern, "i32.lt_s", b, i + 1),
        .i32_trunc_f32_s => |v| try unaryOp(writer, intern, "i32.trunc_f32_s", v.*, i + 1),
        .i64_const => |interned| try i64Const(writer, intern, interned),
        .i64_add => |b| try binaryOp(writer, intern, "i64.add", b, i + 1),
        .i64_sub => |b| try binaryOp(writer, intern, "i64.sub", b, i + 1),
        .i64_mul => |b| try binaryOp(writer, intern, "i64.mul", b, i + 1),
        .i64_div_s => |b| try binaryOp(writer, intern, "i64.div_s", b, i + 1),
        .i64_eq => |b| try binaryOp(writer, intern, "i64.eq", b, i + 1),
        .i64_rem_s => |b| try binaryOp(writer, intern, "i64.rem_s", b, i + 1),
        .i64_gt_s => |b| try binaryOp(writer, intern, "i64.gt_s", b, i + 1),
        .i64_lt_s => |b| try binaryOp(writer, intern, "i64.lt_s", b, i + 1),
        .i64_trunc_f64_s => |v| try unaryOp(writer, intern, "i64.trunc_f64_s", v.*, i + 1),
        .f32_const => |interned| try f32Const(writer, intern, interned),
        .f32_add => |b| try binaryOp(writer, intern, "f32.add", b, i + 1),
        .f32_sub => |b| try binaryOp(writer, intern, "f32.sub", b, i + 1),
        .f32_mul => |b| try binaryOp(writer, intern, "f32.mul", b, i + 1),
        .f32_div => |b| try binaryOp(writer, intern, "f32.div", b, i + 1),
        .f32_eq => |b| try binaryOp(writer, intern, "f32.eq", b, i + 1),
        .f32_gt => |b| try binaryOp(writer, intern, "f32.gt", b, i + 1),
        .f32_lt => |b| try binaryOp(writer, intern, "f32.lt", b, i + 1),
        .f32_sqrt => |v| try unaryOp(writer, intern, "f32.sqrt", v.*, i + 1),
        .f32_convert_i32_s => |v| try unaryOp(writer, intern, "f32.convert_i32_s", v.*, i + 1),
        .f64_const => |interned| try f64Const(writer, intern, interned),
        .f64_add => |b| try binaryOp(writer, intern, "f64.add", b, i + 1),
        .f64_sub => |b| try binaryOp(writer, intern, "f64.sub", b, i + 1),
        .f64_mul => |b| try binaryOp(writer, intern, "f64.mul", b, i + 1),
        .f64_div => |b| try binaryOp(writer, intern, "f64.div", b, i + 1),
        .f64_eq => |b| try binaryOp(writer, intern, "f64.eq", b, i + 1),
        .f64_gt => |b| try binaryOp(writer, intern, "f64.gt", b, i + 1),
        .f64_lt => |b| try binaryOp(writer, intern, "f64.lt", b, i + 1),
        .f64_sqrt => |v| try unaryOp(writer, intern, "f64.sqrt", v.*, i + 1),
        .f64_convert_i64_s => |v| try unaryOp(writer, intern, "f64.convert_i64_s", v.*, i + 1),
        .block => |b| try block(writer, intern, b, i),
        .call => |c| try call(writer, intern, c, i + 1),
        .if_ => |c| try ifElse(writer, intern, c, i + 1),
    }
}

fn function(writer: List(u8).Writer, intern: Intern, f: Function, i: Indent) !void {
    try writer.writeAll("\n");
    try indent(writer, i);
    const name = intern.lookup(f.name);
    try writer.print("(func ${s}", .{name});
    for (f.parameters) |p| {
        const name_symbol = intern.lookup(p.name);
        try writer.print(" (param ${s} ", .{name_symbol});
        try typeString(writer, p.type);
        try writer.writeAll(")");
    }
    switch (f.return_type) {
        .void => {},
        else => |k| {
            try writer.writeAll(" (result ");
            try typeString(writer, k);
            try writer.writeAll(")");
        },
    }
    for (f.locals) |l| {
        const name_symbol = intern.lookup(l.name);
        try indent(writer, i + 1);
        try writer.print("(local ${s} ", .{name_symbol});
        try typeString(writer, l.type);
        try writer.writeAll(")");
    }
    try block(writer, intern, f.body, i + 1);
    try writer.writeAll(")");
}

fn foreignImport(writer: List(u8).Writer, intern: Intern, i: Import) !void {
    try writer.writeAll("\n");
    try indent(writer, 1);
    try writer.print("(import {s} {s} (func ${s} ", .{
        intern.lookup(i.path[0]),
        intern.lookup(i.path[1]),
        intern.lookup(i.name),
    });
    try typeString(writer, i.type);
    try writer.writeAll("))");
}

fn foreignExport(writer: List(u8).Writer, intern: Intern, e: Export) !void {
    try writer.writeAll("\n");
    try indent(writer, 1);
    const alias = intern.lookup(e.alias);
    const name = intern.lookup(e.name);
    try writer.print("(export \"{s}\" (func ${s}))", .{ alias, name });
}

pub fn wat(allocator: Allocator, intern: Intern, ir: IR) ![]const u8 {
    var list = List(u8).init(allocator);
    const writer = list.writer();
    try writer.writeAll("(module");
    for (ir.imports) |i| try foreignImport(writer, intern, i);
    for (ir.functions) |f| try function(writer, intern, f, 1);
    for (ir.exports) |e| try foreignExport(writer, intern, e);
    try writer.writeAll(")");
    return list.toOwnedSlice();
}
