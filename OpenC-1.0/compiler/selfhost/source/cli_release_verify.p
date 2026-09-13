import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool cli_release_package_workflow(
    text compiler,
    text distribution,
    text output_directory,
    ref usize elapsed
) {
    usize started = process.monotonic_milliseconds();
    usize task_elapsed = 0;
    DBuffer command = d_buffer_create(32768);
    cli_workflow_command_start(command, compiler, "test");
    cli_workflow_command_named_argument(
        command, "--manifest=", path.join(
            distribution, "tests/SH21_NATIVE_WORKFLOW_TESTS.json"
        )
    );
    cli_workflow_command_named_argument(
        command, "--report=", path.join(
            output_directory, "relocated-tests.json"
        )
    );
    bool passed = cli_release_run_task(
        command, "OpenC test: 5/5 passed", task_elapsed
    );
    d_buffer_destroy(command);
    if passed {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "pe-audit");
        cli_workflow_command_named_argument(command, "--input=", compiler);
        cli_workflow_command_named_argument(
            command, "--output=", path.join(
                output_directory, "relocated-pe-audit.json"
            )
        );
        passed = cli_release_run_task(
            command, "OpenC PE audit: PASS", task_elapsed
        );
        d_buffer_destroy(command);
    }
    if passed {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "pe-coff-audit");
        cli_workflow_command_named_argument(
            command, "--root=", distribution
        );
        cli_workflow_command_named_argument(
            command, "--artifacts=", path.join(
                output_directory, "relocated-pe-coff-artifacts"
            )
        );
        cli_workflow_command_named_argument(
            command, "--output=", path.join(
                output_directory, "relocated-pe-coff-audit.json"
            )
        );
        passed = cli_release_run_task(
            command,
            "OpenC PE/COFF ecosystem audit: PASS (40/40)",
            task_elapsed
        );
        d_buffer_destroy(command);
    }
    if passed {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "com-winrt-audit");
        cli_workflow_command_named_argument(
            command, "--root=", distribution
        );
        cli_workflow_command_named_argument(
            command, "--artifacts=", path.join(
                output_directory, "relocated-com-winrt-artifacts"
            )
        );
        cli_workflow_command_named_argument(
            command, "--output=", path.join(
                output_directory, "relocated-com-winrt-audit.json"
            )
        );
        passed = cli_release_run_task(
            command, "OpenC COM/WinRT audit: PASS (33/33)", task_elapsed
        );
        d_buffer_destroy(command);
    }
    if passed {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "lsp-audit");
        cli_workflow_command_named_argument(
            command, "--output=", path.join(
                output_directory, "relocated-lsp-audit.json"
            )
        );
        passed = cli_release_run_task(
            command, "OpenC native LSP audit: PASS (42/42)", task_elapsed
        );
        d_buffer_destroy(command);
    }
    if passed {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "editor-audit");
        cli_workflow_command_named_argument(command, "--root=", distribution);
        cli_workflow_command_named_argument(
            command, "--output=", path.join(
                output_directory, "relocated-editor-audit.json"
            )
        );
        passed = cli_release_run_task(
            command, "OpenC native editor audit: PASS (33/33)", task_elapsed
        );
        d_buffer_destroy(command);
    }
    if passed {
        text vsix_a = path.join(
            output_directory, "relocated-OpenC-vscode-1.0.0-a.vsix"
        );
        text vsix_b = path.join(
            output_directory, "relocated-OpenC-vscode-1.0.0-b.vsix"
        );
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "editor-package");
        cli_workflow_command_named_argument(command, "--root=", distribution);
        cli_workflow_command_named_argument(command, "--output=", vsix_a);
        passed = cli_release_run_task(
            command, "OpenC VS Code package: PASS (9/9 entries)", task_elapsed
        );
        d_buffer_destroy(command);
        if passed {
            command = d_buffer_create(32768);
            cli_workflow_command_start(command, compiler, "editor-package");
            cli_workflow_command_named_argument(command, "--root=", distribution);
            cli_workflow_command_named_argument(command, "--output=", vsix_b);
            passed = cli_release_run_task(
                command, "OpenC VS Code package: PASS (9/9 entries)", task_elapsed
            );
            d_buffer_destroy(command);
        }
        if passed {
            command = d_buffer_create(32768);
            cli_workflow_command_start(command, compiler, "finalization-audit");
            cli_workflow_command_named_argument(command, "--root=", distribution);
            cli_workflow_command_named_argument(command, "--vsix-a=", vsix_a);
            cli_workflow_command_named_argument(command, "--vsix-b=", vsix_b);
            cli_workflow_command_named_argument(
                command, "--clean-profile=", path.join(
                    distribution, "review/SH25_WINDOWS_EDITOR_EVIDENCE.json"
                )
            );
            cli_workflow_command_named_argument(
                command, "--output=", path.join(
                    output_directory, "relocated-finalization-audit.json"
                )
            );
            passed = cli_release_run_task(
                command, "OpenC SH-25 finalization audit: PASS (44/44)",
                task_elapsed
            );
            d_buffer_destroy(command);
        }
    }
    if passed {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "contract-audit");
        cli_workflow_command_named_argument(command, "--root=", distribution);
        cli_workflow_command_named_argument(
            command, "--output=", path.join(
                output_directory, "relocated-contract-audit.json"
            )
        );
        passed = cli_release_run_task(
            command, "OpenC native contract audit: PASS (38/38)", task_elapsed
        );
        d_buffer_destroy(command);
    }
    elapsed = process.monotonic_milliseconds() - started;
    return passed;
}

