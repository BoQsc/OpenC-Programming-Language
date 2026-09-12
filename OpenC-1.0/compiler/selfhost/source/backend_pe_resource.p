import system.file;
import system.memory;
import system.text;

struct PeResourceBlob {
    ptr byte data;
    usize length;
    bool ok;
}

unsafe PeResourceBlob pe_resource_load(text path) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(path, out data, out length);
    if !loaded.ok {
        return PeResourceBlob{
            data = null, length = 0, ok = false
        };
    }
    if length > 16777216 {
        memory.free(data);
        return PeResourceBlob{
            data = null, length = 0, ok = false
        };
    }
    return PeResourceBlob{
        data = data,
        length = length,
        ok = true
    };
}

unsafe void pe_resource_directory(ref DBuffer output, usize id_entries) {
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, id_entries);
}

unsafe void pe_resource_tree(
    ref DBuffer output,
    usize type_directory,
    usize name_directory,
    usize data_entry,
    usize payload_rva,
    usize payload_size,
    usize code_page
) {
    pe32_pad_to(output, type_directory);
    pe_resource_directory(output, 1);
    pe32_put_u32(output, 1);
    pe32_put_u32(output, cast(usize, 2147483648) | name_directory);
    pe32_pad_to(output, name_directory);
    pe_resource_directory(output, 1);
    pe32_put_u32(output, 1033);
    pe32_put_u32(output, data_entry);
    pe32_pad_to(output, data_entry);
    pe32_put_u32(output, payload_rva);
    pe32_put_u32(output, payload_size);
    pe32_put_u32(output, code_page);
    pe32_put_u32(output, 0);
}

unsafe DBuffer pe32_build_resources(
    usize section_rva,
    text manifest_path,
    text resource_path
) {
    bool has_manifest = text.byte_length(manifest_path) != 0;
    bool has_resource = text.byte_length(resource_path) != 0;
    PeResourceBlob manifest = PeResourceBlob{
        data = null, length = 0, ok = true
    };
    PeResourceBlob resource_blob = PeResourceBlob{
        data = null, length = 0, ok = true
    };
    if has_manifest {
        manifest = pe_resource_load(manifest_path);
    }
    if manifest.ok && has_resource {
        resource_blob = pe_resource_load(resource_path);
    }
    usize count = 0;
    if has_resource { count = count + 1; }
    if has_manifest { count = count + 1; }
    DBuffer output = d_buffer_create(
        256 + manifest.length + resource_blob.length
    );
    if !manifest.ok || !resource_blob.ok || count == 0 {
        output.ok = false;
    }
    usize root_size = 16 + count * 8;
    usize tree_size = root_size + count * 64;
    usize payload = x64_align_up(tree_size, 4);
    pe_resource_directory(output, count);
    usize item = 0;
    if has_resource {
        pe32_put_u32(output, 10);
        pe32_put_u32(
            output,
            cast(usize, 2147483648) | (root_size + item * 64)
        );
        item = item + 1;
    }
    if has_manifest {
        pe32_put_u32(output, 24);
        pe32_put_u32(
            output,
            cast(usize, 2147483648) | (root_size + item * 64)
        );
    }
    item = 0;
    if has_resource {
        usize type_at = root_size + item * 64;
        pe_resource_tree(
            output, type_at, type_at + 24, type_at + 48,
            section_rva + payload, resource_blob.length, 0
        );
        payload = x64_align_up(payload + resource_blob.length, 4);
        item = item + 1;
    }
    if has_manifest {
        usize type_at = root_size + item * 64;
        pe_resource_tree(
            output, type_at, type_at + 24, type_at + 48,
            section_rva + payload, manifest.length, 65001
        );
    }
    pe32_pad_to(output, x64_align_up(tree_size, 4));
    if has_resource {
        usize index = 0;
        while index < resource_blob.length {
            d_put_byte(output, cast(u8, *(resource_blob.data + index)));
            index = index + 1;
        }
        pe32_pad_to(output, x64_align_up(output.length, 4));
    }
    if has_manifest {
        usize index = 0;
        while index < manifest.length {
            d_put_byte(output, cast(u8, *(manifest.data + index)));
            index = index + 1;
        }
        pe32_pad_to(output, x64_align_up(output.length, 4));
    }
    if resource_blob.data != null { memory.free(resource_blob.data); }
    if manifest.data != null { memory.free(manifest.data); }
    return output;
}
