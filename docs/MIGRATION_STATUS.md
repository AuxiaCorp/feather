# V7 -> self-hosted Feather migration status

The original v0.5.0-dev V7 archive is **not deleted or modified**. It remains the reference for unported features. No new Rust code or Cargo dependencies are present in this independent self-hosted branch.

| Subsystem | Verified in v8 | Still outstanding |
|---|---|---|
| Bootstrap | x86-64 seed and 3 byte-identical generations of compiler `.feather` self-assembly | independent signed seed audit, multi-arch bootstrap |
| Lexer/parser | line/token recognition of fixed bootstrap grammar; nested `when`/`while` brackets | full V7 lexical grammar, rich AST, error recovery |
| Semantic analysis/types | register names `r00..r99` and checked literal encoding | type checker, inferencing, Booleans, float, strings/arrays |
| Native backend | x86-64 ELF64 machine instructions, integer ops, branching, Linux syscalls | PIC/PIE, ARM64, Windows PE, FTHRNAT2, optimizers |
| Linker/binary | in-Feather ELF header + program header writing; code relocation for branches | reusable linker, imports, runtime relocations, code signing |
| CLI | `feather input.feather output.fthr` | rich subcommands from V7 |
| Runtime | static no-libc Linux syscalls, fixed registers/data sections | owned memory, dynamic allocation, async, threads, safety |
| Libraries | direct file/console primitive operations | registry, packages, 98 standard libraries, Number Engine, networking |
| GUI/3D/FFI | not implemented | native windows, Blender, graphics APIs, Java/C/C++/.NET |

The ELF-only `.fthr` output is a temporary standalone native-container profile. It must not silently replace V7 FTHRNAT2 files: existing builds and existing V7 sources remain in the separate original archive.
