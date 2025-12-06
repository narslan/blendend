defmodule Blendend.Error do
  @moduledoc """
  Exception struct used by the `Blendend` API when bang functions fail.

  Errors carry a `:context` atom indicating the operation (e.g. `:path_add_arc`)
  and a `:reason` from the underlying NIF. 
  """
  defexception [:message, :context, :reason]

  def new(context, reason) do
    %__MODULE__{
      context: context,
      reason: reason,
      message: format_message(context, reason)
    }
  end

  defp format_message(context, {:enoent, path}),
    do: "blendend #{context} failed: file not found: #{path}"

  defp format_message(context, reason),
    do: "blendend #{context} failed: #{inspect(reason)}"
end
