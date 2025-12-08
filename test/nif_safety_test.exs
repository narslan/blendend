defmodule Blendend.NifSafetyTest do
  use ExUnit.Case, async: false

  alias Blendend.{Canvas, Text}

  @tag :safety
  test "rendering repeatedly does not crash or leak badly" do
    # Take a baseline memory snapshot
    :erlang.garbage_collect(self())
    mem_before = :erlang.memory(:total)

    # Hammer a NIF call many times
    {:ok, face} = Text.Face.load("priv/fonts/Alegreya-Regular.otf")
    {:ok, font} = Text.Font.create(face, 32.0)

    for _ <- 1..1_000 do
      {:ok, canvas} = Canvas.new(400, 200)

      :ok =
        Canvas.clear(canvas, fill: Blendend.Style.Color.rgb!(0x4C, 0x48, 0x45))

      :ok =
        Canvas.Fill.utf8_text(
          canvas,
          font,
          32.0,
          100.0,
          "Hamburgefonts 0123456789",
          fill: Blendend.Style.Color.rgb!(230, 230, 230, 255)
        )

      {:ok, _} = Canvas.to_png_base64(canvas)
    end

    :erlang.garbage_collect(self())
    mem_after = :erlang.memory(:total)

    assert mem_after < mem_before * 2
  end

  @tag :safety
  test "NIFs are stable under concurrency" do
    {:ok, face} = Text.Face.load("priv/fonts/Alegreya-Regular.otf")
    {:ok, font} = Text.Font.create(face, 32.0)

    job = fn ->
      {:ok, canvas} = Canvas.new(400, 200)

      :ok =
        Canvas.clear(canvas, fill: Blendend.Style.Color.rgb!(0x4C, 0x48, 0x45))

      :ok =
        Canvas.Fill.utf8_text(
          canvas,
          font,
          32.0,
          100.0,
          "Hello world!",
          fill: Blendend.Style.Color.rgb!(100, 200, 255, 255)
        )

      {:ok, _} = Canvas.to_png_base64(canvas)
      :ok
    end

    tasks =
      for _ <- 1..(System.schedulers_online() * 2) do
        Task.async(fn ->
          for _ <- 1..200 do
            job.()
          end
        end)
      end

    Enum.each(tasks, &Task.await(&1, 60_000))
  end

  @tag :safety
  test "glyph shaping stays under 5ms per call" do
    {:ok, face} = Blendend.Text.Face.load("priv/fonts/Alegreya-Regular.otf")
    {:ok, font} = Blendend.Text.Font.create(face, 32.0)

    text = "Hamburgefonts 0123456789"

    gb0 =
      Blendend.Text.GlyphBuffer.new!()
      |> Blendend.Text.GlyphBuffer.set_utf8_text!(text)

    Blendend.Text.Font.shape!(gb0, font)

    times_us =
      for _ <- 1..100 do
        gb =
          Blendend.Text.GlyphBuffer.new!()
          |> Blendend.Text.GlyphBuffer.set_utf8_text!(text)

        {t, _} =
          :timer.tc(fn ->
            Blendend.Text.Font.shape!(gb, font)
          end)

        t
      end

    max_us = Enum.max(times_us)
    assert max_us < 6_000
  end
end
