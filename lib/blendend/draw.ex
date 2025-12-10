defmodule Blendend.Draw do
  @moduledoc """
  This module contains macros for writing `blendend` drawings as Elixir code.

  You typically `use` this module in a script, IEx, or a web playground and
  then drive everything through `draw/2` or `draw/3`:

      use Blendend.Draw

      draw 400, 300, "priv/rect.png" do
        rect 40.0, 40.0, 320.0, 220.0, fill: rgb(255, 255, 255)
      end

  ## What `draw/...` does

  A `draw/2` or `draw/3` call:

    * creates a new `Blendend.Canvas` of the given size
    * stores it as the *current* canvas in the calling process,
    * executes a block, where helpers like `rect/...`, `circle/...`, `text...`
    * finally encodes the image via:
       `Blendend.Canvas.to_png_base64/1`. (`draw/2`)
       `Blendend.Canvas.save/2`. (`draw/3`)
  The return value is whatever `Blendend.Canvas.to_png_base64/1` returns
  (usually `{:ok, base64}`), which makes it easy to give to a web UI:
  Examples: 
  ```
      {:ok, b64} = draw 400, 300 do
                 # ...
                 end

      "data:image/png;base64," <> b64
      # usable as <img src="data:image/png;base64,\#{b64}">
  ```
  This makes the `Blendend.Draw` especially convenient for
  HTTP-streaming setups where we regenerate PNGs on demand.


  ## Process-local state

  The current canvas is stored in the process dictionary.
  Nested `draw/2` in the same process will overwrite the previous state.

  ## Shape API

  Shape helpers (`rect/4`, `circle/3`, `polygon/2`, etc.) default to filling.
  Use `fill: color/gradient/pattern` to set the fill. 
  To stroke instead, pass
  `mode: :stroke` or supply stroke-specific options (`:stroke` with a
  color/gradient/pattern, plus `:stroke_width`, `:stroke_cap`, etc.).


  """
  @canvas_key :blendend_current_canvas

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  # ------------------------------------------------------------------
  # process-local state
  # ------------------------------------------------------------------
  defp put_canvas(c), do: Process.put(@canvas_key, c)

  @doc """
  Returns the current process-local canvas.

  Raises if no canvas is active (use `draw/3` to establish one).
  """
  def get_canvas() do
    Process.get(@canvas_key) ||
      raise "No active canvas. Use draw/3 first."
  end

  # ------------------------------------------------------------------
  # helpers: floatification
  # ------------------------------------------------------------------

  defp to_f(v) when is_integer(v), do: v * 1.0
  defp to_f(v) when is_float(v), do: v
  defp to_f(v), do: v

  defp to_f_points(points) do
    Enum.map(points, fn {x, y} -> {to_f(x), to_f(y)} end)
  end

  defp to_f_boxes(boxes) do
    Enum.map(boxes, fn {x0, y0, x1, y1} ->
      {to_f(x0), to_f(y0), to_f(x1), to_f(y1)}
    end)
  end

  defp to_f_rects(rects) do
    Enum.map(rects, fn {x, y, w, h} ->
      {to_f(x), to_f(y), to_f(w), to_f(h)}
    end)
  end

  # fill vs stroke for shapes that support both
  @doc false
  def classify_mode(opts) do
    mode = Keyword.get(opts, :mode)
    opts = Keyword.drop(opts, [:mode])

    stroke_keys = [:stroke, :stroke_color, :stroke_gradient, :stroke_pattern]

    case mode do
      :stroke ->
        {:stroke, Keyword.drop(opts, [:color, :gradient, :pattern])}

      :fill ->
        {:fill, Keyword.drop(opts, stroke_keys)}

      _ ->
        has_stroke? = Enum.any?(stroke_keys, &Keyword.has_key?(opts, &1))

        if has_stroke? do
          {:stroke, Keyword.drop(opts, [:color, :gradient, :pattern])}
        else
          {:fill, Keyword.drop(opts, stroke_keys)}
        end
    end
  end

  @doc """
  Creates an RGB color (0–255 channels, optional alpha).

  Convenience for `Blendend.Style.Color.rgb!/4`.

  Forms:

    * `rgb(r, g, b, a \\ 255)`
    * `rgb(:random)` for an opaque random color
  """
  defmacro rgb(:random) do
    quote do
      Blendend.Style.Color.random()
    end
  end

  defmacro rgb(r, g, b, a \\ 255) do
    quote bind_quoted: [r: r, g: g, b: b, a: a] do
      Blendend.Style.Color.rgb!(r, g, b, a)
    end
  end

  @doc """
  Creates a color from HSV components plus alpha (0–255).

  `h` in degrees (0–360), `s` and `v` as 0.0–1.0 floats, `a` as 0–255.
  Convenience for `Blendend.Style.Color.from_hsv/4`.

  Forms:

    * `hsv(h, s, v, a \\ 255)`
  """
  defmacro hsv(h, s, v, a \\ 255) do
    quote bind_quoted: [h: h, s: s, v: v, a: a] do
      Blendend.Style.Color.from_hsv(h, s, v, a)
    end
  end

  @doc """
  Top–level entry point for Blendend drawings.

  `draw/3` and `draw/4` create a new `Blendend.Canvas`, make it the *current*
  canvas for the calling process, execute the given block, and finally encode
  the canvas as a PNG.

  There are two forms:

    * `draw width, height do ... end`
    * `draw width, height, "image.png" do ... end`
  ## Basic usage

  The simple form creates a canvas, clears it, runs the block, and returns
  the result of `Blendend.Canvas.to_png_base64/1`:

      iex> {:ok, png_b64} =
      ...>   draw 400, 300 do
      ...>     rect 40.0, 40.0, 320.0, 220.0,
      ...>       fill: rgb(255, 255, 255)
      ...>   end

  Inside the block, other Draw helpers such as `rect/5`, `circle/4`, `text/4`,
  etc. implicitly use the *current* canvas via `Blendend.Draw.get_canvas/0`.

  ## Process-local state

  `draw/...` stores the current canvas in the process dictionary under
  private keys. This means:

    * the Draw state is scoped to the calling process, and
    * nested `draw/...` calls in the same process are not supported and will
      overwrite the previous state.

  For typical usage this keeps the call sites concise 
  while avoiding global mutable state.
  """

  defmacro draw(w, h, do: body) do
    quote do
      Blendend.Draw.__draw__(unquote(w), unquote(h), fn -> unquote(body) end)
    end
  end

  def __draw__(w, h, fun) do
    {:ok, c} = Blendend.Canvas.new(w, h)
    put_canvas(c)
    Blendend.Canvas.clear(c)
    _ = fun.()
    Blendend.Canvas.to_png_base64(c)
  end

  @doc """
  Same as `draw/3` but saves canvas in a png file.
  """
  defmacro draw(w, h, file, do: body) do
    quote do
      Blendend.Draw.__drawsave__(unquote(w), unquote(h), unquote(file), fn ->
        unquote(body)
      end)
    end
  end

  @doc false
  def __drawsave__(w, h, file, fun) do
    {:ok, c} = Blendend.Canvas.new(w, h)
    put_canvas(c)
    Blendend.Canvas.clear(c)
    _ = fun.()
    Blendend.Canvas.save(c, file)
  end

  @doc """
  Clears the current canvas with the given options.

  Wraps `Blendend.Canvas.clear/2`; common options include `fill: color/gradient/pattern`.
  """
  defmacro clear(opts) do
    quote bind_quoted: [opts: opts] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.clear(c, opts)
    end
  end

  @doc """
  Sets the fill rule for the current canvas (`:non_zero` or `:even_odd`).

  Wraps `Blendend.Canvas.set_fill_rule/2`.
  """
  defmacro fill_rule(rule) do
    quote bind_quoted: [rule: rule] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.set_fill_rule(c, rule)
    end
  end

  # Internal helpers for the path macro.
  defp path_impl(path_var, rewritten_body) do
    quote do
      unquote(path_var) = Blendend.Path.new!()
      _ = unquote(rewritten_body)
      unquote(path_var)
    end
  end

  defp rewrite_path_dsl(ast, path_var) do
    Macro.prewalk(ast, fn
      {:move_to, meta, [x, y]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :move_to!]}, meta, [path_var, x, y]}

      {:line_to, meta, [x, y]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :line_to!]}, meta, [path_var, x, y]}

      {:arc_to, meta, [cx, cy, rx, ry, start, sweep, force_move?]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :arc_to!]}, meta,
         [path_var, cx, cy, rx, ry, start, sweep, force_move?]}

      {:quad_to, meta, [x1, y1, x2, y2]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :quad_to!]}, meta,
         [path_var, x1, y1, x2, y2]}

      {:cubic_to, meta, [x1, y1, x2, y2, x3, y3]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :cubic_to!]}, meta,
         [path_var, x1, y1, x2, y2, x3, y3]}

      {:conic_to, meta, [x1, y1, x2, y2, w]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :conic_to!]}, meta,
         [path_var, x1, y1, x2, y2, w]}

      {:arc_quadrant_to, meta, [x1, y1, x2, y2]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :arc_quadrant_to!]}, meta,
         [path_var, x1, y1, x2, y2]}

      {:smooth_quad_to, meta, [x2, y2]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :smooth_quad_to!]}, meta,
         [path_var, x2, y2]}

      {:smooth_cubic_to, meta, [x2, y2, x3, y3]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :smooth_cubic_to!]}, meta,
         [path_var, x2, y2, x3, y3]}

      {:close, meta, []} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :close!]}, meta, [path_var]}

      {:add_circle, meta, [x, y, r]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_circle!]}, meta,
         [path_var, x, y, r]}

      {:add_circle, meta, [x, y, r, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_circle!]}, meta,
         [path_var, x, y, r, opts]}

      {:add_box, meta, [x0, y0, x1, y1]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_box!]}, meta,
         [path_var, x0, y0, x1, y1]}

      {:add_box, meta, [x0, y0, x1, y1, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_box!]}, meta,
         [path_var, x0, y0, x1, y1, opts]}

      {:add_rect, meta, [x, y, w, h]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_rect!]}, meta,
         [path_var, x, y, w, h]}

      {:add_rect, meta, [x, y, w, h, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_rect!]}, meta,
         [path_var, x, y, w, h, opts]}

      {:add_ellipse, meta, [cx, cy, rx, ry]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_ellipse!]}, meta,
         [path_var, cx, cy, rx, ry]}

      {:add_ellipse, meta, [cx, cy, rx, ry, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_ellipse!]}, meta,
         [path_var, cx, cy, rx, ry, opts]}

      {:add_round_rect, meta, [x, y, w, h, rx, ry]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_round_rect!]}, meta,
         [path_var, x, y, w, h, rx, ry]}

      {:add_round_rect, meta, [x, y, w, h, rx, ry, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_round_rect!]}, meta,
         [path_var, x, y, w, h, rx, ry, opts]}

      {:add_arc, meta, [cx, cy, rx, ry, start, sweep]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_arc!]}, meta,
         [path_var, cx, cy, rx, ry, start, sweep]}

      {:add_arc, meta, [cx, cy, rx, ry, start, sweep, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_arc!]}, meta,
         [path_var, cx, cy, rx, ry, start, sweep, opts]}

      {:add_chord, meta, [cx, cy, rx, ry, start, sweep]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_chord!]}, meta,
         [path_var, cx, cy, rx, ry, start, sweep]}

      {:add_chord, meta, [cx, cy, rx, ry, start, sweep, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_chord!]}, meta,
         [path_var, cx, cy, rx, ry, start, sweep, opts]}

      {:add_line, meta, [x0, y0, x1, y1]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_line!]}, meta,
         [path_var, x0, y0, x1, y1]}

      {:add_line, meta, [x0, y0, x1, y1, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_line!]}, meta,
         [path_var, x0, y0, x1, y1, opts]}

      {:add_triangle, meta, [x0, y0, x1, y1, x2, y2]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_triangle!]}, meta,
         [path_var, x0, y0, x1, y1, x2, y2]}

      {:add_triangle, meta, [x0, y0, x1, y1, x2, y2, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_triangle!]}, meta,
         [path_var, x0, y0, x1, y1, x2, y2, opts]}

      {:add_polyline, meta, [points]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_polyline!]}, meta,
         [path_var, points]}

      {:add_polyline, meta, [points, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_polyline!]}, meta,
         [path_var, points, opts]}

      {:add_polygon, meta, [points]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_polygon!]}, meta,
         [path_var, points]}

      {:add_polygon, meta, [points, opts]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Path]}, :add_polygon!]}, meta,
         [path_var, points, opts]}

      other ->
        other
    end)
  end

  @doc """
  Build a `Blendend.Path` with a concise DSL.

      p =
        path do
          move_to 0, 0
          line_to 20, 0
          line_to 20, 10
        end

      badge =
        path badge do
          add_round_rect(20, 20, 140, 80, 12, 12)
          add_circle(60, 60, 18)
          add_line(20, 20, 160, 100)
        end

  Forms:
    * `path do ... end` – returns a new `Blendend.Path` with the given commands.
    * `path name do ... end` – same, but also binds the path to `name` in the caller.

  What it does:
    * creates a fresh `Blendend.Path` (`Path.new!`)
    * rewrites DSL calls (`move_to/2`, `line_to/2`, `add_*`, etc.) to `Blendend.Path.*!/…`
      against that path (no reliance on `var!/1`)
  """
  # Base path macros (declared before wrappers to avoid compile ordering issues)
  defmacro path(do: body) do
    path = Macro.unique_var(:path, __MODULE__)
    rewritten = rewrite_path_dsl(body, path)
    path_impl(path, rewritten)
  end

  defmacro path(var_ast, do: body) do
    var =
      case var_ast do
        {name, _, _} when is_atom(name) -> name
        name when is_atom(name) -> name
        other -> raise ArgumentError, "path/2 expects a variable name, got: #{inspect(other)}"
      end

    path = Macro.var(var, nil)
    rewritten = rewrite_path_dsl(body, path)
    path_impl(path, rewritten)
  end

  @doc """
  Creates a fresh `t:Blendend.Path.t/0`.
  """
  defmacro path do
    quote do
      Blendend.Path.new!()
    end
  end

  @doc """
  Build a `Blendend.Matrix2D` with a tiny DSL.

      m =
        matrix do
          translate 40, 90
          rotate :math.pi() / 3
          skew 0.1, 0.0
          scale 1.2, 0.8
        end

  Forms:
    * `matrix()` – returns identity
    * `matrix do ... end` – identity then applies DSL ops in order
  """
  defmacro matrix(do: body) do
    mat = Macro.unique_var(:matrix, __MODULE__)
    rewritten = rewrite_matrix_dsl(body, mat)

    quote do
      unquote(mat) = Blendend.Matrix2D.identity!()
      _ = unquote(rewritten)
      unquote(mat)
    end
  end

  @doc """
  Returns the identity matrix.
  """
  defmacro matrix do
    quote do
      Blendend.Matrix2D.identity!()
    end
  end

  defp rewrite_matrix_dsl(ast, mtx_var) do
    Macro.prewalk(ast, fn
      {:translate, meta, [x, y]} ->
        {:=, meta,
         [
           mtx_var,
           {{:., meta, [{:__aliases__, [], [:Blendend, :Matrix2D]}, :translate!]}, meta,
            [mtx_var, x, y]}
         ]}

      {:post_translate, meta, [x, y]} ->
        {:=, meta,
         [
           mtx_var,
           {{:., meta, [{:__aliases__, [], [:Blendend, :Matrix2D]}, :post_translate!]}, meta,
            [mtx_var, x, y]}
         ]}

      {:rotate, meta, [angle]} ->
        {:=, meta,
         [
           mtx_var,
           {{:., meta, [{:__aliases__, [], [:Blendend, :Matrix2D]}, :rotate!]}, meta,
            [mtx_var, angle]}
         ]}

      {:rotate, meta, [angle, cx, cy]} ->
        {:=, meta,
         [
           mtx_var,
           {{:., meta, [{:__aliases__, [], [:Blendend, :Matrix2D]}, :rotate_at!]}, meta,
            [mtx_var, angle, cx, cy]}
         ]}

      {:post_rotate, meta, [angle, cx, cy]} ->
        {:=, meta,
         [
           mtx_var,
           {{:., meta, [{:__aliases__, [], [:Blendend, :Matrix2D]}, :post_rotate!]}, meta,
            [mtx_var, angle, cx, cy]}
         ]}

      {:skew, meta, [kx, ky]} ->
        {:=, meta,
         [
           mtx_var,
           {{:., meta, [{:__aliases__, [], [:Blendend, :Matrix2D]}, :skew!]}, meta,
            [mtx_var, kx, ky]}
         ]}

      {:post_skew, meta, [kx, ky]} ->
        {:=, meta,
         [
           mtx_var,
           {{:., meta, [{:__aliases__, [], [:Blendend, :Matrix2D]}, :post_skew!]}, meta,
            [mtx_var, kx, ky]}
         ]}

      {:scale, meta, [sx, sy]} ->
        {:=, meta,
         [
           mtx_var,
           {{:., meta, [{:__aliases__, [], [:Blendend, :Matrix2D]}, :scale!]}, meta,
            [mtx_var, sx, sy]}
         ]}

      {:post_scale, meta, [sx, sy]} ->
        {:=, meta,
         [
           mtx_var,
           {{:., meta, [{:__aliases__, [], [:Blendend, :Matrix2D]}, :post_scale!]}, meta,
            [mtx_var, sx, sy]}
         ]}

      other ->
        other
    end)
  end

  # ------------------------------------------------------------------
  # Gradient DSL
  # ------------------------------------------------------------------

  defp rewrite_grad_dsl(ast, grad_var) do
    Macro.prewalk(ast, fn
      {:add_stop, meta, [offset, color]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Style, :Gradient]}, :add_stop!]}, meta,
         [grad_var, offset, color]}

      {:set_extend, meta, [mode]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Style, :Gradient]}, :set_extend!]}, meta,
         [grad_var, mode]}

      {:set_transform, meta, [matrix]} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Style, :Gradient]}, :set_transform!]}, meta,
         [grad_var, matrix]}

      {:reset_transform, meta, []} ->
        {{:., meta, [{:__aliases__, [], [:Blendend, :Style, :Gradient]}, :reset_transform!]},
         meta, [grad_var]}

      other ->
        other
    end)
  end

  @doc """
  Build a linear gradient.

      grad =
        linear_gradient 0, 0, 0, 200 do
          add_stop 0.0, rgb(255, 0, 0)
          add_stop 1.0, rgb(0, 0, 255)
        end
  """
  defmacro linear_gradient(x0, y0, x1, y1, do: body) do
    grad = Macro.unique_var(:grad, __MODULE__)
    rewritten = rewrite_grad_dsl(body, grad)

    quote do
      unquote(grad) =
        Blendend.Style.Gradient.linear!(unquote(x0), unquote(y0), unquote(x1), unquote(y1))

      _ = unquote(rewritten)
      unquote(grad)
    end
  end

  @doc """
  Build a radial gradient.

      radial_gradient cx0, cy0, r0, cx1, cy1, r1 do
        add_stop 0.0, rgb(255, 255, 0)
        add_stop 1.0, rgb(0, 0, 0)
      end
  """
  defmacro radial_gradient(cx0, cy0, r0, cx1, cy1, r1, do: body) do
    grad = Macro.unique_var(:grad, __MODULE__)
    rewritten = rewrite_grad_dsl(body, grad)

    quote do
      unquote(grad) =
        Blendend.Style.Gradient.radial!(
          unquote(cx0),
          unquote(cy0),
          unquote(r0),
          unquote(cx1),
          unquote(cy1),
          unquote(r1)
        )

      _ = unquote(rewritten)
      unquote(grad)
    end
  end

  @doc """
  Build a conic gradient.

      conic_gradient cx, cy, angle do
        add_stop 0.0, rgb(255, 0, 0)
        add_stop 1.0, rgb(0, 255, 0)
      end
  """
  defmacro conic_gradient(cx, cy, angle, do: body) do
    grad = Macro.unique_var(:grad, __MODULE__)
    rewritten = rewrite_grad_dsl(body, grad)

    quote do
      unquote(grad) = Blendend.Style.Gradient.conic!(unquote(cx), unquote(cy), unquote(angle))
      _ = unquote(rewritten)
      unquote(grad)
    end
  end

  @doc """
  Loads a font face from the given path and creates a font at the specified size.

  Returns the font or raises on error.
  """
  defmacro load_font(path, size) do
    quote bind_quoted: [path: path, size: size] do
      path
      |> Blendend.Text.Face.load!()
      |> Blendend.Text.Font.create!(size)
    end
  end

  @doc """
  Convenience macro for `Blendend.Text.Face.load!/1`.
  """
  defmacro font_face(path) do
    quote bind_quoted: [path: path] do
      Blendend.Text.Face.load!(path)
    end
  end

  @doc """
  Convenience macro for `Blendend.Text.Font.create!/2`.
  """
  defmacro font_create(face, size) do
    quote bind_quoted: [face: face, size: size] do
      Blendend.Text.Font.create!(face, size)
    end
  end

  @doc """
  Draws UTF-8 text at the given position using a `Blendend.Text.Font`.

  Supports both fill and stroke modes (auto-detected via options or `mode: :fill | :stroke`).
  Common options: `fill: color/gradient/pattern`, `stroke: color/gradient/pattern`,
  `stroke_width`, `stroke_cap`, `stroke_join`, `alpha` (in fill mode), `stroke_alpha`, etc.
  """
  defmacro text(font, x, y, string, opts \\ []) do
    quote bind_quoted: [x: x, y: y, font: font, string: string, opts: opts] do
      c = Blendend.Draw.get_canvas()

      case classify_mode(opts) do
        {:stroke, stroke_opts} ->
          Blendend.Canvas.Stroke.utf8_text!(c, font, x, y, string, stroke_opts)

        {:fill, fill_opts} ->
          Blendend.Canvas.Fill.utf8_text!(c, font, x, y, string, fill_opts)
      end

      :ok
    end
  end

  # generic shape handler
  # PATH =====================================================================
  @doc false
  def __shape__(:fill_path, p, opts) do
    c = get_canvas()

    Blendend.Canvas.Fill.path(c, p, opts)
    :ok
  end

  @doc false
  def __shape__(:stroke_path, p, opts) do
    c = get_canvas()

    Blendend.Canvas.Stroke.path(c, p, opts)
    :ok
  end

  # BOX ======================================================================
  @doc false
  def __shape__(:box, [x0, y0, x1, y1], opts) do
    c = get_canvas()

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.box(c, x0, y0, x1, y1, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.box(c, x0, y0, x1, y1, fill_opts)
    end

    :ok
  end

  # RECT =====================================================================
  @doc false
  def __shape__(:rect, [x, y, w, h], opts) do
    c = get_canvas()

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.rect(c, x, y, w, h, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.rect(c, x, y, w, h, fill_opts)
    end

    :ok
  end

  # CIRCLE ===================================================================
  @doc false
  def __shape__(:circle, [cx, cy, r], opts) do
    c = get_canvas()

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.circle(c, cx, cy, r, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.circle(c, cx, cy, r, fill_opts)
    end

    :ok
  end

  # ELLIPSE ==================================================================
  @doc false
  def __shape__(:ellipse, [cx, cy, rx, ry], opts) do
    c = get_canvas()

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.ellipse(c, cx, cy, rx, ry, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.ellipse(c, cx, cy, rx, ry, fill_opts)
    end

    :ok
  end

  # ROUND RECT ===============================================================
  @doc false
  def __shape__(:round_rect, [x, y, w, h, rx, ry], opts) do
    c = get_canvas()

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.round_rect(c, x, y, w, h, rx, ry, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.round_rect(c, x, y, w, h, rx, ry, fill_opts)
    end

    :ok
  end

  # CHORD ====================================================================
  @doc false
  def __shape__(:chord, [cx, cy, rx, ry, start_angle, sweep_angle], opts) do
    c = get_canvas()

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.chord(c, cx, cy, rx, ry, start_angle, sweep_angle, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.chord(c, cx, cy, rx, ry, start_angle, sweep_angle, fill_opts)
    end

    :ok
  end

  # PIE ======================================================================
  @doc false
  def __shape__(:pie, [cx, cy, rx, ry, start_angle, sweep_angle], opts) do
    c = get_canvas()

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.pie(c, cx, cy, rx, ry, start_angle, sweep_angle, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.pie(c, cx, cy, rx, ry, start_angle, sweep_angle, fill_opts)
    end

    :ok
  end

  # TRIANGLE =================================================================
  @doc false
  def __shape__(:triangle, [x0, y0, x1, y1, x2, y2], opts) do
    c = get_canvas()

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.triangle(c, x0, y0, x1, y1, x2, y2, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.triangle(c, x0, y0, x1, y1, x2, y2, fill_opts)
    end

    :ok
  end

  # POLYGON / POLYLINE =======================================================
  @doc false
  def __shape__(:polygon, [points], opts) do
    c = get_canvas()
    points = to_f_points(points)

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.polygon(c, points, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.polygon(c, points, fill_opts)
    end

    :ok
  end

  @doc false
  def __shape__(:polyline, [points], opts) do
    c = get_canvas()
    points = to_f_points(points)
    Blendend.Canvas.Stroke.polyline(c, points, opts)
    :ok
  end

  # BOX ARRAY ================================================================
  @doc false
  def __shape__(:box_array, [boxes], opts) do
    c = get_canvas()
    boxes = to_f_boxes(boxes)

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.box_array(c, boxes, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.box_array(c, boxes, fill_opts)
    end

    :ok
  end

  # RECT ARRAY ===============================================================
  @doc false
  def __shape__(:rect_array, [rects], opts) do
    c = get_canvas()
    rects = to_f_rects(rects)

    case classify_mode(opts) do
      {:stroke, stroke_opts} ->
        Blendend.Canvas.Stroke.rect_array(c, rects, stroke_opts)

      {:fill, fill_opts} ->
        Blendend.Canvas.Fill.rect_array(c, rects, fill_opts)
    end

    :ok
  end

  # LINE =====================================================================

  @doc false
  def __shape__(:line, [x0, y0, x1, y1], opts) do
    c = get_canvas()

    Blendend.Canvas.Stroke.line(c, x0, y0, x1, y1, opts)
    :ok
  end

  # ARC ======================================================================
  @doc false
  def __shape__(:arc, [cx, cy, rx, ry, start_angle, sweep_angle], opts) do
    c = get_canvas()

    Blendend.Canvas.Stroke.arc(c, cx, cy, rx, ry, start_angle, sweep_angle, opts)
    :ok
  end

  @doc """
  Fills a path on the current canvas.

  Style options mirror `Blendend.Canvas.Fill.path/3` (`:fill` with color/gradient/pattern, plus `:alpha`, `:comp_op`, etc.).
  """
  defmacro fill_path(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      Blendend.Draw.__shape__(:fill_path, path, opts)
    end
  end

  @doc """
  Strokes a path on the current canvas.

  Style options mirror `Blendend.Canvas.Stroke.path/3` (`:stroke` with color/gradient/pattern, plus `:stroke_width`, caps/joins, `:comp_op`, etc.).
  """
  defmacro stroke_path(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      Blendend.Draw.__shape__(:stroke_path, path, opts)
    end
  end

  @doc """
  Draws a box given corners `{x0, y0}` and `{x1, y1}` (fill or stroke).

  Style options match the shape API (`:fill`/`:stroke` with color/gradient/pattern, `:stroke_width`, `:comp_op`, etc.).
  """

  defmacro box(x0, y0, x1, y1, opts \\ []) do
    quote bind_quoted: [x0: x0, y0: y0, x1: x1, y1: y1, opts: opts] do
      Blendend.Draw.__shape__(:box, [x0, y0, x1, y1], opts)
    end
  end

  @doc """
  Draws a rectangle at `{x, y}` with width `w` and height `h` (fill or stroke).

  Style options match the shape API.
  """
  defmacro rect(x, y, w, h, opts \\ []) do
    quote bind_quoted: [x: x, y: y, w: w, h: h, opts: opts] do
      Blendend.Draw.__shape__(:rect, [x, y, w, h], opts)
    end
  end

  @doc """
  Draw a rectangle using its center point.

  Mirrors p5.js `rectMode(CENTER)`: `(cx, cy)` is the center; `w`/`h` are size.
  """
  defmacro rect_center(cx, cy, w, h, opts \\ []) do
    quote bind_quoted: [cx: cx, cy: cy, w: w, h: h, opts: opts] do
      x0 = cx - w / 2
      y0 = cy - h / 2
      Blendend.Draw.__shape__(:rect, [x0, y0, w, h], opts)
    end
  end

  @doc """
  Draws a circle centered at `{cx, cy}` with radius `r` (fill or stroke).

  Style options match the shape API.
  """
  defmacro circle(cx, cy, r, opts \\ []) do
    quote bind_quoted: [cx: cx, cy: cy, r: r, opts: opts] do
      Blendend.Draw.__shape__(:circle, [cx, cy, r], opts)
    end
  end

  @doc """
  Draws an ellipse centered at `{cx, cy}` with radii `(rx, ry)` (fill or stroke).

  Style options match the shape API.
  """
  defmacro ellipse(cx, cy, rx, ry, opts \\ []) do
    quote bind_quoted: [cx: cx, cy: cy, rx: rx, ry: ry, opts: opts] do
      Blendend.Draw.__shape__(:ellipse, [cx, cy, rx, ry], opts)
    end
  end

  @doc """
  Draws a rounded rectangle `(x, y, w, h)` with corner radii `(rx, ry)` (fill or stroke).

  Style options match the shape API.
  """
  defmacro round_rect(x, y, w, h, rx, ry, opts \\ []) do
    quote bind_quoted: [x: x, y: y, w: w, h: h, rx: rx, ry: ry, opts: opts] do
      Blendend.Draw.__shape__(:round_rect, [x, y, w, h, rx, ry], opts)
    end
  end

  @doc """
  Draws a chord (closed arc) with center `(cx, cy)`, radii `(rx, ry)`, start angle, and sweep (radians).

  Style options match the shape API.
  """
  defmacro chord(cx, cy, rx, ry, start_angle, sweep_angle, opts \\ []) do
    quote bind_quoted: [
            cx: cx,
            cy: cy,
            rx: rx,
            ry: ry,
            start_angle: start_angle,
            sweep_angle: sweep_angle,
            opts: opts
          ] do
      Blendend.Draw.__shape__(
        :chord,
        [cx, cy, rx, ry, start_angle, sweep_angle],
        opts
      )
    end
  end

  @doc """
  Draws a pie slice with center `(cx, cy)`, radii `(rx, ry)`, start angle, and sweep (radians).

  Style options match the shape API.
  """
  defmacro pie(cx, cy, rx, ry, start_angle, sweep_angle, opts \\ []) do
    quote bind_quoted: [
            cx: cx,
            cy: cy,
            rx: rx,
            ry: ry,
            start_angle: start_angle,
            sweep_angle: sweep_angle,
            opts: opts
          ] do
      Blendend.Draw.__shape__(
        :pie,
        [cx, cy, rx, ry, start_angle, sweep_angle],
        opts
      )
    end
  end

  @doc """
  Draws a triangle, equilateral when given a center point and side length.

  `triangle(cx, cy, side)` – builds an equilateral triangle centered at `{cx, cy}`,
  pointing up, with edge length `side`.  
  Same style `opts` as `Blendend.Canvas.Fill.path/3` or `Blendend.Canvas.Stroke.path/3`.
  """
  defmacro triangle(cx, cy, side, opts \\ []) do
    quote bind_quoted: [cx: cx, cy: cy, side: side, opts: opts] do
      h = side * :math.sqrt(3) / 2.0
      offset = h / 3.0

      x0 = cx
      y0 = cy - offset
      x1 = cx - side / 2.0
      y1 = cy + (h - offset)
      x2 = cx + side / 2.0
      y2 = cy + (h - offset)

      Blendend.Draw.__shape__(:triangle, [x0, y0, x1, y1, x2, y2], opts)
    end
  end

  @doc """
  `triangle(x0, y0, x1, y1, x2, y2)` – triangle from explicit vertices.
  Same style `opts` as `Blendend.Canvas.Fill.path/3` or `Blendend.Canvas.Stroke.path/3`.
  """
  defmacro triangle(x0, y0, x1, y1, x2, y2, opts \\ []) do
    quote bind_quoted: [x0: x0, y0: y0, x1: x1, y1: y1, x2: x2, y2: y2, opts: opts] do
      Blendend.Draw.__shape__(:triangle, [x0, y0, x1, y1, x2, y2], opts)
    end
  end

  @doc """
  Draws a polygon (fill or stroke) from a list of `{x, y}` points.

  Style options match `Blendend.Canvas.Fill.path/3` and `Blendend.Canvas.Stroke.path/3`
  (e.g. `fill: color/gradient/pattern`, `stroke: color/gradient/pattern`, `:stroke_width`, `:comp_op`).
  """
  defmacro polygon(points, opts \\ []) do
    quote bind_quoted: [points: points, opts: opts] do
      Blendend.Draw.__shape__(:polygon, [points], opts)
    end
  end

  @doc """
  Draws a stroked polyline from a list of `{x, y}` points.

  Style options match `Blendend.Canvas.Stroke.path/3` (`:stroke`, `:stroke_width`, `:stroke_cap`, etc.).
  """
  defmacro polyline(points, opts \\ []) do
    quote bind_quoted: [points: points, opts: opts] do
      Blendend.Draw.__shape__(:polyline, [points], opts)
    end
  end

  @doc """
  Draws multiple boxes from a list of `{x0, y0, x1, y1}` tuples (fill or stroke).

  Style options match `Blendend.Canvas.Fill.path/3` and `Blendend.Canvas.Stroke.path/3`.
  """
  defmacro box_array(boxes, opts \\ []) do
    quote bind_quoted: [boxes: boxes, opts: opts] do
      Blendend.Draw.__shape__(:box_array, [boxes], opts)
    end
  end

  @doc """
  Draws multiple rects from a list of `{x, y, w, h}` tuples (fill or stroke).

  Style options match `Blendend.Canvas.Fill.path/3` and `Blendend.Canvas.Stroke.path/3`.
  """
  defmacro rect_array(rects, opts \\ []) do
    quote bind_quoted: [rects: rects, opts: opts] do
      Blendend.Draw.__shape__(:rect_array, [rects], opts)
    end
  end

  @doc """
  Draws a stroked line segment from `{x0, y0}` to `{x1, y1}`.

  Style options match `Blendend.Canvas.Stroke.path/3` (`:stroke`, `:stroke_width`, `:stroke_cap`, etc.).
  """
  defmacro line(x0, y0, x1, y1, opts \\ []) do
    quote bind_quoted: [x0: x0, y0: y0, x1: x1, y1: y1, opts: opts] do
      Blendend.Draw.__shape__(:line, [x0, y0, x1, y1], opts)
    end
  end

  @doc """
  Draws a stroked elliptical arc defined by center `(cx, cy)`, radii `(rx, ry)`,
  start angle, and sweep angle (radians).

  Style options match `Blendend.Canvas.Stroke.path/3`.
  """
  defmacro arc(cx, cy, rx, ry, start_angle, sweep_angle, opts \\ []) do
    quote bind_quoted: [
            cx: cx,
            cy: cy,
            rx: rx,
            ry: ry,
            start_angle: start_angle,
            sweep_angle: sweep_angle,
            opts: opts
          ] do
      Blendend.Draw.__shape__(
        :arc,
        [cx, cy, rx, ry, start_angle, sweep_angle],
        opts
      )
    end
  end

  @doc """
  Translates the current canvas transform by `{tx, ty}` (pixels).
  """
  defmacro translate(tx, ty) do
    quote bind_quoted: [tx: tx, ty: ty] do
      c = get_canvas()
      Blendend.Canvas.translate(c, tx, ty)
    end
  end

  @doc """
  Translates temporarily the current canvas transform by `{tx, ty}` (pixels) for the duration of the block.
  """
  defmacro translate(tx, ty, do: body) do
    quote do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.translate(c, unquote(tx), unquote(ty))

      try do
        unquote(body)
      after
        :ok = Blendend.Canvas.restore_state(c)
      end

      c
    end
  end

  @doc """
  Post-Translates temporarily the current canvas transform by `{tx, ty}` (pixels) for the duration of the block.
  """
  defmacro post_translate(tx, ty, do: body) do
    quote do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.post_translate(c, unquote(tx), unquote(ty))

      try do
        unquote(body)
      after
        :ok = Blendend.Canvas.restore_state(c)
      end

      c
    end
  end

  @doc """
  Scales the current canvas uniformly by `s` (both axes).
  """
  defmacro scale(sx, sy) do
    quote bind_quoted: [sx: sx, sy: sy] do
      c = get_canvas()
      Blendend.Canvas.scale(c, sx, sy)
    end
  end

  @doc """
  Scales temporarily the current canvas transform by `{sx, sy}` for the duration of the block.
  """

  defmacro scale(sx, sy, do: body) do
    quote do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.scale(c, unquote(sx), unquote(sy))

      try do
        unquote(body)
      after
        :ok = Blendend.Canvas.restore_state(c)
      end

      c
    end
  end

  @doc """
  Skews the current canvas transform by `{sx, sy}` (radians) relative to the x/y axes.
  """
  defmacro skew(kx, ky) do
    quote bind_quoted: [kx: kx, ky: ky] do
      c = get_canvas()
      Blendend.Canvas.skew(c, kx, ky)
    end
  end

  @doc """
  Skews temporarily the current canvas by `s` on both axes (radians) for the duration of the block.
  """
  defmacro skew(kx, ky, do: body) do
    quote do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.skew(c, unquote(kx), unquote(ky))

      try do
        unquote(body)
      after
        :ok = Blendend.Canvas.restore_state(c)
      end

      c
    end
  end

  @doc """
  Rotates the current canvas transform by `angle` (radians) around the origin.
  """
  defmacro rotate(angle) do
    quote bind_quoted: [angle: angle] do
      c = get_canvas()
      Blendend.Canvas.rotate(c, angle)
    end
  end

  @doc """
  Rotates the current canvas transform by `angle` (radians) around `{cx, cy}`.
  """
  defmacro rotate(angle, cx, cy) do
    quote bind_quoted: [angle: angle, cx: cx, cy: cy] do
      c = get_canvas()
      Blendend.Canvas.rotate_at(c, angle, cx, cy)
    end
  end

  @doc """
  Rotates temporarily the current canvas `angle` (radians)  around `{cx, cy}` while evaluating `do` block.
  """
  defmacro rotate(angle, do: body) do
    quote do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.rotate(c, unquote(angle))

      try do
        unquote(body)
      after
        :ok = Blendend.Canvas.restore_state(c)
      end

      c
    end
  end

  @doc """
  Rotates temporarily the current canvas `angle` (radians) around `{cx, cy}` while evaluating `do` block.
  """
  defmacro rotate(angle, cx, cy, do: body) do
    quote do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.rotate_at(c, unquote(angle), unquote(cx), unquote(cy))

      try do
        unquote(body)
      after
        :ok = Blendend.Canvas.restore_state(c)
      end

      c
    end
  end

  @doc """
  Post-Rotates temporarily the current canvas `angle` (radians)  around `{cx, cy}` while evaluating `do` block.
  """
  defmacro post_rotate(angle, do: body) do
    quote do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.post_rotate(c, unquote(angle))

      try do
        unquote(body)
      after
        :ok = Blendend.Canvas.restore_state(c)
      end

      c
    end
  end

  @doc """
  Post-Rotates temporarily the current canvas `angle` (radians) around `{cx, cy}` while evaluating `do` block.
  """
  defmacro post_rotate(angle, cx, cy, do: body) do
    quote do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.post_rotate_at(c, unquote(angle), unquote(cx), unquote(cy))

      try do
        unquote(body)
      after
        :ok = Blendend.Canvas.restore_state(c)
      end

      c
    end
  end

  @doc """
  Temporarily applies a transform to the current canvas while evaluating `do` block.
  That means any transform applied inside is rolled back when the block exits.
  This macro mirrors the typical *save / apply / restore* pattern:

    * saves the current context state (`Canvas.save_state/1`),
    * applies the given matrix via `Canvas.apply_transform/2`,
    * executes the body,
    * restores the previous state with `Canvas.restore/1`, even if an error
      is raised inside the block.

  `matrix_ast` should evaluate to a `Blendend.Matrix2D` value.

  ## Examples

       m = Blendend.Matrix2D.identity!()
           |> Blendend.Matrix2D.rotate!(:math.pi() / 4)

       with_transform m do
         text f, 80, 80, "Elixir is awesome!"
       end

  """
  defmacro with_transform(matrix_ast, do: body) do
    quote do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.apply_transform(c, unquote(matrix_ast))

      try do
        unquote(body)
      after
        :ok = Blendend.Canvas.restore_state(c)
      end
    end
  end

  @doc """
  Temporarily clip drawing to the rectangle `{x, y, w, h}` while executing the block.

  This wraps `Canvas.save_state/1`, `Canvas.Clip.to_rect/5`, then restores state
  after the block (even if it raises).
  """
  defmacro with_clip(x, y, w, h, do: body) do
    quote bind_quoted: [x: x, y: y, w: w, h: h, body: body] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.save_state(c)
      :ok = Blendend.Canvas.Clip.to_rect(c, x, y, w, h)

      try do
        body
      after
        :ok = Blendend.Canvas.restore_state(c)
      end
    end
  end

  # ------------------------------------------------------------------
  # Effects
  # ------------------------------------------------------------------

  @doc """
  Blur a path and composite it onto the current canvas.
  Wraps `Blendend.Effects.blur_path/4`; accepts blur options (e.g. `:radius`, `:spread`) and style overrides.
  """
  def blur_path(path, sigma, opts \\ []) do
    canvas = get_canvas()
    Blendend.Effects.blur_path!(canvas, path, sigma, opts)
    canvas
  end

  @doc "Apply a soft shadow (blur + offset) for a path on the current canvas."
  def shadow_path(path, dx, dy, sigma, opts \\ []) do
    canvas = get_canvas()
    Blendend.Effects.shadow_path!(canvas, path, dx, dy, sigma, opts)
    canvas
  end
end
