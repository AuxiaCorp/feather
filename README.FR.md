# Feather Language — Bootstrap indépendant avec auto-hébergement (v8, expérimental)

Ce dossier est une arborescence de sources sans Rust ni dépendances externes pour un nouveau bootstrap du compilateur Feather. Il ne remplace pas toutes les fonctionnalités de V7. L’archive V7 fonctionnelle doit être conservée séparément jusqu’à l’obtention de la parité.

## Fonctionnalités vérifiées et exécutables

L’implémentation du compilateur se trouve dans `src/compiler.feather` (sous-ensemble bootstrap de Feather, environ 2 300 lignes). Elle reconnaît les jetons et les lignes, décode les opérandes numériques, résout structurellement les branchements avant et arrière, et émet directement des instructions machine x86-64 ainsi que des en-têtes Linux ELF64.

Un seed natif x86-64 (`bootstrap/feather-seed`) compile ce code source Feather en un deuxième compilateur natif. Celui-ci compile le même code pour produire un troisième compilateur. Les générations sont identiques octet par octet et possèdent des condensats SHA-256 identiques.

### `.feather -> .fthr`

Dans ce bootstrap, `.fthr` est un exécutable Linux ELF64 portant l’extension `.fthr`, et non l’ancien conteneur V7 `FTHRNAT2`. Le programme s’exécute directement sous Linux, car ELF est un conteneur natif du système d’exploitation.

Aucun interpréteur, Rust, Cargo, Python, Clang, GCC, LLVM, glibc ou JVM n’est nécessaire pour construire ou exécuter ces programmes. La prise en charge de Windows, d’ARM64 et la compatibilité avec le format V7 ne sont pas implémentées.

La première ligne doit obligatoirement être `#terminal-only`, `#executable` ou `#script`. La dernière ligne doit être `quit.script`, suivie d’un saut de ligne. Les trois modes génèrent actuellement le même modèle d’entrée Linux ELF orienté console ; la sémantique des autorisations GUI/fenêtres n’est pas implémentée.

### ELF et sécurité

L’ELF est lié statiquement, sans chargeur dynamique, avec des segments distincts lecture/exécution et lecture/écriture, et une pile non exécutable. L’ELF actuel est de type `ET_EXEC`, non compatible PIE/ASLR. Aucun bac à sable pour le code utilisateur n’est fourni.

L’arithmétique des registres utilise des entiers 64 bits avec retour cyclique en cas de dépassement (wrapping). Il n’existe ni système de types complet ni vérification automatique des limites.

## Construction sans chaîne d’outils de compilation

Sous Linux x86-64, depuis ce dossier :

```sh
./scripts/build.sh
./scripts/test.sh
./bin/feather examples/hello.feather examples/hello.fthr
./examples/hello.fthr
```

Ou :

```sh
make build
```

Seuls le seed en code machine x86-64 déjà compilé, le code source Feather et les appels système Linux standard sont nécessaires. Les scripts shell facultatifs de construction et de test utilisent bash et des utilitaires système de base. Il n’existe aucune dépendance d’exécution envers une chaîne d’outils de langage. Ce n’est pas un bootstrap multiplateforme.

### Installation

Pour installer dans `~/.local/bin` :

```sh
./scripts/install-linux.sh
```

Définissez `PREFIX=/custom/path` pour une autre destination.

La CLI native accepte actuellement deux arguments positionnels :

```sh
feather SOURCE.feather OUTPUT.fthr
```

Les commandes V7 complètes telles que `feather build --maximum`, `feather inspect` et `feather lib` n’ont pas encore été portées. Les arguments non pris en charge ne sont pas acceptés par `./bin/feather`.

## Syntaxe du bootstrap implémentée

La grammaire est volontairement limitée :

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

Les variables sont limitées à 100 emplacements de registres 64 bits nommés `r00..r99`. `set` accepte exactement 16 chiffres hexadécimaux minuscules. Les identifiants arbitraires comme `set enabled=true` de V7 ne sont pas pris en charge.

Opérations : `copy r01=r02`, `inc r01`, `dec r01`, `add r01=r02`, `sub r01=r02`, `mul r01=r02`.

Conditions : `when r01==r02 [`, `when r01!=r02 [`, `when r01<r02 [`, `when r01>=r02 [`.

Boucles : `while r01<r02 [`, `while r01!=r02 [`, `while r01==r02 [` ; les blocs se ferment avec `]` sur sa propre ligne.

### Sortie, fichiers et tampons binaires

- `say"ASCII/UTF-8 text"` affiche le texte sans interpréter les séquences d’échappement ni accepter de guillemets intégrés.
- `load source` lit une entrée argv dans un tampon source fixe et place sa longueur en octets dans `r00`.
- `store output rXX` écrit la sortie binaire vers le chemin argv suivant.
- `get r01=source[r02]` lit un octet.
- `get32 r01=output[r02]` lit une valeur de 32 bits.
- `put output[r01]=r02` écrit un octet.
- `put32 output[r01]=r02` écrit une valeur de 32 bits.
- `put64 output[r01]=r02` écrit une valeur de 64 bits.
- `append r01="48454c4c4f"` ajoute des octets indiqués en hexadécimal minuscule.
- `fail` termine avec le code de sortie 2.

Une instruction par ligne. Les fins de ligne doivent être LF et la dernière ligne doit se terminer par LF. Les commentaires `""` en début de ligne et les constructions `Working=...` sont reconnus. La syntaxe générale de V7 n’a pas été migrée.

Cette grammaire est un sous-ensemble de migration, sans prétention de compatibilité complète avec Feather.

## Architecture du compilateur

Le compilateur est écrit en Feather et s’auto-héberge, mais effectue actuellement un abaissement direct en un seul passage (direct one-pass lowering). Une AST générale, un analyseur sémantique, un optimiseur, les types génériques et l’IR restent à réaliser.

## Vérification

`./scripts/test.sh` vérifie trois générations d’auto-compilation identiques octet par octet, l’exécution native ELF, l’arithmétique et les boucles à l’exécution, les opérations sur tampons binaires 32/64 bits, la copie native de fichiers y compris les octets NUL et `0xff`, les erreurs d’E/S, le rejet du code mal formé et les métadonnées de pile non exécutable. Les tests n’utilisent ni Rust ni un autre compilateur de langage.

### Seed et racine de confiance

Le seed est un programme en code machine précompilé servant de racine de confiance. Il a initialement été préparé en dehors de cette arborescence. Après la première compilation, le compilateur peut être reproduit à partir de `src/compiler.feather` avec un exécutable Feather précédemment auto-compilé.

L’égalité des hachages démontre une régénération déterministe sur l’architecture testée. Elle ne prouve ni l’absence de comportement malveillant, ni la sûreté mémoire, ni le durcissement nécessaire à la production.

## Étapes critiques de migration restantes

Conservez l’ancienne archive V7 pour ses fonctionnalités historiques. La branche native ne prend pas encore en charge les variables nommées/Bool/expressions textuelles, un lexer/AST/système de types/IR complet, les largeurs numériques typées, les diagnostics avec positions source, la vérification des dépassements signés, les garanties de gestion mémoire sans GC, la vérification automatique des limites, l’asynchronisme, un gestionnaire de paquets/98 bibliothèques, `Number.by`, TLS/réseau, GUI/Blender/3D, FFI, le format `FTHRNAT2`, les signatures, ARM64, Windows ou l’audit fuzz/sécurité.

**Ne déployez pas cette version comme compilateur de confiance pour du code source non fiable.** Il s’agit d’une base native d’auto-hébergement validée, et non d’une distribution prête pour la production.
