defmodule Klime.EventType do
  @moduledoc """
  Event types supported by the API.
  """

  @track "track"
  @identify "identify"
  @group "group"

  def track, do: @track
  def identify, do: @identify
  def group, do: @group
end

defmodule Klime.Event do
  @moduledoc """
  Represents a single event to be sent to the Klime API.

  Events are created with auto-generated `message_id` (UUID) and `timestamp` (ISO 8601).
  """

  import Bitwise

  alias Klime.EventContext

  defstruct [
    :type,
    :message_id,
    :timestamp,
    :event,
    :user_id,
    :group_id,
    :properties,
    :traits,
    :context
  ]

  @type t :: %__MODULE__{
          type: String.t(),
          message_id: String.t(),
          timestamp: String.t(),
          event: String.t() | nil,
          user_id: String.t() | nil,
          group_id: String.t() | nil,
          properties: map() | nil,
          traits: map() | nil,
          context: EventContext.t() | nil
        }

  @doc """
  Creates a new Event struct with auto-generated message_id and timestamp.

  ## Options

    * `:event` - Event name (required for track events)
    * `:user_id` - User identifier
    * `:group_id` - Group identifier
    * `:properties` - Event properties (for track events)
    * `:traits` - User/group traits (for identify/group events)
    * `:context` - Event context with library info

  ## Examples

      iex> Klime.Event.new("track", event: "Button Clicked", user_id: "user_123")
      %Klime.Event{type: "track", event: "Button Clicked", user_id: "user_123", ...}

  """
  @spec new(String.t(), keyword()) :: t()
  def new(type, opts \\ []) do
    %__MODULE__{
      type: type,
      message_id: generate_uuid(),
      timestamp: generate_timestamp(),
      event: Keyword.get(opts, :event),
      user_id: Keyword.get(opts, :user_id),
      group_id: Keyword.get(opts, :group_id),
      properties: Keyword.get(opts, :properties),
      traits: Keyword.get(opts, :traits),
      context: Keyword.get(opts, :context)
    }
  end

  @doc """
  Converts an Event to a map with camelCase keys for JSON serialization.
  Only includes non-nil fields.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = event) do
    %{
      "type" => event.type,
      "messageId" => event.message_id,
      "timestamp" => event.timestamp
    }
    |> maybe_put("event", event.event)
    |> maybe_put("userId", event.user_id)
    |> maybe_put("groupId", event.group_id)
    |> maybe_put("properties", event.properties)
    |> maybe_put("traits", event.traits)
    |> maybe_put_context(event.context)
  end

  @doc """
  Converts an Event to JSON string.
  """
  @spec to_json(t()) :: String.t()
  def to_json(%__MODULE__{} = event) do
    event |> to_map() |> Jason.encode!()
  end

  @doc """
  Estimates the size of an event in bytes when serialized to JSON.
  """
  @spec estimate_size(t()) :: non_neg_integer()
  def estimate_size(%__MODULE__{} = event) do
    byte_size(to_json(event))
  end

  # Generate a UUID v4
  defp generate_uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    # Set version (4) and variant (2) bits
    c = (c &&& 0x0FFF) ||| 0x4000
    d = (d &&& 0x3FFF) ||| 0x8000

    :io_lib.format(
      "~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
      [a, b, c, d, e]
    )
    |> IO.iodata_to_binary()
  end

  # Generate an ISO 8601 timestamp with milliseconds
  defp generate_timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, value) when value == %{}, do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_context(map, nil), do: map

  defp maybe_put_context(map, %EventContext{} = context) do
    context_map = EventContext.to_map(context)

    if map_size(context_map) > 0 do
      Map.put(map, "context", context_map)
    else
      map
    end
  end
end
