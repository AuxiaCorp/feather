# Feather Language — Unabhängiger Self-Hosting-Bootstrap (v8, experimentell)

Dieser Ordner enthält einen Rust- und abhängigkeitenfreien Quellcodebaum für einen neuen Feather-Compiler-Bootstrap. Er ersetzt nicht sämtliche Funktionen von V7. Das funktionsfähige V7-Archiv muss separat aufbewahrt werden, bis Funktionsgleichheit erreicht ist.

## Verifizierte, ausführbare Funktionen

Die Compilerimplementierung befindet sich in `src/compiler.feather` (Feather-Bootstrap-Teilmenge, etwa 2.300 Zeilen). Sie erkennt Token und Zeilen, dekodiert numerische Operanden, löst strukturierte Vorwärts- und Rückwärtssprünge auf und erzeugt direkt x86-64-Maschineninstruktionen sowie Linux-ELF64-Header.

Ein nativer x86-64-Seed (`bootstrap/feather-seed`) kompiliert diesen Feather-Quellcode zu einem zweiten nativen Compiler. Dieser kompiliert denselben Quellcode zu einem dritten Compiler. Die Generationen sind bytegenau identisch und besitzen identische SHA-256-Hashes.

### `.feather -> .fthr`

In diesem Bootstrap ist `.fthr` eine ausführbare Linux-ELF64-Datei mit der Endung `.fthr`, nicht der frühere V7-Container `FTHRNAT2`. Das Programm läuft direkt unter Linux, da ELF ein natives Betriebssystemformat ist.

Zum Erstellen und Ausführen werden weder Interpreter noch Rust, Cargo, Python, Clang, GCC, LLVM, glibc oder JVM benötigt. Windows, ARM64 und die Kompatibilität mit dem V7-Format sind nicht implementiert.

Die erste Zeile muss `#terminal-only`, `#executable` oder `#script` enthalten. Die letzte Zeile muss `quit.script` sein und von einem Zeilenumbruch gefolgt werden. Alle drei Modi erzeugen derzeit dasselbe konsolenorientierte Linux-ELF-Einstiegsmodell; GUI-/Fensterberechtigungen sind nicht implementiert.

### ELF und Sicherheit

Das ELF ist statisch gelinkt, besitzt keinen dynamischen Loader, verwendet getrennte Lese-/Ausführungs- und Lese-/Schreibsegmente und hat einen nicht ausführbaren Stack. Das aktuelle Bootstrap-ELF ist `ET_EXEC`, nicht PIE-/ASLR-fähig. Eine Sandbox für Benutzercode wird nicht bereitgestellt.

Registerarithmetik verwendet 64-Bit-Ganzzahlen mit Wraparound-Semantik. Ein vollständiges Typsystem und automatische Bereichsprüfungen fehlen.

## Erstellung ohne Compiler-Toolchain

Unter Linux x86-64 in diesem Ordner:

```sh
./scripts/build.sh
./scripts/test.sh
./bin/feather examples/hello.feather examples/hello.fthr
./examples/hello.fthr
```

Oder:

```sh
make build
```

Benötigt werden nur der bereits erstellte x86-64-Maschinencode-Seed, der Feather-Quellcode und standardmäßige Linux-Systemaufrufe. Optionale Shell-Build- und Testskripte verwenden bash und grundlegende Systemwerkzeuge. Zur Laufzeit bestehen keine Abhängigkeiten von Sprach-Toolchains. Dies ist kein plattformübergreifender Bootstrap.

### Installation

Zur Installation nach `~/.local/bin`:

```sh
./scripts/install-linux.sh
```

Für ein anderes Ziel setzen Sie `PREFIX=/custom/path`.

Die native CLI akzeptiert derzeit zwei Positionsargumente:

```sh
feather SOURCE.feather OUTPUT.fthr
```

Vollständige V7-Befehle wie `feather build --maximum`, `feather inspect` und `feather lib` wurden noch nicht portiert. Aufrufe von `./bin/feather` mit nicht unterstützten Argumenten werden nicht unterstützt.

## Implementierte Bootstrap-Syntax

Die Grammatik ist bewusst eng begrenzt:

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

Variablen sind auf 100 64-Bit-Registerplätze namens `r00..r99` beschränkt. `set` akzeptiert genau 16 kleingeschriebene Hexadezimalziffern. Beliebige Bezeichner wie `set enabled=true` aus V7 werden noch nicht unterstützt.

