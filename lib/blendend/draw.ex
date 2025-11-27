defmodule Blendend.Draw do
  @moduledoc """
  DSL for writing Blendend drawings as Elixir code.

  You typically `use` this module in a script, IEx, or a web playground and
  then drive everything through `draw/2` or `draw/3`:

      use Blendend.Draw

      draw 400, 300 do
        rect 40.0, 40.0, 320.0, 220.0, fill: rgb(255, 255, 255)
      end

  ## What `draw/...` does

  A `draw/2` or `draw/3` call:

    * creates a new `Blendend.Canvas` of the given size
    * stores it as the *current* canvas in the calling process,
    * executes a block, where helpers like `rect/...`, `circle/...`, `text...`
    * finally encodes the image via `Blendend.Canvas.to_png_base64/1`.

  The return value is whatever `Blendend.Canvas.to_png_base64/1` returns
  (usually `{:ok, base64}`), which makes it easy to give to a web UI:

      {:ok, b64} =
        draw 400, 300 do
          # ...
        end

      "data:image/png;base64," <> b64
      # usable as <img src="data:image/png;base64,\#{b64}">

  This makes the `Blendend.Draw` especially convenient for LiveView / WebSocket /
  HTTP-streaming setups where we regenerate PNGs on demand.


  ## Process-local state

  The current canvas is stored in the process dictionary.
  Nested `draw/2` in the same process will overwrite the previous state.
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
  def put_canvas(c), do: Process.put(@canvas_key, c)

  def get_canvas() do
    Process.get(@canvas_key) ||
      raise "No active canvas. Use draw/3 first."
  end

  # ------------------------------------------------------------------
  # helpers: floatification
  # ------------------------------------------------------------------
  # numeric helpers
  def to_f(v) when is_integer(v), do: v * 1.0
  def to_f(v) when is_float(v), do: v
  def to_f(v), do: v

  # trig helpers (radian input)
  defmacro sin(angle) do
    quote do
      :math.sin(unquote(angle))
    end
  end

  defmacro cos(angle) do
    quote do
      :math.cos(unquote(angle))
    end
  end

  defmacro tan(angle) do
    quote do
      :math.tan(unquote(angle))
    end
  end

  defmacro atan2(y, x) do
    quote do
      :math.atan2(unquote(y), unquote(x))
    end
  end

  # defp to_f_list(list), do: Enum.map(list, &to_f/1)

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
  def classify_mode(opts) do
    stroke_val = Keyword.get(opts, :stroke_color) || Keyword.get(opts, :stroke)

    cond do
      stroke_val ->
        base_opts =
          opts
          |> Keyword.delete(:stroke_color)
          |> Keyword.delete(:stroke)

        {:stroke, Keyword.put(base_opts, :stroke, stroke_val)}

      true ->
        {:fill, opts}
    end
  end

  defmacro rgb(r, g, b, a \\ 255) do
    quote bind_quoted: [r: r, g: g, b: b, a: a] do
      Blendend.Style.Color.rgb!(r, g, b, a)
    end
  end

  defmacro rgb(:random) do
    quote do
      Blendend.Style.Color.random()
    end
  end

  defmacro hsv(h, s, v, a \\ 255) do
    quote bind_quoted: [h: h, s: s, v: v, a: a] do
      Blendend.Style.Color.hsv(h, s, v, a)
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

  def __drawsave__(w, h, file, fun) do
    {:ok, c} = Blendend.Canvas.new(w, h)
    put_canvas(c)
    Blendend.Canvas.clear(c)
    _ = fun.()
    Blendend.Canvas.save(c, file)
  end

  defmacro clear(opts) do
    quote bind_quoted: [opts: opts] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.clear(c, opts)
    end
  end

  defmacro comp_op(op) do
    quote bind_quoted: [op: op] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.set_comp_op(c, op)
    end
  end

  defmacro global_alpha(alpha) do
    quote bind_quoted: [alpha: alpha] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.set_global_alpha(c, alpha)
    end
  end

  defmacro style_alpha(slot, alpha) do
    quote bind_quoted: [slot: slot, alpha: alpha] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.set_style_alpha(c, slot, alpha)
    end
  end

  defmacro fill_rule(rule) do
    quote bind_quoted: [rule: rule] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.set_fill_rule(c, rule)
    end
  end

  defmacro set_stroke_style(style) do
    quote bind_quoted: [style: style] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.set_stroke_style(c, style)
    end
  end

  defmacro set_stroke_width(width) do
    quote bind_quoted: [width: width] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.set_stroke_width(c, width)
    end
  end

  defmacro set_stroke_join(join) do
    quote bind_quoted: [join: join] do
      c = Blendend.Draw.get_canvas()
      :ok = Blendend.Canvas.set_stroke_join(c, join)
    end
  end

  defmacro load_font(face, size) do
    quote bind_quoted: [face: face, size: size] do
      face = Blendend.Text.Face.load!(face)
      Blendend.Text.Font.create!(face, size)
    end
  end

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

  def __shape__(:fill_path, p, opts) do
    c = get_canvas()

    Blendend.Canvas.Fill.path(c, p, opts)
    :ok
  end

  def __shape__(:stroke_path, p, opts) do
    c = get_canvas()

    Blendend.Canvas.Stroke.path(c, p, opts)
    :ok
  end

  # BOX ======================================================================

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

  # polyline is stroke-only (no fill variant)
  def __shape__(:polyline, [points], opts) do
    c = get_canvas()
    points = to_f_points(points)
    Blendend.Canvas.Stroke.polyline(c, points, opts)
    :ok
  end

  # BOX ARRAY ================================================================

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

  # line is stroke-only
  def __shape__(:line, [x0, y0, x1, y1], opts) do
    c = get_canvas()

    Blendend.Canvas.Stroke.line(c, x0, y0, x1, y1, opts)
    :ok
  end

  # ARC ======================================================================

  # arc is stroke-only
  def __shape__(:arc, [cx, cy, rx, ry, start_angle, sweep_angle], opts) do
    c = get_canvas()

    Blendend.Canvas.Stroke.arc(c, cx, cy, rx, ry, start_angle, sweep_angle, opts)
    :ok
  end

  # path fill / stroke
  defmacro fill_path(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      Blendend.Draw.__shape__(:fill_path, path, opts)
    end
  end

  defmacro stroke_path(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      Blendend.Draw.__shape__(:stroke_path, path, opts)
    end
  end

  # box (uses fill_box / stroke_box)
  defmacro box(x0, y0, x1, y1, opts \\ []) do
    quote bind_quoted: [x0: x0, y0: y0, x1: x1, y1: y1, opts: opts] do
      Blendend.Draw.__shape__(:box, [x0, y0, x1, y1], opts)
    end
  end

  # rect (fill_rect / stroke_rect)
  defmacro rect(x, y, w, h, opts \\ []) do
    quote bind_quoted: [x: x, y: y, w: w, h: h, opts: opts] do
      Blendend.Draw.__shape__(:rect, [x, y, w, h], opts)
    end
  end

  # circle (fill_circle / stroke_circle)
  defmacro circle(cx, cy, r, opts \\ []) do
    quote bind_quoted: [cx: cx, cy: cy, r: r, opts: opts] do
      Blendend.Draw.__shape__(:circle, [cx, cy, r], opts)
    end
  end

  # ellipse (fill_ellipse / stroke_ellipse)
  defmacro ellipse(cx, cy, rx, ry, opts \\ []) do
    quote bind_quoted: [cx: cx, cy: cy, rx: rx, ry: ry, opts: opts] do
      Blendend.Draw.__shape__(:ellipse, [cx, cy, rx, ry], opts)
    end
  end

  # round rect (fill_round_rect / stroke_round_rect)
  defmacro round_rect(x, y, w, h, rx, ry, opts \\ []) do
    quote bind_quoted: [x: x, y: y, w: w, h: h, rx: rx, ry: ry, opts: opts] do
      Blendend.Draw.__shape__(:round_rect, [x, y, w, h, rx, ry], opts)
    end
  end

  # chord (fill_chord / stroke_chord)
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

  # pie (fill_pie / stroke_pie)
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

  # triangle (fill_triangle / stroke_triangle)
  # equilateral triangle by center + side length (pointing up)
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

  defmacro triangle(x0, y0, x1, y1, x2, y2, opts \\ []) do
    quote bind_quoted: [x0: x0, y0: y0, x1: x1, y1: y1, x2: x2, y2: y2, opts: opts] do
      Blendend.Draw.__shape__(:triangle, [x0, y0, x1, y1, x2, y2], opts)
    end
  end

  # polygon (fill_polygon / stroke_polygon)
  defmacro polygon(points, opts \\ []) do
    quote bind_quoted: [points: points, opts: opts] do
      Blendend.Draw.__shape__(:polygon, [points], opts)
    end
  end

  # polyline (stroke_polyline only)
  defmacro polyline(points, opts \\ []) do
    quote bind_quoted: [points: points, opts: opts] do
      Blendend.Draw.__shape__(:polyline, [points], opts)
    end
  end

  # box_array (fill_box_array / stroke_box_array)
  defmacro box_array(boxes, opts \\ []) do
    quote bind_quoted: [boxes: boxes, opts: opts] do
      Blendend.Draw.__shape__(:box_array, [boxes], opts)
    end
  end

  # rect_array (fill_rect_array / stroke_rect_array)
  defmacro rect_array(rects, opts \\ []) do
    quote bind_quoted: [rects: rects, opts: opts] do
      Blendend.Draw.__shape__(:rect_array, [rects], opts)
    end
  end

  # line (stroke_line only)
  defmacro line(x0, y0, x1, y1, opts \\ []) do
    quote bind_quoted: [x0: x0, y0: y0, x1: x1, y1: y1, opts: opts] do
      Blendend.Draw.__shape__(:line, [x0, y0, x1, y1], opts)
    end
  end

  # arc (stroke_arc only)
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

  # translate (canvas only)
  defmacro translate(tx, ty) do
    quote bind_quoted: [tx: tx, ty: ty] do
      c = get_canvas()
      Blendend.Canvas.translate(c, tx, ty)
    end
  end

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

  # scale (canvas only)
  defmacro scale(sx, sy) do
    quote bind_quoted: [sx: sx, sy: sy] do
      c = get_canvas()
      Blendend.Canvas.scale(c, sx, sy)
    end
  end

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

  # skew (canvas only)
  defmacro skew(kx, ky) do
    quote bind_quoted: [kx: kx, ky: ky] do
      c = get_canvas()
      Blendend.Canvas.skew(c, kx, ky)
    end
  end

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

  # rotate (canvas only)
  defmacro rotate(angle) do
    quote bind_quoted: [angle: angle] do
      c = get_canvas()
      Blendend.Canvas.rotate(c, angle)
    end
  end

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
  Temporarily applies a transform to the current canvas while evaluating `do` block.

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

  # ------------------------------------------------------------------
  # Effects
  # ------------------------------------------------------------------

  @doc "Blur a path and composite it onto the current canvas."
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
