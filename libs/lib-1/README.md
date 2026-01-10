# zour-dough
This is a project about a lib for sour dough in Zig.

## Quick start

Build the shared library:

```bash
zig build-lib src/lib.zig -dynamic -O ReleaseSmall -target native --name zour_dough
```

Compile the example:

```bash
clang examples/c/main.c -I include -L. -lzour_dough -o examples/c/main
```

Run the example (macOS):

```bash
DYLD_LIBRARY_PATH=. ./examples/c/main
```
