const std = @import("std");

pub fn main() !void {
    // You can use print statements as follows for debugging, they'll be visible when running tests.
    try std.io.getStdOut().writer().print("Logs from your program will appear here\n", .{});

    // Uncomment this to pass the first stage
    //
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // note the type of args here
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        try std.io.getStdErr().writer().print("Usage: {s} <database_file_path> <command>\n", .{args[0]});
        return;
    }

    var database_file_path: []const u8 = args[1];
    var command: []const u8 = args[2];

    // String comparison is sus here.
    if (std.mem.eql(u8, command, ".dbinfo")) {
        const dbInfo = try DBInfo.read(database_file_path);
        defer dbInfo.close();

        try std.io.getStdOut().writer().print("database page size: {}\n", .{dbInfo.page_size});
        try std.io.getStdOut().writer().print("number of tables: {}\n", .{dbInfo.table_count});
    }

    if (std.mem.eql(u8, command, ".tables")) {
        const dbInfo = try DBInfo.read(database_file_path);
        defer dbInfo.close();
    }
}

const DBInfo = struct {
    file: std.fs.File,
    page_size: u16,
    table_count: u16,

    pub fn read(database_file_path: []const u8) !DBInfo {
        var file = try std.fs.cwd().openFile(database_file_path, .{});
        errdefer file.close();

        var buf: [2]u8 = undefined;
        _ = try file.seekTo(16);
        _ = try file.read(&buf);
        const page_size = std.mem.readInt(u16, &buf, .Big);

        // The header is 100 bytes long https://www.sqlite.org/fileformat.html#the_database_header
        // After the header, we have the actual beginning of the first page that is the root page of the table b-tree for
        // the sqlite_schema table https://www.sqlite.org/fileformat.html#storage_of_the_sql_database_schema

        var page_type: [1]u8 = undefined;
        _ = try file.seekTo(100);
        _ = try file.read(&page_type);

        // We assert that the page is a table _leaf_ page, meaning we can only count the cells to get the table count
        std.debug.assert(page_type[0] == 0x0D);

        var buffer: [2]u8 = undefined;
        _ = try file.seekBy(2);
        _ = try file.read(&buffer);
        const table_count = std.mem.readInt(u16, &buffer, .Big);

        return DBInfo{ .page_size = page_size, .table_count = table_count, .file = file };
    }

    pub fn close(self: DBInfo) void {
        self.file.close();
    }

    pub fn table_names(self: DBInfo, allocator: std.mem.Allocator) ![][]u8 {
        _ = allocator;

        _ = try self.file.seekTo(100);

        var buffer: [2]u8 = undefined;
        _ = try self.file.seekBy(5);
        _ = try self.file.read(&buffer);
        const cell_content_start = std.mem.readInt(u16, &buffer, .Big);

        if (cell_content_start != 0) {
            _ = try self.file.seekTo(cell_content_start);
        } else {
            _ = try self.file.seekTo(65536);
        }

        for (0..self.table_count) |i| {
            // We are still in a table leaf page here
            // We need to read a cell properly
            // To read a cell properly we need to read a varint properly
            _ = i;
        }

        return [_][]u8{"hello"};
    }
};
