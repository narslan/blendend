defmodule Blendend.Matrix2DTest do
  use ExUnit.Case, async: true
  alias Blendend.Matrix2D, as: M

  # simple float compare with tolerance
  defp assert_floats_close(list1, list2, eps \\ 1.0e-9) do
    Enum.zip(list1, list2)
    |> Enum.each(fn {a, b} ->
      assert abs(a - b) <= eps, "expected #{a} ≈ #{b}"
    end)
  end

  test "new/1 rejects invalid lists" do
    # too short
    assert {:error, _} = M.new([1, 2, 3])
    # too long
    assert {:error, _} = M.new([1, 2, 3, 4, 5, 6, 7])
    assert {:error, _} = M.new([:a, 0, 0, 1, 0, 0])
  end

  test "translate from identity" do
    m0 = M.identity!()
    m1 = M.translate!(m0, 10.0, 5.0)

    # original untouched
    assert_floats_close(M.to_list!(m0), [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])

    # translated copy
    assert_floats_close(M.to_list!(m1), [1.0, 0.0, 0.0, 1.0, 10.0, 5.0])
  end

  test "scale from identity" do
    m0 = M.identity!()
    m1 = M.scale!(m0, 2.0, 3.0)

    assert_floats_close(M.to_list!(m0), [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])
    assert_floats_close(M.to_list!(m1), [2.0, 0.0, 0.0, 3.0, 0.0, 0.0])
  end

  test "scale then translate matches using compose" do
    # chain using the high-level helpers
    m =
      M.identity!()
      |> M.scale!(2.0, 3.0)
      |> M.translate!(10.0, 5.0)

    # build the same transform explicitly via compose
    s = M.identity!() |> M.scale!(2.0, 3.0)
    t = M.identity!() |> M.translate!(10.0, 5.0)

    expected =
      M.identity!()
      |> M.compose!(s)
      |> M.compose!(t)

    assert_floats_close(M.to_list!(m), M.to_list!(expected))
  end

  test "compose!/2 does not mutate inputs" do
    a = M.scale!(M.identity!(), 2.0, 2.0)
    b = M.translate!(M.identity!(), 5.0, -3.0)

    _ab = M.compose!(a, b)

    assert_floats_close(M.to_list!(a), [2.0, 0.0, 0.0, 2.0, 0.0, 0.0])
    assert_floats_close(M.to_list!(b), [1.0, 0.0, 0.0, 1.0, 5.0, -3.0])
  end

  test "rotate 90 degrees" do
    m0 = M.identity!()
    m1 = M.rotate!(m0, :math.pi() / 2)

    assert_floats_close(M.to_list!(m0), [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])

    [m00, m01, m10, m11, tx, ty] = M.to_list!(m1)

    assert_in_delta m00, 0.0, 1.0e-9
    assert_in_delta m01, 1.0, 1.0e-9
    assert_in_delta m10, -1.0, 1.0e-9
    assert_in_delta m11, 0.0, 1.0e-9
    assert_in_delta tx, 0.0, 1.0e-9
    assert_in_delta ty, 0.0, 1.0e-9
  end

  test "rotation additivity" do
    a = M.rotate!(M.identity!(), :math.pi() / 4)
    b = M.rotate!(M.identity!(), :math.pi() / 6)
    ab = M.compose!(a, b) |> M.to_list!()
    sum = M.rotate!(M.identity!(), :math.pi() * (1 / 4 + 1 / 6)) |> M.to_list!()
    assert assert_floats_close(ab, sum)
  end

  test "skew with zero is identity" do
    m =
      M.identity!()
      |> M.skew!(0.0, 0.0)

    assert_floats_close(M.to_list!(m), [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])
  end

  test "skew is functional and does not introduce translation from identity" do
    m0 = M.identity!()
    m1 = M.skew!(m0, 0.3, -0.2)

    assert_floats_close(M.to_list!(m0), [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])

    [_, _, _, _, tx, ty] = M.to_list!(m1)
    assert_floats_close([tx, ty], [0.0, 0.0])

    refute M.to_list!(m1) == [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
  end
end
