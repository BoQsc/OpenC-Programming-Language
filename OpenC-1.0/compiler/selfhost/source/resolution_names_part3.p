import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe bool resolution_lossless(
    ptr byte type_data,
    usize source_type,
    usize target_type
) {
    if source_type == target_type { return true; }
    usize source_kind = read_record_field(type_data, source_type, 0);
    usize target_kind = read_record_field(type_data, target_type, 0);
    if source_kind == 2 && target_kind == 2 {
        return read_record_field(type_data, source_type, 3) <=
            read_record_field(type_data, target_type, 3);
    }
    if ((source_kind == 3 || source_kind == 6) && target_kind == 3) {
        return read_record_field(type_data, source_type, 3) <=
            read_record_field(type_data, target_type, 3);
    }
    if source_kind == 4 && target_kind == 4 {
        return read_record_field(type_data, source_type, 3) <=
            read_record_field(type_data, target_type, 3);
    }
    return false;
}
