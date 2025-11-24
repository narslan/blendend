# blendend

<p align="center">
  <img src="docs/images/piriform.png" alt="Blendend logo" width="320">
</p>

Elixir bindings to [Blend2D](https://blend2d.com/) – a fast 2D renderer – for drawing shapes, text, and gradients into images.

- Blend2D's rendering engine from plain Elixir.
- Composable drawing pipeline: `Canvas`, `Path`, `Matrix2D`, `Text`, `Style` modules.
- A DSL (`Blendend.Draw`) for concise scripts. 
- Support for PNG/QOI export. 

## Status

**Early, experimental.** APIs change definetely; feedback and bug reports are welcome.

## Requirements

- The latest Blend2D built and installed on your system
- A C++ toolchain (a C++ compiler + cmake)

Quick build of Blend2D:
```sh
git clone https://github.com/blend2d/blend2d
cd blend2d
git clone https://github.com/asmjit/asmjit 3rdparty/asmjit
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

## Install in your project

```elixir
def deps do
  [
    {:blendend, github: "narslan/blendend"}
  ]
end
```

Then:
```sh
mix deps.get
mix compile
```

## Quick start

Using the DSL:
```elixir
use Blendend.Draw

draw 200, 200, "priv/basic_line.png" do
  line 0, 100, 200, 100, stroke: rgb(255, 255, 255)
end
```
For examples, please browse in:
[blendend_playground](https://github.com/narslan/blendend_playground).

## Playground

There is a separate web playground for live editing and rendering, and for browsing the bundled examples:
[blendend_playground](https://github.com/narslan/blendend_playground).

## Gallery

![Blendend logo](docs/images/blendend_logo.png)
![Flower field](docs/images/flower_field.png)
![Sine waves](docs/images/sine_wave.png)
![Tiger demo](docs/images/tiger.png)

## Licenses & Assets

- This project is released under the MIT License (see `LICENSE`).
- `blend2d` is licensed under the zlib license.
- `priv/fonts/Alegreya-Regular.otf` is distributed under the SIL Open Font License.
