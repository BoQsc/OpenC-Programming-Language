import system.io;
import windows.com;
import windows.winrt;

i32 verify_values() {
    com.Guid unknown = com.iid_unknown();
    if unknown.low != cast(u64, 0) { return 1; }
    if unknown.high != cast(u64, 5044031582654955712) { return 2; }
    if !com.succeeded(com.hresult(0)) { return 3; }
    if !com.failed(com.hresult(-1)) { return 4; }
    return 0;
}

i32 verify_com() {
    com.Apartment apartment;
    status initialized = com.initialize_multithreaded(out apartment);
    if !initialized.ok { return 10; }
    com.Unknown stream;
    status created = com.memory_stream(apartment, out stream);
    if !created.ok { com.apartment_destroy(apartment); return 11; }
    if !com.valid(stream) {
        com.unknown_destroy(stream);
        com.apartment_destroy(apartment);
        return 12;
    }
    if com.reference_count(stream) < 1 {
        com.unknown_destroy(stream);
        com.apartment_destroy(apartment);
        return 16;
    }
    com.Unknown queried;
    status query = com.query_interface(stream, com.iid_unknown(), out queried);
    if !query.ok {
        com.unknown_destroy(stream);
        com.apartment_destroy(apartment);
        return 13;
    }
    if com.reference_count(queried) < 1 {
        com.unknown_destroy(queried);
        com.unknown_destroy(stream);
        com.apartment_destroy(apartment);
        return 14;
    }
    com.Unknown cloned;
    status copied = com.clone(queried, out cloned);
    if !copied.ok {
        com.unknown_destroy(queried);
        com.unknown_destroy(stream);
        com.apartment_destroy(apartment);
        return 15;
    }
    com.unknown_destroy(cloned);
    com.unknown_destroy(queried);
    com.unknown_destroy(stream);
    com.apartment_destroy(apartment);
    return 0;
}

i32 verify_winrt() {
    winrt.Runtime runtime;
    status initialized = winrt.initialize_multithreaded(out runtime);
    if !initialized.ok { return 20; }
    winrt.HString name;
    status named = winrt.string_create(
        "Windows.Globalization.Calendar", out name
    );
    if !named.ok { winrt.runtime_destroy(runtime); return 21; }
    com.Unknown factory;
    status activated = winrt.activation_factory(
        name, winrt.iid_activation_factory(), out factory
    );
    if !activated.ok {
        winrt.string_destroy(name);
        winrt.runtime_destroy(runtime);
        return 22;
    }
    if !com.valid(factory) {
        com.unknown_destroy(factory);
        winrt.string_destroy(name);
        winrt.runtime_destroy(runtime);
        return 23;
    }
    com.Unknown instance;
    status activated_instance = winrt.activate_instance(factory, out instance);
    if !activated_instance.ok || !com.valid(instance) {
        com.unknown_destroy(instance);
        com.unknown_destroy(factory);
        winrt.string_destroy(name);
        winrt.runtime_destroy(runtime);
        return 24;
    }
    winrt.HString runtime_name;
    status class_named = winrt.runtime_class_name(instance, out runtime_name);
    if !class_named.ok {
        com.unknown_destroy(instance);
        com.unknown_destroy(factory);
        winrt.string_destroy(name);
        winrt.runtime_destroy(runtime);
        return 25;
    }
    if !winrt.valid(runtime_name) {
        winrt.string_destroy(runtime_name);
        com.unknown_destroy(instance);
        com.unknown_destroy(factory);
        winrt.string_destroy(name);
        winrt.runtime_destroy(runtime);
        return 26;
    }
    i32 trust;
    status trusted = winrt.trust_level(instance, out trust);
    if !trusted.ok {
        winrt.string_destroy(runtime_name);
        com.unknown_destroy(instance);
        com.unknown_destroy(factory);
        winrt.string_destroy(name);
        winrt.runtime_destroy(runtime);
        return 27;
    }
    if trust < 0 || trust > 2 {
        winrt.string_destroy(runtime_name);
        com.unknown_destroy(instance);
        com.unknown_destroy(factory);
        winrt.string_destroy(name);
        winrt.runtime_destroy(runtime);
        return 28;
    }
    winrt.string_destroy(runtime_name);
    com.unknown_destroy(instance);
    com.unknown_destroy(factory);
    winrt.string_destroy(name);
    winrt.runtime_destroy(runtime);
    return 0;
}

i32 main() {
    i32 result = verify_values();
    if result != 0 { return result; }
    result = verify_com();
    if result != 0 { return result; }
    result = verify_winrt();
    if result != 0 { return result; }
    io.println("OpenC SH-23 COM/WinRT projection PASS");
    return 0;
}
