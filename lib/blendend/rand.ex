defmodule Blendend.Rand do
  @moduledoc """
  Fast normal random numbers with a process-local pool.

  This module wraps a NIF-backed ziggurat sampler and keeps a per-process
  pool of float32 values to avoid per-sample NIF calls.

  The default seed is fixed for deterministic output; call `seed/1` to
  set your own seed in the current process.
  """

  alias Blendend.Native

  @pool_key :blendend_rand_pool
  @rng_key :blendend_rand_state
  @pool_size_key :blendend_rand_pool_size
  @default_batch 1024
  @default_seed 0x9E3779B97F4A7C15

  @doc """
  Seeds the process-local generator.

  This clears any cached pool so the next call starts from the new seed.
  """
  @spec seed(integer()) :: :ok | {:error, term()}
  def seed(seed) when is_integer(seed) do
    case Native.rand_new(seed) do
      {:ok, rng} ->
        Process.put(@rng_key, rng)
        Process.delete(@pool_key)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a standard normal variate (`mean=0`, `stddev=1`).
  """
  @spec normal() :: float()
  def normal do
    {bin, offset} = ensure_pool()
    <<_::binary-size(^offset), value::float-little-32, _::binary>> = bin
    Process.put(@pool_key, {bin, offset + 4})
    value
  end

  @doc """
  Returns a normal variate scaled by `sigma`.
  """
  @spec normal(number()) :: float()
  def normal(sigma) when is_number(sigma), do: normal() * sigma

  @doc """
  Returns a binary of `count` float32 values in little-endian order.
  """
  @spec normal_batch(non_neg_integer()) :: {:ok, binary()} | {:error, term()}
  def normal_batch(count) when is_integer(count) and count >= 0 do
    rng = current_rng()
    Process.delete(@pool_key)
    Native.rand_normal_batch(rng, count)
  end

  @doc """
  Sets the process-local pool size for refills.

  This clears any existing pool.
  """
  @spec pool_size(pos_integer()) :: :ok
  def pool_size(count) when is_integer(count) and count > 0 do
    Process.put(@pool_size_key, count)
    Process.delete(@pool_key)
    :ok
  end

  @doc """
  Prefills the process-local pool with `count` values.

  This also sets the pool size for subsequent refills.
  """
  @spec prefill(pos_integer()) :: :ok | {:error, term()}
  def prefill(count) when is_integer(count) and count > 0 do
    rng = current_rng()

    case Native.rand_normal_batch(rng, count) do
      {:ok, bin} ->
        Process.put(@pool_key, {bin, 0})
        Process.put(@pool_size_key, count)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ensure_pool do
    case Process.get(@pool_key) do
      {bin, offset} when is_binary(bin) and offset + 4 <= byte_size(bin) ->
        {bin, offset}

      _ ->
        refill_pool(pool_size())
    end
  end

  defp refill_pool(count) do
    rng = current_rng()

    case Native.rand_normal_batch(rng, count) do
      {:ok, bin} ->
        Process.put(@pool_key, {bin, 0})
        {bin, 0}

      {:error, reason} ->
        raise "rand_normal_batch failed: #{inspect(reason)}"
    end
  end

  defp current_rng do
    Process.get(@rng_key) || seed_default()
  end

  defp pool_size do
    Process.get(@pool_size_key, @default_batch)
  end

  defp seed_default do
    case Native.rand_new(@default_seed) do
      {:ok, rng} ->
        Process.put(@rng_key, rng)
        rng

      {:error, reason} ->
        raise "rand_new failed: #{inspect(reason)}"
    end
  end
end
