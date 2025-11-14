const std = @import("std");
const httpz = @import("httpz");
const IDGenerator = @import("id_generator.zig").GiftIDGenerator;
const server = @import("server.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // skip program name

    var workshop_id: u16 = 1;
    var port: u16 = 8080;
    var host: []const u8 = "0.0.0.0";

    // Simple argument parsing
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--workshop-id")) {
            if (args.next()) |id_str| {
                workshop_id = try std.fmt.parseInt(u16, id_str, 10);
            }
        } else if (std.mem.eql(u8, arg, "--port")) {
            if (args.next()) |port_str| {
                port = try std.fmt.parseInt(u16, port_str, 10);
            }
        } else if (std.mem.eql(u8, arg, "--host")) {
            if (args.next()) |h| {
                host = h;
            }
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            return;
        }
    }

    // Initialize ID generator
    var id_generator = try IDGenerator.init(workshop_id);
    
    std.log.info("Starting Gift ID Service", .{});
    std.log.info("Workshop ID: {d}", .{workshop_id});
    std.log.info("Listening on {s}:{d}", .{ host, port });

    // Start HTTP server
    try server.start(allocator, &id_generator, host, port);
}

fn printHelp() void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(
        \\Gift ID Service - Distributed ID Generator for Santa's Workshop
        \\
        \\Usage: gift_id_service [options]
        \\
        \\Options:
        \\  --workshop-id <id>   Workshop ID (1-1023, default: 1)
        \\  --port <port>        Port to listen on (default: 8080)
        \\  --host <host>        Host to bind to (default: 0.0.0.0)
        \\  -h, --help          Show this help message
        \\
        \\API Endpoints:
        \\  POST /api/v1/gift-id/generate     Generate a new Gift ID
        \\  GET  /api/v1/gift-id/:id/decode   Decode a Gift ID
        \\  GET  /health                       Health check endpoint
        \\
    , .{}) catch {};
}

test "main smoke test" {
    // Basic test to ensure main compiles
    try std.testing.expect(true);
}