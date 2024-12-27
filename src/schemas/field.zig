const FieldType = enum { Int, String, Enum, Array, Bool, U64 };

const Field = struct {
    name: []const u8,
    field_type: FieldType,
};

const Schema = struct {
    fields: []const Field,
};
