# w4-shadows :zap:

Using [Zig](https://ziglang.org/) to compile a `.wasm` cart
for use in [WASM-4](https://wasm4.org/)

## Development

File watcher can be started by calling:
```sh
zig build spy
```

Running the cart in WASM-4:
```sh
zig build run
```

Deploy:
```
make Deploy
```
