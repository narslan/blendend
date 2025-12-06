defmodule Blendend.Text.Face do
  @moduledoc """
  A face represents a loaded font family from a TTF/OTF file.
  Typical workflow looks like:

    * load a face from disk,
    * create a `Blendend.Text.Font` from it for actual drawing.
    * inspect its metadata / metrics / coverage.
  Example:

      alias Blendend.Text.{Face, Font}

      face  = Face.load!("priv/fonts/Alegreya-Regular.otf")
      info  = Face.info!(face)
      names = Face.names!(face)

      font  = Font.create!(face, 48.0)
  """

  alias Blendend.Native
  alias Blendend.Error

  @opaque t :: reference()

  @doc """
  Loads a font face from `path`.

  On success, returns `{:ok, face}`, where `face` is an opaque NIF resource.

  On failure, returns `{:error, reason}`.
  """
  @spec load(String.t()) :: {:ok, t()} | {:error, term()}
  def load(path) when is_binary(path) do
    with {:ok, bin} <- File.read(path) |> map_file_error(path),
         {:ok, img} <- Native.face_load(bin) do
      {:ok, img}
    end
  end

  @doc """
  Same as `load/1`, but raises on failure.

  On success, returns the face.

  On failure, raises `Blendend.Error`.
  """
  @spec load!(binary()) :: t()
  def load!(path) do
    case load(path) do
      {:ok, face} -> face
      {:error, reason} -> raise Error.new(:face_load, reason)
    end
  end

  defp map_file_error({:ok, bin}, _path), do: {:ok, bin}
  defp map_file_error({:error, :enoent}, path), do: {:error, {:enoent, path}}
  defp map_file_error({:error, reason}, _path), do: {:error, reason}

  @doc """
  Returns design-space metrics for the face.

  On success, returns `{:ok, map}`.

  On failure, returns `{:error, reason}`.

  Examples: 
      
      alias Blendend.Text.Face
      {:ok, face}  = Face.load("priv/fonts/Alegreya-Regular.otf")
      Face.design_metrics!(face)
      > %{
        "ascent" => 1016,
        "cap_height" => 637,
        "descent" => 345,
        "h_min_lsb" => -395,
        "h_min_tsb" => -214,
        "line_gap" => 0,
        "units_per_em" => 1000,
        "v_ascent" => 1016,
        "v_descent" => 345,
        "x_height" => 452
        }
  """
  @spec design_metrics(t()) :: {:ok, map()} | {:error, term()}
  def design_metrics(face), do: Native.face_design_metrics(face)

  @doc """
  Same as `design_metrics/1`, but returns the metrics map directly.

  On success, returns map.

  On failure, raises `Blendend.Error`.
  """
  @spec design_metrics!(t()) :: map()
  def design_metrics!(face) do
    case design_metrics(face) do
      {:ok, map} -> map
      {:error, reason} -> raise Error.new(:face_design_metrics, reason)
    end
  end

  @doc """
  Returns the list of OpenType feature tags supported by this face.

  Each tag is a 4-character string (e.g. `"kern"`, `"liga"`).

  On success, returns `{:ok, tags}`.

  On failure, returns `{:error, reason}`.
  """
  @spec feature_tags(t()) :: {:ok, list()} | {:error, term()}
  def feature_tags(face), do: Native.face_get_feature_tags(face)

  @doc """
  Same as `feature_tags/1`, but returns the tag list directly.

  On success, returns `tags`.

  On failure, raises `Blendend.Error`.


  Examples: 

    face  = Face.load!("priv/fonts/Alegreya-Regular.otf")
    Face.feature_tags!(face)
    ["tnum", "sups", "subs", ...]
  """
  @spec feature_tags!(t()) :: list()
  def feature_tags!(face) do
    case feature_tags(face) do
      {:ok, tags} -> tags
      {:error, reason} -> raise Error.new(:face_get_feature_tags, reason)
    end
  end
end