unsafe bool cli_release_relocated_verify(
    text output_directory,
    text root_name,
    text compiler_hash,
    usize standalone_entries,
    ref CliReleaseResult result
) {
    text extraction = path.join(output_directory, "relocated");
    if !cli_release_ensure_directory(extraction) { return false; }
    text archive = path.join(output_directory, "standalone-a.zip");
    usize archive_bytes = 0;
    usize entries = 0;
    usize peak = 0;
    bool extracted = cli_zip_verify_extract(
        archive, root_name, extraction, true, standalone_entries,
        archive_bytes, entries, peak
    );
    text distribution = path.join(extraction, root_name);
    usize manifest_entries = 0;
    result.manifest_verified = extracted && cli_release_verify_manifest(
        distribution, standalone_entries, manifest_entries
    );
    result.manifest_entries = manifest_entries;
    text packaged = path.join(distribution, "openc.exe");
    text project = path.join(
        distribution, "compiler/selfhost/openc.project.json"
    );
    text stage2 = path.join(output_directory, "relocated-stage2.exe");
    text stage3 = path.join(output_directory, "relocated-stage3.exe");
    DBuffer command = d_buffer_create(32768);
    cli_workflow_command_start(command, packaged, "build");
    cli_workflow_command_named_argument(command, "--project=", project);
    cli_workflow_command_named_argument(command, "--output=", stage2);
    bool stage2_ok = cli_release_run_task(
        command, "", result.stage2_elapsed
    );
    d_buffer_destroy(command);
    command = d_buffer_create(32768);
    cli_workflow_command_start(command, stage2, "build");
    cli_workflow_command_named_argument(command, "--project=", project);
    cli_workflow_command_named_argument(command, "--output=", stage3);
    bool stage3_ok = stage2_ok && cli_release_run_task(
        command, "", result.stage3_elapsed
    );
    d_buffer_destroy(command);
    DBuffer stage2_hash = d_buffer_create(65);
    DBuffer stage3_hash = d_buffer_create(65);
    result.stage_closure = stage3_ok &&
        cli_release_hash_file(stage2, stage2_hash) &&
        cli_release_hash_file(stage3, stage3_hash) &&
        d_buffer_text(stage2_hash) == d_buffer_text(stage3_hash);
    result.stage2_hash = d_buffer_text(stage2_hash);
    result.stage3_hash = d_buffer_text(stage3_hash);

    result.daily_workflow = result.stage_closure &&
        cli_release_package_workflow(
            stage3, distribution, output_directory, result.workflow_elapsed
        );

    command = d_buffer_create(32768);
    cli_workflow_command_start(command, stage3, "validate");
    cli_workflow_command_named_argument(
        command, "--manifest=", path.join(
            distribution, "conformance/fixtures/MANIFEST.json"
        )
    );
    cli_workflow_command_named_argument(
        command, "--output=", path.join(
            output_directory, "relocated-conformance.json"
        )
    );
    result.conformance = result.daily_workflow && cli_release_run_task(
        command, "278/278", result.conformance_elapsed
    );
    d_buffer_destroy(command);
    return result.manifest_verified && result.stage_closure &&
        result.daily_workflow && result.conformance;
}
