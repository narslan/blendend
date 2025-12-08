defmodule Blendend.Text do
  @moduledoc """
  High-level text helpers for Blendend.

  This module is surface over the lower-level text modules:

    * `Blendend.Text.Face`        – load and inspect font faces
    * `Blendend.Text.Font`        – create fonts, metrics, shaping
    * `Blendend.Text.GlyphBuffer` – input text / shaped glyph storage
    * `Blendend.Text.GlyphRun`    – view for shaped glyphs, ready to draw

  For the most direct "just draw this UTF-8 text" call, see
  `Blendend.Canvas.Fill.utf8_text/6` and `Blendend.Canvas.Stroke.utf8_text/6`.
  """

  alias Blendend.Text.{Face, Font, GlyphBuffer, GlyphRun}

  @opaque face :: Face.t()
  @opaque font :: Font.t()
  @opaque glyph_run :: GlyphRun.t()

  @doc """
  Shapes `text` with the given `font` and returns a `GlyphRun`.

  Internally this:

    * allocates a `GlyphBuffer`
    * sets its UTF-8 text
    * calls the underlying shaping engine via `Font.shape/2`
    * returns the resulting `GlyphRun`

  Use this when you want to inspect or reuse the shaped glyphs.
  """
  @spec shape(font(), String.t()) :: glyph_run()
  def shape(font, text) do
    {:ok, gb} = GlyphBuffer.new()

    with :ok <- GlyphBuffer.set_utf8_text(gb, text),
         :ok <- Font.shape(font, gb) do
      {:ok, GlyphRun.new(gb)}
    end
  end

  @doc """
  Computes text metrics for the given `text` and `font`.

  Internally this uses a glyph buffer and `Font.get_text_metrics/2`.
  .
  """
  @spec metrics(font(), String.t()) :: term() | {:error, term()}
  def metrics(font, text) do
    gb = GlyphBuffer.new()

    with :ok <- GlyphBuffer.set_utf8_text(gb, text) do
      Font.get_text_metrics(font, gb)
    end
  end
end
