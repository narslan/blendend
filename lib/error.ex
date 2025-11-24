defmodule Blendend.Error do
  @moduledoc false
  defexception [:message, :context, :reason]

  def new(context, reason) do
    %__MODULE__{
      context: context,
      reason: reason,
      message: "Blendend #{context} failed: #{inspect(reason)}"
    }
  end
end
