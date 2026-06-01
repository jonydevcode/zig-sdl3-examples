# Some SDL3 Examples in Zig

![No LLM Generation](https://img.shields.io/badge/LLM%20generation-none-brightgreen)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

I'm learning Zig. I have ported some of the SDL3 examples to
Zig to learn how C bindings work. They are all done by hand. No
LLM-generation was used in the code for this repo.

![Snake](screenshots/03-snake.png)

## AI Use Disclosure

The current contents of this repository were written without LLM/AI code generation. All AI usage in any form by contributors must be disclosed.

## Getting Started

### Dependencies

- Zig 0.16
- [castholm/SDL](https://github.com/castholm/SDL)

### Executing

```bash
zig build run-clear
zig build run-primitives
zig build run-snake
zig build run-gpu
```

## Acknowledgments

- [zig](https://codeberg.org/ziglang/zig)
- [castholm/SDL](https://github.com/castholm/SDL)

## License

Distributed under the MIT License. See [LICENSE](./LICENSE) for more information.

## Screenshots

![Clear](screenshots/01-clear.png)
![Primitives](screenshots/02-primitives.png)
![GPU](screenshots/04-gpu.png)
