# Feather Language — 独立自举编译器（v8，实验版）

此文件夹是一个不依赖 Rust 和外部依赖项的新 Feather 编译器自举源码树。它并不取代 V7 语言的全部功能。在实现功能对等之前，必须单独保留可用的 V7 归档版本。

## 已验证且可运行的功能

编译器实现位于 `src/compiler.feather`（Feather 自举子集，约 2,300 行）。它能够识别 token 和行、解码数值操作数、结构化解析向前和向后的分支，并直接生成 x86-64 机器指令和 Linux ELF64 文件头。

x86-64 原生种子编译器（`bootstrap/feather-seed`）将此 Feather 源码编译成第二个原生编译器。生成的编译器再将相同源码编译成第三个编译器。各代版本逐字节完全相同，并具有相同的 SHA-256 摘要。

### `.feather -> .fthr`

此自举版本中的 `.fthr` 是扩展名为 `.fthr` 的 Linux ELF64 可执行文件，而不是早期 V7 的 `FTHRNAT2` 封装格式。由于 ELF 是操作系统的原生容器，程序可直接在 Linux 上运行。

构建或运行这些程序不需要解释器、Rust、Cargo、Python、Clang、GCC、LLVM、glibc 或 JVM。尚未实现 Windows、ARM64 和 V7 格式兼容性。

第一行必须是 `#terminal-only`、`#executable` 或 `#script`。最后一行必须是 `quit.script`，并以换行符结束。目前三种模式都会生成相同的面向控制台的 Linux ELF 入口模型；尚未实现 GUI/窗口权限语义。

### ELF 与安全性

ELF 采用静态链接，没有动态加载器，具有独立的读/执行段和读/写段，并使用不可执行栈。当前自举 ELF 类型为 `ET_EXEC`，不支持 PIE/ASLR。未提供用户代码沙箱。

寄存器运算使用带回绕语义的 64 位整数。没有完整类型系统，也没有自动边界检查。

## 无需编译工具链即可构建

在 Linux x86-64 上，从此文件夹运行：

```sh
./scripts/build.sh
./scripts/test.sh
./bin/feather examples/hello.feather examples/hello.fthr
./examples/hello.fthr
```

或者：

```sh
make build
```

运行编译器只需要已构建的 x86-64 机器码种子、Feather 源码以及 Linux 标准系统调用。可选 shell 构建/测试脚本使用 bash 和基本系统工具。运行时不依赖语言编译工具链。这不是跨平台自举系统。

### 安装

安装到 `~/.local/bin`：

```sh
./scripts/install-linux.sh
```

如需其他目标路径，设置 `PREFIX=/custom/path`。

当前原生 CLI 接受两个位置参数：

```sh
feather SOURCE.feather OUTPUT.fthr
```

`feather build --maximum`、`feather inspect` 和 `feather lib` 等完整 V7 命令尚未移植。不支持使用未支持的参数调用 `./bin/feather`。

## 已实现的自举语法

语法范围经过刻意限制：

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

变量仅限于 100 个名为 `r00..r99` 的 64 位寄存器槽。`set` 必须接受恰好 16 个小写十六进制数字。尚不支持 V7 中 `set enabled=true` 这样的任意源代码标识符。

操作：`copy r01=r02`、`inc r01`、`dec r01`、`add r01=r02`、`sub r01=r02`、`mul r01=r02`。

条件：`when r01==r02 [`、`when r01!=r02 [`、`when r01<r02 [`、`when r01>=r02 [`。

循环：`while r01<r02 [`、`while r01!=r02 [`、`while r01==r02 [`；代码块必须在单独一行使用 `]` 关闭。

### 输出、文件和二进制缓冲区

- `say"ASCII/UTF-8 text"` — 输出文本，不解释转义序列，也不支持嵌入引号。
- `load source` — 将 argv 输入读入固定源码缓冲区，并将字节长度写入 `r00`。
- `store output rXX` — 将二进制输出写入下一个 argv 路径。
- `get r01=source[r02]` — 读取一个字节。
- `get32 r01=output[r02]` — 读取一个 32 位值。
- `put output[r01]=r02` — 写入一个字节。
- `put32 output[r01]=r02` — 写入一个 32 位值。
- `put64 output[r01]=r02` — 写入一个 64 位值。
- `append r01="48454c4c4f"` — 追加以小写十六进制表示的字节。
- `fail` — 以退出状态 2 结束程序。

每行只能有一条语句。换行符必须是 LF，最后一行也必须以 LF 结束。可识别行首的 `""` 注释和 `Working=...` 结构。通用 V7 语法尚未迁移。

此语法只是迁移用子集，并不表示与 Feather 语法完全兼容。

## 编译器架构

编译器使用 Feather 编写并能够自举，但目前采用直接单遍降低（direct one-pass lowering）。通用 AST、语义分析器、优化器、泛型类型和 IR 仍未实现。

## 验证

`./scripts/test.sh` 检查三代自举构建逐字节一致、原生 ELF 执行、运行时算术和循环、32/64 位二进制缓冲区操作、包括 NUL 和 `0xff` 字节的原生文件复制、文件 I/O 错误、拒绝格式错误的源码，以及不可执行栈元数据。测试不使用 Rust 或其他语言编译器。

### 种子与信任根

种子是充当信任根的预编译机器码程序，最初在此源码树之外准备。首次构建后，可以使用之前自举生成的 Feather 可执行文件，仅根据 `src/compiler.feather` 可重复地构建编译器。

各代之间哈希相同，证明该编译器能够在经过测试的架构上确定性地重新生成。但这不能证明不存在恶意行为、内存安全或已达到生产环境所需的安全加固水平。

## 尚待完成的关键迁移工作

为保留历史功能，请保留旧版 V7 归档。原生自举分支目前尚不支持命名变量/Bool/文本表达式、完整 lexer/AST/类型系统/IR、类型化数值宽度、带源码位置的编译器诊断、有符号整数溢出检查、无 GC 内存管理安全保证、自动边界检查、异步功能、包管理器/98 个库、`Number.by`、TLS/网络、GUI/Blender/3D、FFI、`FTHRNAT2` 格式、签名、ARM64、Windows 或模糊测试/安全审查。

**不要将此版本部署为处理不可信源码的可信编译器。** 它是经过验证的原生自举基础，而不是可用于生产环境的语言发行版。
