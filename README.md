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

<table>
  <tr>
    <td width="50%">
      <strong>Adorable tiger (vector tracing)</strong><br>
      <img src="docs/images/tiger.png" alt="Vector tiger head with dynamic strokes" title="Vector tiger head rendered with blendend" />
    </td>
    <td width="50%">
      <strong>Flower waves (blur effect)</strong><br>
      <img src="docs/images/floral_waves.png" alt="Layered flower waves with blur" title="Flower waves rendered with blendend" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <strong>Cartesian plot</strong><br>
      <img src="docs/images/sine_wave.png" alt="Sine and cosine waves on cartesian axes" title="Cartesian plot generated with Blendend.Cartesian" />
    </td>
    <td width="50%">
      <strong>Blendend logo (path flattening)</strong><br>
      <img src="docs/images/blendend_logo.png" alt="Rainbow Blendend logo with noisy stroke outlines" title="Path flattening on the letters of blendend" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <strong> Color Burn gradients</strong><br>
      <img src="docs/images/p5_burn_grid.png" alt="Grid of gradients with burn blend" title="p5.js burn grid port rendered with blendend" />
    </td>
    <td width="50%">
    </td>
  </tr>
</table>

Attribution: The burn grid demo and flower waves (which are available in `blendend_playground`)is adapted from takawo's original p5.js sketch (https://openprocessing.org/user/6533) and shared under the Creative Commons BY-NC-SA 3.0 license (https://creativecommons.org/licenses/by-nc-sa/3.0/).


## Licenses 

- This project is released under the MIT License (see `LICENSE`).
- `blend2d` is licensed under the zlib license.
- `priv/fonts/Alegreya-Regular.otf` is distributed under the SIL Open Font License.
