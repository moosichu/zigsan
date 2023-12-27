pub extern fn setCustomRecoverHandler(new_custom_recover_handler: *const *const fn (error_msg: []const u8) void) void;
