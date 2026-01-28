defmodule Klime.EventTest do
  use ExUnit.Case, async: true

  alias Klime.{Event, EventType, EventContext, LibraryInfo}

  describe "EventType" do
    test "returns correct type constants" do
      assert EventType.track() == "track"
      assert EventType.identify() == "identify"
      assert EventType.group() == "group"
    end
  end

  describe "LibraryInfo" do
    test "creates new library info" do
      info = LibraryInfo.new("elixir-sdk", "1.0.0")
      assert info.name == "elixir-sdk"
      assert info.version == "1.0.0"
    end

    test "converts to map" do
      info = LibraryInfo.new("elixir-sdk", "1.0.0")
      map = LibraryInfo.to_map(info)

      assert map == %{"name" => "elixir-sdk", "version" => "1.0.0"}
    end
  end

  describe "EventContext" do
    test "creates empty context" do
      context = EventContext.new()
      assert context.library == nil
      assert context.ip == nil
    end

    test "creates context with library" do
      library = LibraryInfo.new("elixir-sdk", "1.0.0")
      context = EventContext.new(library: library)
      assert context.library == library
    end

    test "creates context with ip" do
      context = EventContext.new(ip: "192.168.1.1")
      assert context.ip == "192.168.1.1"
    end

    test "converts to map with library" do
      library = LibraryInfo.new("elixir-sdk", "1.0.0")
      context = EventContext.new(library: library)
      map = EventContext.to_map(context)

      assert map == %{
               "library" => %{"name" => "elixir-sdk", "version" => "1.0.0"}
             }
    end

    test "converts to map with ip" do
      context = EventContext.new(ip: "192.168.1.1")
      map = EventContext.to_map(context)

      assert map == %{"ip" => "192.168.1.1"}
    end

    test "converts empty context to empty map" do
      context = EventContext.new()
      map = EventContext.to_map(context)

      assert map == %{}
    end
  end

  describe "Event.new/2" do
    test "creates track event with auto-generated message_id and timestamp" do
      event = Event.new("track", event: "Button Clicked", user_id: "user_123")

      assert event.type == "track"
      assert event.event == "Button Clicked"
      assert event.user_id == "user_123"
      assert event.message_id != nil
      assert event.timestamp != nil
    end

    test "generates valid UUID v4 format" do
      event = Event.new("track", event: "Test")

      # UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      assert Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i, event.message_id)
    end

    test "generates ISO 8601 timestamp" do
      event = Event.new("track", event: "Test")

      # ISO 8601 format: 2025-01-15T10:30:00.000Z
      assert Regex.match?(~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, event.timestamp)
    end

    test "creates identify event" do
      event = Event.new("identify", user_id: "user_123", traits: %{email: "test@example.com"})

      assert event.type == "identify"
      assert event.user_id == "user_123"
      assert event.traits == %{email: "test@example.com"}
    end

    test "creates group event" do
      event = Event.new("group", group_id: "org_456", traits: %{name: "Acme"}, user_id: "user_123")

      assert event.type == "group"
      assert event.group_id == "org_456"
      assert event.user_id == "user_123"
      assert event.traits == %{name: "Acme"}
    end

    test "creates event with context" do
      library = LibraryInfo.new("elixir-sdk", "1.0.0")
      context = EventContext.new(library: library)
      event = Event.new("track", event: "Test", context: context)

      assert event.context == context
    end
  end

  describe "Event.to_map/1" do
    test "converts track event to map with camelCase keys" do
      event = %Event{
        type: "track",
        message_id: "abc-123",
        timestamp: "2025-01-15T10:30:00Z",
        event: "Button Clicked",
        user_id: "user_123",
        properties: %{"button" => "signup"}
      }

      map = Event.to_map(event)

      assert map["type"] == "track"
      assert map["messageId"] == "abc-123"
      assert map["timestamp"] == "2025-01-15T10:30:00Z"
      assert map["event"] == "Button Clicked"
      assert map["userId"] == "user_123"
      assert map["properties"] == %{"button" => "signup"}
    end

    test "omits nil fields" do
      event = %Event{
        type: "track",
        message_id: "abc-123",
        timestamp: "2025-01-15T10:30:00Z",
        event: "Test",
        user_id: nil,
        group_id: nil,
        properties: nil,
        traits: nil,
        context: nil
      }

      map = Event.to_map(event)

      refute Map.has_key?(map, "userId")
      refute Map.has_key?(map, "groupId")
      refute Map.has_key?(map, "properties")
      refute Map.has_key?(map, "traits")
      refute Map.has_key?(map, "context")
    end

    test "omits empty properties/traits" do
      event = %Event{
        type: "track",
        message_id: "abc-123",
        timestamp: "2025-01-15T10:30:00Z",
        event: "Test",
        properties: %{},
        traits: %{}
      }

      map = Event.to_map(event)

      refute Map.has_key?(map, "properties")
      refute Map.has_key?(map, "traits")
    end

    test "includes context when present and non-empty" do
      library = LibraryInfo.new("elixir-sdk", "1.0.0")
      context = EventContext.new(library: library)

      event = %Event{
        type: "track",
        message_id: "abc-123",
        timestamp: "2025-01-15T10:30:00Z",
        event: "Test",
        context: context
      }

      map = Event.to_map(event)

      assert map["context"] == %{
               "library" => %{"name" => "elixir-sdk", "version" => "1.0.0"}
             }
    end

    test "omits empty context" do
      context = EventContext.new()

      event = %Event{
        type: "track",
        message_id: "abc-123",
        timestamp: "2025-01-15T10:30:00Z",
        event: "Test",
        context: context
      }

      map = Event.to_map(event)

      refute Map.has_key?(map, "context")
    end
  end

  describe "Event.to_json/1" do
    test "serializes event to JSON string" do
      event = %Event{
        type: "track",
        message_id: "abc-123",
        timestamp: "2025-01-15T10:30:00Z",
        event: "Test",
        user_id: "user_123"
      }

      json = Event.to_json(event)

      assert is_binary(json)
      {:ok, decoded} = Jason.decode(json)
      assert decoded["type"] == "track"
      assert decoded["messageId"] == "abc-123"
      assert decoded["userId"] == "user_123"
    end
  end

  describe "Event.estimate_size/1" do
    test "returns byte size of serialized event" do
      event = Event.new("track", event: "Test", user_id: "user_123")
      size = Event.estimate_size(event)

      assert is_integer(size)
      assert size > 0
      assert size == byte_size(Event.to_json(event))
    end
  end
