defmodule Klime do
  @moduledoc """
  Klime SDK for Elixir - Track events, identify users, and group them with organizations.

  ## Quick Start

      # Start the client (typically in your application supervision tree)
      {:ok, client} = Klime.Client.start_link(write_key: "your-write-key")

      # Track events
      Klime.track(client, "Button Clicked", %{button_name: "Sign up"}, user_id: "user_123")

      # Identify users
      Klime.identify(client, "user_123", %{email: "user@example.com", name: "Stefan"})

      # Associate with groups
      Klime.group(client, "org_456", %{name: "Acme Inc"}, user_id: "user_123")

  ## Phoenix Integration

  Add to your application supervision tree:

      # In application.ex
      children = [
        {Klime.Client, write_key: System.get_env("KLIME_WRITE_KEY"), name: Klime}
      ]

      # In controllers/contexts
      Klime.track(Klime, "Page Viewed", %{path: conn.request_path}, user_id: user.id)

  ## Configuration Options

  See `Klime.Client` for all available configuration options.
  """

  @doc """
  Tracks a user event (async).

  Events are queued and sent in batches. Returns immediately.

  ## Options

    * `:user_id` - User identifier (recommended for user events)
    * `:group_id` - Group identifier (for group-level events or explicit context)

  ## Examples

      Klime.track(client, "Button Clicked", %{button: "signup"}, user_id: "user_123")
      Klime.track(client, "Webhook Received", %{count: 10}, group_id: "org_456")

  """
  defdelegate track(client, event_name, properties \\ %{}, opts \\ []), to: Klime.Client

  @doc """
  Tracks a user event (sync) - blocks until sent, returns result.

  Unlike `track/4`, this sends the event immediately and waits for the response.

  ## Examples

      {:ok, response} = Klime.track!(client, "Button Clicked", %{button: "signup"}, user_id: "user_123")

  """
  defdelegate track!(client, event_name, properties \\ %{}, opts \\ []), to: Klime.Client

  @doc """
  Identifies a user with traits (async).

  Events are queued and sent in batches. Returns immediately.

  ## Examples

      Klime.identify(client, "user_123", %{email: "user@example.com", name: "Stefan"})

  """
  defdelegate identify(client, user_id, traits \\ %{}), to: Klime.Client

  @doc """
  Identifies a user with traits (sync) - blocks until sent, returns result.

  Unlike `identify/3`, this sends the event immediately and waits for the response.

  ## Examples

      {:ok, response} = Klime.identify!(client, "user_123", %{email: "user@example.com"})

  """
  defdelegate identify!(client, user_id, traits \\ %{}), to: Klime.Client

  @doc """
  Associates a user with a group and/or sets group traits (async).

  Events are queued and sent in batches. Returns immediately.

  ## Options

    * `:user_id` - User identifier to link to the group

  ## Examples

      # Associate user with group and set traits
      Klime.group(client, "org_456", %{name: "Acme Inc"}, user_id: "user_123")

      # Just set group traits (no user association)
      Klime.group(client, "org_456", %{plan: "enterprise"})

  """
  defdelegate group(client, group_id, traits \\ %{}, opts \\ []), to: Klime.Client

  @doc """
  Associates a user with a group (sync) - blocks until sent, returns result.

  Unlike `group/4`, this sends the event immediately and waits for the response.

  ## Examples

      {:ok, response} = Klime.group!(client, "org_456", %{name: "Acme Inc"}, user_id: "user_123")

  """
  defdelegate group!(client, group_id, traits \\ %{}, opts \\ []), to: Klime.Client

  @doc """
  Manually flushes all queued events immediately.

  Blocks until all events are sent.

  ## Examples

      :ok = Klime.flush(client)

  """
  defdelegate flush(client), to: Klime.Client

  @doc """
  Gracefully shuts down the client, flushing remaining events.

  ## Examples

      :ok = Klime.shutdown(client)

  """
  defdelegate shutdown(client), to: Klime.Client

  @doc """
  Returns the current queue size (useful for debugging).
  """
  defdelegate queue_size(client), to: Klime.Client
end
