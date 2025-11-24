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

**Early, experimental.** APIs change definitely; feedback and bug reports are welcome.

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

## Playground

There is a separate web playground for live editing and rendering, and for browsing the bundled examples:
[blendend_playground](https://github.com/narslan/blendend_playground).

## Gallery

### Fierce and adorable tiger (vector tracing)
![Vector tiger head with dynamic strokes](docs/images/tiger.png "Vector tiger head rendered with Blend2D")

### Cartesian plot 
![Sine and cosine waves on cartesian axes](docs/images/sine_wave.png "Cartesian plot generated with Blendend.Cartesian")

### Layered fills
![Overlapping colorful flowers on black background](docs/images/flower_field.png "Randomized flower field rendered with layered fills")

### Effects on glyph outlines
![Rainbow Blendend logo with noisy stroke outlines](docs/images/blendend_logo.png "Blendend logo drawn with jittered path flattening")

## Licenses 

- This project is released under the MIT License (see `LICENSE`).
- `blend2d` is licensed under the zlib license.
- `priv/fonts/Alegreya-Regular.otf` is distributed under the SIL Open Font License.
