defmodule Blendend.DrawRgbTest do
  use ExUnit.Case, async: true
  use Blendend.Draw

  test "rgb/1 supports {r, g, b} tuples" do
    color = rgb({200, 200, 255})
    assert {200, 200, 255, 255} == Blendend.Style.Color.components!(color)
  end

  test "rgb/1 supports {r, g, b} tuple expressions" do
    tuple = {200, 200, 255}
    color = rgb(tuple)
    assert {200, 200, 255, 255} == Blendend.Style.Color.components!(color)
  end

  test "rgb/1 supports {r, g, b, a} tuples" do
    color = rgb({200, 200, 255, 128})
    assert {200, 200, 255, 128} == Blendend.Style.Color.components!(color)
  end
end
