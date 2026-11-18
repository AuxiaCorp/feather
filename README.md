# Feather Language — Independent Self-Hosting Bootstrap (v8, experimental)

This folder is a **Rust-free, dependency-free source tree for a new Feather compiler bootstrap**, not a replacement for all V7 language features. The working V7 archive must be retained separately until parity is established.

## Verified, runnable functionality

- The compiler implementation is `src/compiler.feather` (Feather bootstrap subset, ~2,300 lines). It performs token/line recognition, numeric operand decoding, structured forward/backward branch resolution, and directly emits x86-64 machine instructions and Linux ELF64 headers.
- An x86-64 native seed (`bootstrap/feather-seed`) compiles this Feather source into a second native compiler. The resulting compiler compiles the same source into a third. Repeated generations are **byte-for-byte identical** and have identical SHA-256 digests.
- `.feather -> .fthr`: `.fthr` in this bootstrap is a **Linux ELF64 executable with the `.fthr` suffix**, not the earlier V7 `FTHRNAT2` envelope. The program runs directly on Linux because ELF is a native OS container; no interpreter, Rust, Cargo, Python, Clang, GCC, LLVM, glibc, or JVM is required to build or execute these programs. Windows, ARM64, and V7 format compatibility are not implemented here.
- Mandatory first line `#terminal-only`, `#executable`, or `#script`, and mandatory final `quit.script` (with trailing newline) are checked. All three modes currently generate the same console-oriented Linux ELF entry model; no GUI/window permission semantics are implemented.
- Supports fixed-register integer operations and assignments, `when` and `while` comparisons, native syscalls for file I/O and console output, binary-buffer access and writing, literal byte emission, and program termination.
- ELF is statically linked, without a dynamic loader, with separate read/execute and read/write segments and non-executable stack. Current bootstrap ELF is `ET_EXEC`, **not PIE/ASLR-capable**; no user-code sandbox is provided. Register arithmetic uses wrapping 64-bit integers, and there is no full type system or automatic bounds-checking.

## Build entirely without a compiler toolchain

On **Linux x86-64**, from this folder:

```sh
./scripts/build.sh
./scripts/test.sh
./bin/feather examples/hello.feather examples/hello.fthr
./examples/hello.fthr
```

Or:

```sh
make build
```

Only the **already-built x86-64 machine-code seed**, the Feather source, and standard Linux syscalls are needed for compiler execution. The optional shell test/build scripts use bash and basic system utilities; there are no runtime language toolchain dependencies. This is not a cross-platform bootstrap.

To install to `~/.local/bin`:

```sh
./scripts/install-linux.sh
```

Set `PREFIX=/custom/path` for another destination. The native CLI presently accepts two positional arguments: `feather SOURCE.feather OUTPUT.fthr`. Full V7 commands such as `feather build --maximum`, `feather inspect`, and `feather lib` are not yet ported. Calling `./bin/feather` with unsupported arguments is not supported.

## Implemented bootstrap syntax (deliberately narrow)

```feather
#terminal-only
Working=demo
set r01=0000000000000000
set r02=0000000000000003
while r01<r02 [
say"Hello"
inc r01
]
quit.script
```

- Variables are limited to 100 64-bit register slots named `r00..r99`; `set` accepts **exactly 16 lowercase hexadecimal digits**. It does not yet accept arbitrary source identifiers like `set enabled=true` from V7.
- `copy r01=r02`, `inc r01`, `dec r01`, `add r01=r02`, `sub r01=r02`, `mul r01=r02`.
- `when r01==r02 [`, `when r01!=r02 [`, `when r01<r02 [`, `when r01>=r02 [`, and `while r01<r02 [`, `while r01!=r02 [`, `while r01==r02 [`, closed with `]` on its own line.
- `say"ASCII/UTF-8 text"` without escape interpretation or embedded quote; `load source` reads an argv input into a fixed source buffer and sets `r00` to its byte length; `store output rXX` writes binary output to the next argv path.
- `get r01=source[r02]`, `get32 r01=output[r02]`, `put output[r01]=r02`, `put32 output[r01]=r02`, `put64 output[r01]=r02`, `append r01="48454c4c4f"` (lowercase hexadecimal bytes), and `fail` (exit status 2).
- One statement per line; newlines must be LF, and the last line must end with LF. `""` line-start comments and `Working=...` are recognized, but general V7 syntax is not yet migrated.

This bootstrap grammar is a **migration subset**, not a claim of complete Feather syntax compatibility. Its compiler is written in Feather and self-hosts, but currently does direct one-pass lowering; a general AST, semantic analyzer, optimizer, generic types, and IR are still outstanding.

## Verification

`./scripts/test.sh` checks three generations of exact self-build parity, native ELF execution, runtime arithmetic and loops, 32/64-bit binary-buffer operations, native file copy of bytes (including NUL/0xff), file I/O errors, rejected malformed source, and non-executable stack metadata. It uses no Rust or other language compiler.

The seed is a **precompiled machine-code trust root**. It was initially prepared outside this source tree; after the first build, the compiler is reproducible entirely from `src/compiler.feather` using a previous self-built Feather executable. Hash equality across generations demonstrates deterministic regeneration of the seed on the tested architecture. It does **not** prove absence of malicious behavior, memory safety, or production hardening.

## Remaining critical migration steps

Preserve the old V7 archive for historical functionality. The native selfhost branch does **not** yet support named variables/Bool/text expressions, full lexer/AST/types/IR, typed numeric widths, compiler diagnostics with source positions, signed overflow checking, memory ownership/GC-free safety guarantees, automatic bounds checking, async, package manager/98 libraries, `Number.by`, TLS/networking, GUI/Blender/3D, FFI, `FTHRNAT2` format, signatures, ARM64, Windows, or fuzz/security review. Do not deploy it as a trusted compiler for untrusted source. It is a validated native self-hosting foundation, **not a production-ready language distribution**.
