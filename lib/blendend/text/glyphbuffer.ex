defmodule Blendend.Text.GlyphBuffer do
  @moduledoc """
  A glyph buffer holds input text (UTF-8) and, after shaping, the glyph
  IDs / clusters / positions produced by a font.

  We normally don't draw directly from a `GlyphBuffer`; we turn it into a
  `GlyphRun` first.
  """

  @opaque t :: reference()

  alias Blendend.Native
  alias Blendend.Error

  @doc """
  Allocates an empty glyph buffer.

  On success, returns `{:ok, gb}`, where `gb` is an opaque glyph-buffer
  resource.

  On failure, returns `{:error, reason}`.
  """
  @spec new() :: {:ok, t()} | {:error, term()}
  def new, do: Native.glyph_buffer_new()

  @doc """
  Same as `new/0`, but returns the glyph buffer directly.

  On success, returns the buffer.

  On failure, raises `Blendend.Error`.
  """
  @spec new!() :: t()
  def new! do
    case new() do
      {:ok, gb} -> gb
      {:error, reason} -> raise Error.new(:glyph_buffer_new, reason)
    end
  end

  @doc """
  Sets the UTF-8 text of the glyph buffer.

  This only stores the text; it does not perform shaping. To shape
  the buffer we need to call `Blendend.Text.Font.shape/2`.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}` (for example if the buffer is
  invalid or the text cannot be stored).
  """
  @spec set_utf8_text(t(), String.t()) :: :ok | {:error, term()}
  def set_utf8_text(gb, text), do: Native.glyph_buffer_set_utf8_text(gb, text)

  @doc """
  Same as `set_utf8_text/2`, but returns the glyph buffer directly.

  On success, returns the same `gb`.

  On failure, raises `Blendend.Error`.

  Examples: 
      gb =
        GlyphBuffer.new!()
        |> GlyphBuffer.set_utf8_text!("Hello")
        |> Font.shape!(font)
  """
  @spec set_utf8_text!(t(), String.t()) :: t()
  def set_utf8_text!(gb, text) do
    case set_utf8_text(gb, text) do
      :ok -> gb
      {:error, reason} -> raise Error.new(:glyph_buffer_set_utf8_text, reason)
    end
  end
end
