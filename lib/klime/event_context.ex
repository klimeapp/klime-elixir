defmodule Klime.LibraryInfo do
  @moduledoc """
  Library information included in event context.
  """

  defstruct [:name, :version]

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t()
        }

  @doc """
  Creates a new LibraryInfo struct.
  """
  @spec new(String.t(), String.t()) :: t()
  def new(name, version) do
    %__MODULE__{name: name, version: version}
  end

  @doc """
  Converts LibraryInfo to a map with camelCase keys for JSON serialization.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = info) do
    %{
      "name" => info.name,
      "version" => info.version
    }
  end
end

defmodule Klime.EventContext do
  @moduledoc """
  Context information attached to events.
  """

  alias Klime.LibraryInfo

  defstruct [:library, :ip]

  @type t :: %__MODULE__{
          library: LibraryInfo.t() | nil,
          ip: String.t() | nil
        }

  @doc """
  Creates a new EventContext struct.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      library: Keyword.get(opts, :library),
      ip: Keyword.get(opts, :ip)
    }
  end

  @doc """
  Converts EventContext to a map with camelCase keys for JSON serialization.
  Only includes non-nil fields.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = context) do
    %{}
    |> maybe_put("library", context.library, &LibraryInfo.to_map/1)
    |> maybe_put_value("ip", context.ip)
  end

  defp maybe_put(map, _key, nil, _transform), do: map
  defp maybe_put(map, key, value, transform), do: Map.put(map, key, transform.(value))

  defp maybe_put_value(map, _key, nil), do: map
  defp maybe_put_value(map, key, value), do: Map.put(map, key, value)
end
