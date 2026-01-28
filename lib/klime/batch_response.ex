defmodule Klime.ValidationError do
  @moduledoc """
  Represents a validation error for a single event in a batch response.
  """

  defstruct [:index, :message, :code]

  @type t :: %__MODULE__{
          index: integer(),
          message: String.t(),
          code: String.t()
        }

  @doc """
  Creates a ValidationError from a map (parsed from JSON response).
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      index: Map.get(map, "index", -1),
      message: Map.get(map, "message", ""),
      code: Map.get(map, "code", "")
    }
  end
end

defmodule Klime.BatchResponse do
  @moduledoc """
  Represents the response from the batch API endpoint.
  """

  alias Klime.ValidationError

  defstruct [:status, :accepted, :failed, :errors]

  @type t :: %__MODULE__{
          status: String.t(),
          accepted: non_neg_integer(),
          failed: non_neg_integer(),
          errors: [ValidationError.t()] | nil
        }

  @doc """
  Creates a BatchResponse from a map (parsed from JSON response).

  ## Examples

      iex> Klime.BatchResponse.from_map(%{"status" => "ok", "accepted" => 5, "failed" => 0})
      %Klime.BatchResponse{status: "ok", accepted: 5, failed: 0, errors: nil}

  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      status: Map.get(map, "status", "ok"),
      accepted: Map.get(map, "accepted", 0),
      failed: Map.get(map, "failed", 0),
      errors: parse_errors(Map.get(map, "errors"))
    }
  end

  defp parse_errors(nil), do: nil
  defp parse_errors(errors) when is_list(errors) do
    Enum.map(errors, &ValidationError.from_map/1)
  end
  defp parse_errors(_), do: nil

  @doc """
  Returns true if the batch was fully successful (no failures).
  """
  @spec success?(t()) :: boolean()
  def success?(%__MODULE__{failed: 0}), do: true
  def success?(%__MODULE__{}), do: false

  @doc """
  Returns true if the batch was partially successful (some failures).
  """
  @spec partial?(t()) :: boolean()
  def partial?(%__MODULE__{failed: failed}) when failed > 0, do: true
  def partial?(%__MODULE__{}), do: false
end
