defmodule Blendend do
  @moduledoc """
  `blendend` is an Elixir wrapper around the [blend2d](https://blend2d.com) 2D
  graphics engine.

  ## Core concepts

  ### Canvas

  The main drawing surface in `blendend` is a **canvas** (`Blendend.Canvas` resource).

  A canvas owns:

    * an internal pixel buffer (32-bit RGBA, with alpha)
    * a `blend2d` context that stores the **current graphics state**:
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

  A **path** is a sequence of lines and curves. We can fill or stroke paths just like simple shapes.

  ### Styles, colors, gradients, patterns

  Whenever we fill or stroke a geometry, we apply a **style**
  `blendend` has:

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
        color: Color.rgb!(240, 240, 255),
        comp_op: :multiply
      )

  """
end
