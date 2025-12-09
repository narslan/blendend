defmodule Blendend.Text.Layout do
  @moduledoc """
  Small helpers for measuring text and computing positions of a text.
  """

  alias Blendend.Text.{GlyphBuffer, Font}

  @doc """
  Measures the layout metrics for a UTF-8 `string` rendered with `font`
  (advance vector and tight bounding box).

  Returns a map of text metrics with the following keys:

    * `"advance_x"` / `"advance_y"` – total pen movement after drawing the run
    * `"bbox_x0"` / `"bbox_y0"` – lower-left corner of the run's tight bounding box
    * `"bbox_x1"` / `"bbox_y1"` – upper-right corner of the run's tight bounding box

  The bounding box is expressed in user space, relative to the text baseline at `{0, 0}`.

  ## Examples

      alias Blendend.Text.{Face, Font, Layout}

      face = Face.load!("priv/fonts/Alegreya-Regular.otf")
      font = Font.create!(face, 12)
      Layout.measure(font, "abc")
      %{
        "advance_x" => 16.776,
        "advance_y" => -0.0,
        "bbox_x0" => 0.492,
        "bbox_x1" => 16.332,
        "bbox_y0" => -0.0,
        "bbox_y1" => -0.0
      }
  """
  @spec measure(Font.t(), String.t()) :: map()
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
