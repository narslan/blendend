defmodule Blendend.Text.Layout do
  @moduledoc """
  Small helpers for measuring text and computing positions for labels/icons.
  """

  alias Blendend.Text.{GlyphBuffer, Font}

  @doc """
  Measures a UTF-8 `string` for the given `font`.

  Returns `{advance_x, {x0, y0, x1, y1}}` where the box is the text's
  bounding box in font space, relative to the text baseline at (0, 0).
  """
  @spec measure(Font.t(), String.t()) :: {float(), {float(), float(), float(), float()}}
  def measure(font, string) do
    gb =
      GlyphBuffer.new!()
      |> GlyphBuffer.set_utf8_text!(string)
      |> Font.shape!(font)

    Font.get_text_metrics!(font, gb)
  end

  @doc """
  Returns a reasonable line height for `font`.

  Uses ascent + descent + line_gap from `Font.metrics!/1`.
  """
  @spec line_height(Font.t(), number()) :: float()
  def line_height(font, scale \\ 1.0) do
    m = Font.metrics!(font)
    (m["ascent"] + m["descent"] + m["line_gap"]) * scale * 1.0
  end
end