end

defmodule Klime.BatchResponseTest do
  use ExUnit.Case, async: true

  alias Klime.{BatchResponse, ValidationError}

  describe "ValidationError.from_map/1" do
    test "creates validation error from map" do
      map = %{"index" => 2, "message" => "Invalid userId", "code" => "INVALID_USER_ID"}
      error = ValidationError.from_map(map)

      assert error.index == 2
      assert error.message == "Invalid userId"
      assert error.code == "INVALID_USER_ID"
    end

    test "handles missing fields with defaults" do
      error = ValidationError.from_map(%{})

      assert error.index == -1
      assert error.message == ""
      assert error.code == ""
    end
  end

  describe "BatchResponse.from_map/1" do
    test "creates batch response from map" do
      map = %{"status" => "ok", "accepted" => 5, "failed" => 0}
      response = BatchResponse.from_map(map)

      assert response.status == "ok"
      assert response.accepted == 5
      assert response.failed == 0
      assert response.errors == nil
    end

    test "parses errors when present" do
      map = %{
        "status" => "partial",
        "accepted" => 3,
        "failed" => 2,
        "errors" => [
          %{"index" => 1, "message" => "Error 1", "code" => "ERR1"},
          %{"index" => 4, "message" => "Error 2", "code" => "ERR2"}
        ]
      }

      response = BatchResponse.from_map(map)

      assert response.failed == 2
      assert length(response.errors) == 2
      assert hd(response.errors).index == 1
      assert hd(response.errors).message == "Error 1"
    end

    test "handles missing fields with defaults" do
      response = BatchResponse.from_map(%{})

      assert response.status == "ok"
      assert response.accepted == 0
      assert response.failed == 0
      assert response.errors == nil
    end
  end

  describe "BatchResponse.success?/1" do
    test "returns true when no failures" do
      response = BatchResponse.from_map(%{"accepted" => 5, "failed" => 0})
      assert BatchResponse.success?(response)
    end

    test "returns false when there are failures" do
      response = BatchResponse.from_map(%{"accepted" => 3, "failed" => 2})
      refute BatchResponse.success?(response)
    end
  end

  describe "BatchResponse.partial?/1" do
    test "returns true when there are failures" do
      response = BatchResponse.from_map(%{"accepted" => 3, "failed" => 2})
      assert BatchResponse.partial?(response)
    end

    test "returns false when no failures" do
      response = BatchResponse.from_map(%{"accepted" => 5, "failed" => 0})
      refute BatchResponse.partial?(response)
    end
  end
end
