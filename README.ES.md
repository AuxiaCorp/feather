# Feather Language — Bootstrap independiente con autoalojamiento (v8, experimental)

Esta carpeta es un árbol de código fuente sin Rust ni dependencias externas para un nuevo bootstrap del compilador Feather. No sustituye todas las funciones de V7. El archivo V7 funcional debe conservarse por separado hasta alcanzar la paridad.

## Funcionalidad verificada y ejecutable

La implementación del compilador está en `src/compiler.feather` (subconjunto bootstrap de Feather, unas 2.300 líneas). Reconoce tokens y líneas, decodifica operandos numéricos, resuelve estructuralmente saltos hacia delante y hacia atrás, y emite directamente instrucciones máquina x86-64 y cabeceras Linux ELF64.

Una semilla nativa x86-64 (`bootstrap/feather-seed`) compila este código Feather en un segundo compilador nativo. Este compila el mismo código para generar un tercero. Las generaciones son idénticas byte por byte y tienen los mismos hashes SHA-256.

### `.feather -> .fthr`

En este bootstrap, `.fthr` es un ejecutable Linux ELF64 con extensión `.fthr`, no el contenedor V7 anterior `FTHRNAT2`. El programa se ejecuta directamente en Linux porque ELF es un contenedor nativo del sistema operativo.

No se necesita intérprete, Rust, Cargo, Python, Clang, GCC, LLVM, glibc ni JVM para construir o ejecutar estos programas. La compatibilidad con Windows, ARM64 y el formato V7 no está implementada.

La primera línea debe ser obligatoriamente `#terminal-only`, `#executable` o `#script`. La última debe ser `quit.script` seguida de un salto de línea. Los tres modos generan actualmente el mismo modelo de entrada Linux ELF orientado a consola; no está implementada la semántica de permisos de GUI/ventanas.

### ELF y seguridad

El ELF está enlazado estáticamente, sin cargador dinámico, con segmentos separados de lectura/ejecución y lectura/escritura, y una pila no ejecutable. El ELF actual es `ET_EXEC`, no compatible con PIE/ASLR. No se proporciona una sandbox para el código del usuario.

La aritmética de registros utiliza enteros de 64 bits con desbordamiento circular (wrapping). No existe un sistema de tipos completo ni comprobación automática de límites.

## Compilación sin una cadena de herramientas de compilación

En Linux x86-64, desde esta carpeta:

```sh
./scripts/build.sh
./scripts/test.sh
./bin/feather examples/hello.feather examples/hello.fthr
./examples/hello.fthr
```

O bien:

```sh
make build
```

Solo se necesitan la semilla de código máquina x86-64 ya compilada, el código fuente Feather y las llamadas al sistema estándar de Linux. Los scripts shell opcionales usan bash y utilidades básicas del sistema. No hay dependencias de herramientas de compilación de lenguajes en tiempo de ejecución. No es un bootstrap multiplataforma.

### Instalación

Para instalar en `~/.local/bin`:

```sh
./scripts/install-linux.sh
```

Establece `PREFIX=/custom/path` para otro destino.

La CLI nativa acepta actualmente dos argumentos posicionales:

```sh
feather SOURCE.feather OUTPUT.fthr
```

Los comandos V7 completos, como `feather build --maximum`, `feather inspect` y `feather lib`, aún no se han migrado. No se admite ejecutar `./bin/feather` con argumentos no compatibles.

## Sintaxis bootstrap implementada

La gramática es deliberadamente limitada:

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

Las variables se limitan a 100 posiciones de registros de 64 bits llamadas `r00..r99`. `set` acepta exactamente 16 dígitos hexadecimales en minúscula. Aún no se admiten identificadores arbitrarios como `set enabled=true` de V7.

Operaciones: `copy r01=r02`, `inc r01`, `dec r01`, `add r01=r02`, `sub r01=r02`, `mul r01=r02`.

Condiciones: `when r01==r02 [`, `when r01!=r02 [`, `when r01<r02 [`, `when r01>=r02 [`.

Bucles: `while r01<r02 [`, `while r01!=r02 [`, `while r01==r02 [`; los bloques se cierran con `]` en una línea independiente.

### Salida, archivos y búferes binarios

- `say"ASCII/UTF-8 text"` muestra texto sin interpretar secuencias de escape ni admitir comillas incrustadas.
- `load source` lee una entrada argv en un búfer de origen fijo y establece `r00` con su longitud en bytes.
- `store output rXX` escribe la salida binaria en la siguiente ruta argv.
- `get r01=source[r02]` lee un byte.
- `get32 r01=output[r02]` lee un valor de 32 bits.
- `put output[r01]=r02` escribe un byte.
- `put32 output[r01]=r02` escribe un valor de 32 bits.
- `put64 output[r01]=r02` escribe un valor de 64 bits.
- `append r01="48454c4c4f"` añade bytes especificados en hexadecimal en minúsculas.
- `fail` termina con el estado de salida 2.

Una instrucción por línea. Los saltos de línea deben ser LF y la última línea debe terminar en LF. Se reconocen los comentarios `""` al inicio de línea y las construcciones `Working=...`. La sintaxis general de V7 aún no se ha migrado.

Esta gramática es un subconjunto de migración, no una afirmación de compatibilidad completa con Feather.

## Arquitectura del compilador

El compilador está escrito en Feather y se compila a sí mismo, pero actualmente realiza una traducción directa en una sola pasada (direct one-pass lowering). Todavía están pendientes una AST general, un analizador semántico, un optimizador, tipos genéricos e IR.

## Verificación

`./scripts/test.sh` comprueba tres generaciones de autocompilación idénticas byte por byte, ejecución nativa ELF, aritmética y bucles en tiempo de ejecución, operaciones con búferes binarios de 32/64 bits, copia nativa de archivos incluidos NUL y `0xff`, errores de E/S, rechazo de código mal formado y metadatos de pila no ejecutable. No utiliza Rust ni compiladores de otros lenguajes.

### Semilla y raíz de confianza

La semilla es un programa de código máquina precompilado que actúa como raíz de confianza. Se preparó inicialmente fuera de este árbol de código fuente. Tras la primera compilación, el compilador puede reproducirse desde `src/compiler.feather` usando un ejecutable Feather autocreado previamente.

La igualdad de hashes demuestra una regeneración determinista en la arquitectura probada. No demuestra ausencia de comportamiento malicioso, seguridad de memoria ni endurecimiento para producción.

## Pasos críticos de migración pendientes

Conserva el antiguo archivo V7 para mantener la funcionalidad histórica. La rama nativa self-host aún no admite variables con nombre/Bool/expresiones de texto, lexer/AST/sistema de tipos/IR completos, anchuras numéricas tipadas, diagnósticos con posiciones del código fuente, comprobación de desbordamiento con signo, garantías de memoria segura sin GC, comprobación automática de límites, async, gestor de paquetes/98 bibliotecas, `Number.by`, TLS/redes, GUI/Blender/3D, FFI, formato `FTHRNAT2`, firmas, ARM64, Windows ni fuzzing/revisión de seguridad.

**No despliegues esta versión como compilador de confianza para código fuente no confiable.** Es una base nativa self-host validada, no una distribución del lenguaje lista para producción.
