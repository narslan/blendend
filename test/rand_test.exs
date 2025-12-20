defmodule Blendend.RandTest do
  use ExUnit.Case, async: true

  alias Blendend.Rand

  test "seed/1 resets the sequence" do
    assert :ok = Rand.seed(1234)
    values = Enum.map(1..5, fn _ -> Rand.normal() end)

    assert :ok = Rand.seed(1234)
    values_again = Enum.map(1..5, fn _ -> Rand.normal() end)

    assert values == values_again
  end

  test "normal_batch/1 returns float32 binary" do
    assert :ok = Rand.seed(42)
    assert {:ok, bin} = Rand.normal_batch(4)
    assert byte_size(bin) == 16

    values = for <<v::float-little-32 <- bin>>, do: v

    assert :ok = Rand.seed(42)
    values_again = Enum.map(1..4, fn _ -> Rand.normal() end)

    assert values == values_again
  end

  test "prefill/1 seeds the pool and keeps the sequence" do
    assert :ok = Rand.seed(99)
    assert :ok = Rand.prefill(3)

    pooled = [Rand.normal(), Rand.normal()]

    assert :ok = Rand.seed(99)
    assert {:ok, bin} = Rand.normal_batch(3)
    values = for <<v::float-little-32 <- bin>>, do: v

    assert pooled == Enum.take(values, 2)
  end
end
