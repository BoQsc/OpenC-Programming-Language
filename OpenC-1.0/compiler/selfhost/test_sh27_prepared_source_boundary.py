#!/usr/bin/env python3
"""Static ownership checklist for the opt-in prepared-source vertical slice."""

from __future__ import annotations

from pathlib import Path
import re
import unittest


SOURCE = Path(__file__).resolve().parent / "source"


class PreparedSourceBoundaryTests(unittest.TestCase):
    def test_every_context_field_has_exactly_one_owner(self) -> None:
        declarations = (SOURCE / "ir.p").read_text(encoding="utf-8")
        implementation = (SOURCE / "ir_prepared_source.p").read_text(
            encoding="utf-8"
        )
        context = declarations.split("struct IrContext {", 1)[1].split(
            "}", 1
        )[0]
        scratch = declarations.split("struct IrFunctionScratch {", 1)[1].split(
            "}", 1
        )[0]
        fields = lambda body: re.findall(
            r"^\s*(?:text|ptr byte|PackedBuffer|usize|bool)\s+([a-z_]+);",
            body, re.MULTILINE,
        )
        all_fields = fields(context)
        scratch_fields = fields(scratch)
        self.assertEqual(len(all_fields), 120)
        self.assertEqual(len(scratch_fields), 58)
        self.assertEqual(len(set(all_fields)), len(all_fields))
        self.assertEqual(len(set(scratch_fields)), len(scratch_fields))
        self.assertTrue(set(scratch_fields) < set(all_fields))
        for field in all_fields:
            with self.subTest(field=field):
                if field in scratch_fields:
                    self.assertIn(
                        f"prepared.view.{field} = view.{field};",
                        implementation,
                    )
                    self.assertIn(
                        f"context.{field} = scratch.{field};",
                        implementation,
                    )
                else:
                    self.assertIn(
                        f"prepared.view.{field} = source.{field};",
                        implementation,
                    )
                    self.assertIn(
                        f"context.{field} = prepared.view.{field};",
                        implementation,
                    )

    def test_every_mutable_scratch_field_is_cleared_bound_and_captured(self) -> None:
        declarations = (SOURCE / "ir.p").read_text(encoding="utf-8")
        implementation = (SOURCE / "ir_prepared_source.p").read_text(
            encoding="utf-8"
        )
        struct = declarations.split("struct IrFunctionScratch {", 1)[1].split(
            "}", 1
        )[0]
        fields = re.findall(
            r"^\s*(?:ptr byte|PackedBuffer|usize)\s+([a-z_]+);",
            struct, re.MULTILINE,
        )
        self.assertGreaterEqual(len(fields), 30)
        for field in fields:
            with self.subTest(field=field):
                self.assertIn(f"view.{field} =", implementation)
                self.assertIn(f"{field} = source.{field}", implementation)
                self.assertIn(
                    f"context.{field} = scratch.{field}", implementation
                )
                self.assertIn(
                    f"scratch.{field} = context.{field}", implementation
                )

    def test_boundary_allocates_no_source_or_worker_arena(self) -> None:
        implementation = (SOURCE / "ir_prepared_source.p").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("memory.alloc", implementation)
        self.assertNotIn("memory.realloc", implementation)
        self.assertNotIn("c_native_parallel_jobs", implementation)
        self.assertNotIn("PREPARED DEBUG", implementation)

    def test_lowering_and_native_emission_do_not_write_frozen_arrays(self) -> None:
        frozen = (
            "syntax_data", "token_data", "symbol_data", "detail_data",
            "source_data", "statement_nodes", "expression_nodes",
            "function_at_position", "declaration_symbol_cache",
            "top_symbols",
        )
        target = "|".join(frozen)
        writes = re.compile(
            rf"write_(?:record_field|usize|byte)\s*\(\s*"
            rf"(?:context\.)?(?:{target})\b", re.DOTALL,
        )
        for path in SOURCE.glob("*.p"):
            if not path.name.startswith(("ir_lower", "ir_control", "backend_native")):
                continue
            with self.subTest(path=path.name):
                self.assertIsNone(writes.search(path.read_text(encoding="utf-8")))

    def test_opt_in_default_and_chunk_propagation(self) -> None:
        backend = (SOURCE / "backend.p").read_text(encoding="utf-8")
        cli = (SOURCE / "cli_artifact.p").read_text(encoding="utf-8")
        source = (SOURCE / "backend_c_project_source.p").read_text(
            encoding="utf-8"
        )
        chunks = (SOURCE / "backend_c_parallel_state.p").read_text(
            encoding="utf-8"
        )
        self.assertIn("prepared_function_scratch = false", backend)
        self.assertIn('value == "--prepared-function-scratch"', cli)
        self.assertIn('value == "--freeze-function-types"', cli)
        self.assertIn('value == "--owned-function-project-caches"', cli)
        self.assertIn(
            "timings.prepared_function_scratch && timings.emission_mode == 2",
            source,
        )
        for name in ("one", "two", "three", "four"):
            self.assertIn(
                f"state.chunk_{name}.timings.prepared_function_scratch =",
                chunks,
            )
            self.assertIn(
                f"state.chunk_{name}.timings.freeze_function_types =",
                chunks,
            )
            self.assertIn(
                f"state.chunk_{name}.timings.owned_function_project_caches =",
                chunks,
            )

    def test_project_cache_snapshot_has_bounded_distinct_worker_storage(self) -> None:
        source = (SOURCE / "backend_c_project_source.p").read_text(
            encoding="utf-8"
        )
        self.assertIn("usize max_words = 131072;", source)
        self.assertIn("if words > max_words", source)
        self.assertIn("usize type_slots = source_context.types.length;", source)
        self.assertIn("scratch.native_layout_cache_entries = type_slots;", source)
        self.assertIn(
            "source_context.native_layout_cache_entries = source_layout_entries;",
            source,
        )
        for name in (
            "symbol_export_cache", "native_layout_size_cache",
            "native_layout_alignment_cache", "native_layout_state_cache",
        ):
            self.assertIn(f"scratch.{name} = owned_", source)
            self.assertIn(f"source_context.{name} = source_", source)
        for name in (
            "owned_export", "owned_layout_size", "owned_layout_alignment",
            "owned_layout_state",
        ):
            self.assertIn(f"scope memory.free({name});", source)
        self.assertIn("OPENC-FUNCTION-PROJECT-CACHE-ALIAS", source)
        self.assertIn("owned_function_project_cache_bytes", source)
        layout = (SOURCE / "backend_native_scalar.p").read_text(
            encoding="utf-8"
        )
        function = layout.split("unsafe NativeLayout native_layout(", 1)[1].split(
            "unsafe usize native_field_offset(", 1
        )[0]
        self.assertLess(
            function.index("type_id >= context.native_layout_cache_entries"),
            function.index("read_usize(context.native_layout_state_cache"),
        )

    def test_type_freeze_checks_each_function_before_next_bind(self) -> None:
        source = (SOURCE / "backend_c_project_source.p").read_text(
            encoding="utf-8"
        )
        self.assertIn("usize types_before = function_context.types.length;", source)
        self.assertIn("function_context.types.length != types_before", source)
        self.assertIn("OPENC-FUNCTION-TYPE-FREEZE-MISS", source)
        wrapper = source.split(
            "unsafe bool c_emit_prepared_source_functions(", 1
        )[1].split("unsafe bool c_emit_source_record(", 1)[0]
        self.assertLess(
            wrapper.index("ir_prematerialize_ref_call_pointer_types(source_context)"),
            wrapper.index("c_emit_prepared_source_functions_inner("),
        )
        self.assertLess(
            source.index("function_context.types.length != types_before"),
            source.index("ir_capture_function_scratch(scratch, function_context)"),
        )

    def test_type_closure_scans_indexed_calls_only(self) -> None:
        prepass = (SOURCE / "ir_function_type_freeze.p").read_text(
            encoding="utf-8"
        )
        self.assertIn("while call_index < context.call_count", prepass)
        self.assertIn("ir_select_call(context, call)", prepass)
        self.assertIn("ir_ref_argument_needs_address_type", prepass)
        self.assertNotIn("ir_lower_function(", prepass)
        self.assertNotIn("memory.alloc", prepass)

    def test_type_registry_record_writes_append_only(self) -> None:
        writers = []
        pattern = re.compile(
            r"write_(?:record_field|usize)\s*\(\s*"
            r"(?:context\.)?type_data\b"
        )
        for path in SOURCE.glob("*.p"):
            if pattern.search(path.read_text(encoding="utf-8")):
                writers.append(path.name)
        self.assertEqual(writers, ["semantic.p"])
        semantic = (SOURCE / "semantic.p").read_text(encoding="utf-8")
        add_type = semantic.split("unsafe usize semantic_add_type(", 1)[1].split(
            "}\n", 1
        )[0]
        self.assertIn("usize record = types.length;", add_type)
        self.assertIn("types.length = types.length + 1;", add_type)


if __name__ == "__main__":
    unittest.main()