Operationen: `copy r01=r02`, `inc r01`, `dec r01`, `add r01=r02`, `sub r01=r02`, `mul r01=r02`.

Bedingungen: `when r01==r02 [`, `when r01!=r02 [`, `when r01<r02 [`, `when r01>=r02 [`.

Schleifen: `while r01<r02 [`, `while r01!=r02 [`, `while r01==r02 [`; Blöcke werden mit `]` in einer eigenen Zeile geschlossen.

### Ausgabe, Dateien und Binärpuffer

- `say"ASCII/UTF-8 text"` gibt Text ohne Interpretation von Escape-Sequenzen und ohne eingebettete Anführungszeichen aus.
- `load source` liest eine argv-Eingabe in einen festen Quellpuffer und setzt `r00` auf deren Länge in Bytes.
- `store output rXX` schreibt Binärdaten in den nächsten argv-Pfad.
- `get r01=source[r02]` liest ein Byte.
- `get32 r01=output[r02]` liest einen 32-Bit-Wert.
- `put output[r01]=r02` schreibt ein Byte.
- `put32 output[r01]=r02` schreibt einen 32-Bit-Wert.
- `put64 output[r01]=r02` schreibt einen 64-Bit-Wert.
- `append r01="48454c4c4f"` hängt Bytes an, die als kleingeschriebene Hexadezimalzeichenfolge angegeben sind.
- `fail` beendet das Programm mit Status 2.

Eine Anweisung pro Zeile. Zeilenumbrüche müssen LF sein; die letzte Zeile muss mit LF enden. Kommentare `""` am Zeilenanfang und `Working=...` werden erkannt. Die allgemeine V7-Syntax wurde noch nicht migriert.

Dies ist eine Migrations-Teilmenge der Grammatik und kein Anspruch auf vollständige Feather-Kompatibilität.

## Compilerarchitektur

Der Compiler ist in Feather geschrieben und kompiliert sich selbst, führt derzeit jedoch ein direktes einstufiges Lowering (direct one-pass lowering) aus. Eine allgemeine AST, ein semantischer Analysator, ein Optimierer, generische Typen und IR stehen noch aus.

## Verifizierung

`./scripts/test.sh` prüft drei bytegenau übereinstimmende Self-Build-Generationen, native ELF-Ausführung, Laufzeitarithmetik und Schleifen, 32/64-Bit-Binärpufferoperationen, natives Kopieren von Dateien einschließlich NUL- und `0xff`-Bytes, Datei-E/A-Fehler, Zurückweisung fehlerhaften Quellcodes und Metadaten für einen nicht ausführbaren Stack. Die Tests verwenden weder Rust noch Compiler anderer Sprachen.

### Seed und Vertrauensanker

Der Seed ist ein vorkompiliertes Maschinenprogramm und dient als Vertrauensanker. Er wurde ursprünglich außerhalb dieses Quellcodebaums erstellt. Nach dem ersten Build lässt sich der Compiler mit einer zuvor selbst erstellten Feather-Datei reproduzierbar allein aus `src/compiler.feather` erzeugen.

Die Hash-Gleichheit der Generationen zeigt die deterministische Neuerzeugung auf der getesteten Architektur. Sie beweist weder das Fehlen bösartigen Verhaltens noch Speichersicherheit oder Produktionshärtung.

## Verbleibende kritische Migrationsschritte

Bewahren Sie das alte V7-Archiv für historische Funktionen auf. Der native Self-Hosting-Zweig unterstützt noch keine benannten Variablen/Bool/Textausdrücke, keinen vollständigen Lexer/AST/Typen/IR, keine typisierten numerischen Breiten, keine Compilerdiagnosen mit Quellpositionen, keine Prüfung auf vorzeichenbehafteten Überlauf, keine GC-freien Speichersicherheitsgarantien, keine automatische Bereichsprüfung, kein Async, keinen Paketmanager/98 Bibliotheken, kein `Number.by`, TLS/Netzwerk, GUI/Blender/3D, FFI, das `FTHRNAT2`-Format, Signaturen, ARM64, Windows oder Fuzzing/Sicherheitsaudit.

**Setzen Sie diese Version nicht als vertrauenswürdigen Compiler für nicht vertrauenswürdigen Quellcode ein.** Sie ist eine validierte Grundlage für natives Self-Hosting, keine produktionsreife Sprachdistribution.
