defmodule Blendend do
  @moduledoc """
  `blendend` is an Elixir wrapper around the [blend2d](https://blend2d.com) 2D
  graphics engine.

  blend2d is a high–performance vector renderer written in C/C++.
  `blendend` exposes it as a set of composable Elixir modules.

  At a high level:

    * we create a **canvas** backed by a 32-bit RGBA image
    * we draw **shapes**, **paths**, **text**, and **images** onto it
    * we control how they are rendered using **styles**, **strokes** and
      **transforms**
    * we export the result as PNG/QOI binaries

  `blendend` aims to mirror blend2d's core concepts, while providing an API that
  feels natural in Elixir.

  ## Core concepts

  ### Canvas

  The main drawing surface in `blendend` is a **canvas** (`Blendend.Canvas.t/0`).

  A canvas owns:

    * an internal pixel buffer (32-bit RGBA, with alpha)
    * a blend2d context that stores the **current graphics state**:
      stroke width, current style, transform matrix, composition mode, etc.

  Everything we draw goes through a canvas. Most `blendend` modules take a canvas
  as their first argument and either **fill** or **stroke** geometry onto it.

  There is no retained scene or display list.
  If we want a new frame, clear the canvas and draw everything again.

  We can snapshot a canvas as:

    * raw PNG / QOI data (`Blendend.Canvas.to_png/1`, `to_qoi/1`)
    * files via helpers like `Blendend.Canvas.save/2`

  ### Geometry and paths

  `blendend` exposes both simple shapes and complex paths:

    * simple primitives are available via:

        * `Blendend.Canvas.Fill` (rectangles, circles, ellipses, boxes, pies)
        * `Blendend.Canvas.Stroke` (lines, rectangles, circles etc. but stroked instead of filled)

    * complex shapes live in `Blendend.Path`:
        * commands such as `move_to/3`, `line_to/3`, `quad_to/5`, `cubic_to/7`,
          `arc_quadrant_to/5`, `add_circle/4`
        * utilities to inspect and deform paths:
          `vertex_count/1`, `vertex_at/2`, `set_vertex_at/5`, `hit_test/3,4`,
          `equal?/2`, `fit_to/2`, debug helpers

  A **path** is a sequence of lines and curves (quadratic and cubic Bézier
  segments). We can fill or stroke paths just like simple shapes.

  ### Styles, colors, gradients, patterns

  Whenever we fill or stroke a geometry, we apply a **style**, not just a flat
  color. `blendend` supports:

    * solid colors (`Blendend.Style.Color`)
    * gradients (`Blendend.Style.Gradient`)
    * patterns based on images (`Blendend.Style.Pattern`)

  Styles can carry alpha. Alpha means how strongly this layer should show up 
  when blended with the existing canvas. When we draw, pixels are blended with whatever is
  already in the canvas using a chosen **composition operator** (e.g.
  `:src_over`, `:multiply`, `:screen` ...).

  Stroke rendering can be tuned with:

    * caps (`:butt`, `:round`, `:square`, ...)
    * joins (`:miter`, `:round`, `:bevel`, ...)
    * stroke_width, stroke_color

  The low–level style parsing lives in the NIF layer; at the Elixir level we
  pass keyword lists like:

      Canvas.Fill.rect(canvas, 10, 10, 100, 40,
        color: Style.color(240, 240, 255),
        comp_op: :multiply
      )

  ### Coordinate systems and transforms

  By default, `blendend` uses pixel–aligned coordinates with origin at the
  top-left of the canvas: `(0.0, 0.0)` is the top-left corner.

  We can change the current transform using:

    * `Blendend.Canvas.translate/3`, `scale/3`, `rotate/2`, `skew/3`
    * or by building matrices with `Blendend.Matrix2D` and applying them via
      `Blendend.Canvas.apply_transform/2`.

  Transforms are part of the canvas graphics state. We can push/pop them using
  `save_state/1` and `restore_state/1`, or higher–level helpers like
  `Blendend.Draw.with_transform/2`.

  The `Blendend.Matrix2D` module wraps blend2d's `BLMatrix2D` and provides
  functional helpers such as `identity/0`, `translate/3`, `scale/3`, `rotate/2`
  and `compose/2`.

  ### Text and glyphs
  `blendend` provides helpers and lower–level glyph
  primitives useful for experimental typography and custom effects.

  To simply type text on the canvas `blendend` provides:
    * `Blendend.Canvas.Fill.utf8_text/6`
    * `Blendend.Canvas.Stroke.utf8_text/6`

  Lower level text support lives under `Blendend.Text`:

    * `Blendend.Text.Face` – load font faces from files, inspect naming info
      and design metrics
    * `Blendend.Text.Font` – create sized fonts, configure OpenType features
      * Shaping (text -> glyph run) works on GlyphBuffer 
        and fills it with glyphs, advances, offsets and ligatures.
      * Outlining (glyph run -> paths) takes a GlyphRun and produce 
        paths describing the outlines of those glyphs.

    * `Blendend.Text.GlyphBuffer` – holds input UTF-8 text and shaped glyphs
    * `Blendend.Text.GlyphRun` – views over glyph sequences, including
      utilities to inspect runs, slice them, and render with a font

  Typical low-level-pipeline:
      
      alias Blendend.Text
      alias Blendend.Text.{Face, Font, GlyphBuffer, GlyphRun}
      face = Face.load!("priv/fonts/Alegreya-Regular.otf")
      font = Font.create!(face, 48.0)
      gr = GlyphBuffer.new!()
       |> GlyphBuffer.set_utf8_text!("Hello")
       |> Font.shape!(font)
       |> GlyphRun.new!()
      or simply:
      {:ok, gr} = Text.shape(font, "Hello!")
      Then draw the run on the canvas.
      :ok = GlyphRun.fill(canvas, font, 100, 150, gr, color: Style.color(255, 255, 255))

      # or turn glyphs into a Path and manipulate outlines
      m   = Blendend.Matrix2D.identity!()
      path = Blendend.Path.new!()
      glyph_paths  = Blendend.Text.Font.get_glyph_run_outlines!(font, gr, m, path)

  ### Images

  `blendend` treats images as regular data we can load, inspect, and then
  reuse as styles.

  * Use `Blendend.Image` to load images from disk or memory and query their
    `{width, height}`.
  * Turn an image into a reusable style with `Blendend.Style.Pattern`, then
    pass that pattern as `pattern:` (or `stroke_pattern:`) to canvas drawing
    functions.
  * Patterns support extend modes (`:pad`, `:repeat`, `:reflect` ...) and their
    own transform (`Blendend.Matrix2D`), so we can tile, mirror, rotate, or
    scale textures.

  For export, encode a canvas to:

  * PNG – `Blendend.Canvas.to_png/1`, `Blendend.Canvas.save/2`
  * QOI – `Blendend.Canvas.to_qoi/1`, `Blendend.Canvas.save_qoi/2`

  The usual flow is:

      {:ok, img} = Blendend.Image.from_data(bytes)
      pat        = Blendend.Style.Pattern.create!(img)
      # ...draw with `pattern: pat`...
      :ok        = Blendend.Canvas.save!(canvas, "out.png")

  ## Error handling

  Most NIFs follow the convention:

    * on success: `{:ok, value}` or `:ok`
    * on failure: `{:error, reason}` (with descriptive atoms or strings)

  For pipelines  many modules provide bang variants
  (`new!/0`, `to_png!/1`, `save!/2` ...) which raise `Blendend.Error` on failure.

  ## Library layout

  The main public modules are:

    * `Blendend.Canvas` – canvas creation, transforms, compositing, export
    * `Blendend.Canvas.Fill` / `Blendend.Canvas.Stroke` – shape drawing
    * `Blendend.Path` – path building and manipulation
    * `Blendend.Style.*` – colors, gradients, patterns and style helpers
    * `Blendend.Matrix2D` – 2D transform matrices
    * `Blendend.Text.*` – font faces, fonts, glyph buffers and runs
    * `Blendend.Draw` – high–level drawing DSL for demos and playgrounds

  Internally, `blendend` is implemented as a set of C++ NIFs that wrap blend2d
  APIs with careful resource management and dirty–scheduler usage where
  appropriate.

  ## Where this is going

  `blendend` leans into two gaps in the Elixir ecosystem:

    * **Data visualization building blocks** –
      primitives like `Blendend.Frame` that map math space to pixels,
      draw axes and grids, and make it easy to plot functions or datasets.
      Think “parts of matplotlib”, not a full charting library.

    * **Rich text layout** –
      on top of `Blendend.Text.Font` and shaping, the goal is a
      `Blendend.Text.Paragraph` layer that can lay out styled text blocks
      (headings, body, inline colors, spans) and render them into our
      drawings, a bit like a tiny LaTeX/page layout engine.

  The idea isn't "flashy graphics for their own sake", but clean, precise
  images that carry information and still look good.

  """
end
