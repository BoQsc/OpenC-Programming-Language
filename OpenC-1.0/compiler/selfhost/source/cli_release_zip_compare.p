import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool cli_release_files_equal(text left_path, text right_path) {
    ptr byte left;
    usize left_length;
    status left_loaded = file.read_bytes_raw(
        left_path, out left, out left_length
    );
    if !left_loaded.ok { return false; }
    if left_length > 67108864 {
        memory.free(left);
        return false;
    }
    ptr byte right;
    usize right_length;
    status right_loaded = file.read_bytes_raw(
        right_path, out right, out right_length
    );
    bool equal = false;
    if right_loaded.ok {
        equal = left_length == right_length &&
            cli_zip_bytes_equal(left, right, left_length);
        memory.free(right);
    }
    memory.free(left);
    return equal;
}
