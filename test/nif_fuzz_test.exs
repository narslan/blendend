defmodule Blendend.NifFuzzTest do
  use ExUnit.Case, async: false

  alias Blendend.Text
  alias Blendend.Text.GlyphRun

  @tag :fuzz
  test "glyph buffer survives random strings" do
    :rand.seed(:exsss, {4, 5, 6})
    {:ok, face} = Text.Face.load("priv/fonts/Alegreya-Regular.otf")
    {:ok, font} = Text.Font.create(face, 32.0)

    for _ <- 1..500 do
      text =
        1..Enum.random(1..40)
        |> Enum.map(fn _ -> :rand.uniform(0x10FFFF) end)
        # skip surrogates
        |> Enum.reject(&(&1 in 0xD800..0xDFFF))
        |> Enum.map(&<<&1::utf8>>)
        |> Enum.join()

      gb =
        Text.GlyphBuffer.new!()
        |> Text.GlyphBuffer.set_utf8_text!(text)

      _ = Text.Font.shape!(gb, font)

      run = GlyphRun.new!(gb)
      info = GlyphRun.info!(run)
      assert info[:size] && info[:size] > 0
    end
  end
end
