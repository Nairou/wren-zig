const std = @import("std");
const mem = std.mem;
const wren = @import("wren.zig");

pub fn main() anyerror!void {
    var config: wren.WrenConfiguration = undefined;
    wren.wrenInitConfiguration(&config);
    config.write_fn = writeFn;
    config.error_fn = errorFn;
    config.bind_foreign_method_fn = bindForeignMethod;
    var vm = wren.wrenNewVM(&config);
    defer vm.free();

    _ = vm.interpret("main", "System.print(\"Hello, world!\")");

    const print_handle = vm.makeCallHandle("print(_)");
    vm.ensureSlots(2);
    vm.getVariable("main", "System", 0);
    vm.setSlotString(1, "Hello from zig!");
    const result = vm.call(print_handle);
    std.debug.print("Result: {}\n", .{ result });

    const foreignMethod =
        \\class Zig {
        \\  foreign static hello()
        \\  foreign static add(a, b)
        \\}
    ;
    _ = vm.interpret("main", foreignMethod);
    _ = vm.interpret("main", "System.print(Zig.hello())");
    _ = vm.interpret("main", "System.print(Zig.add(2, 3))");
}

pub export fn writeFn(vm: *wren.WrenVM, text: [*:0]const u8) void {
    _ = vm;
    const stdout = std.io.getStdOut().writer();
    stdout.print("{s}", .{ text }) catch unreachable;
}

pub export fn errorFn(vm: *wren.WrenVM, error_type: wren.WrenErrorType, module: [*:0]const u8, line: c_int, msg: [*:0]const u8) void {
    _ = vm;
    const stderr = std.io.getStdErr().writer();
    switch (error_type) {
        .WREN_ERROR_COMPILE => stderr.print("[{s} line {d}] [Error] {s}\n", .{ module, line, msg }) catch unreachable,
        .WREN_ERROR_STACK_TRACE => stderr.print("[{s} line {d}] in {s}\n", .{ module, line, msg }) catch unreachable,
        .WREN_ERROR_RUNTIME => stderr.print("[Runtime Error] {s}\n", .{ msg }) catch unreachable,
    }
}

pub export fn bindForeignMethod(vm: *wren.WrenVM, module: [*:0]const u8, class_name: [*:0]const u8, is_static: bool, signature: [*:0]const u8) ?wren.WrenForeignMethodFn {
    _ = vm;
    if (mem.eql(u8, mem.span(module), "main")) {
        if (mem.eql(u8, mem.span(class_name), "Zig")) {
            if (is_static) {
                if (mem.eql(u8, mem.span(signature), "add(_,_)")) {
                    return zigAdd;
                } else if (mem.eql(u8, mem.span(signature), "hello()")) {
                    return zigHello;
                }
            }
        }
    }
    return null;
}

pub export fn zigHello(vm: *wren.WrenVM) void {
    vm.setSlotString(0, "Hello from zig land!");
}

pub export fn zigAdd(vm: *wren.WrenVM) void {
    const a = vm.getSlotDouble(1);
    const b = vm.getSlotDouble(2);
    vm.setSlotDouble(0, a + b);
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}

test "ref all" {
    std.testing.refAllDecls(wren);
    std.testing.refAllDecls(wren.WrenVM);
}
