defmodule Klime do
  @moduledoc """
  Klime SDK for Elixir - Track events, identify users, and group them with organizations.

  ## Quick Start

  1. Configure in `config/config.exs`:

      config :klime,
        write_key: System.get_env("KLIME_WRITE_KEY")

  2. Add to your supervision tree in `application.ex`:

      children = [
        Klime.Client
      ]

  3. Track events anywhere in your app:

      Klime.track("Button Clicked", %{button: "signup"}, user_id: "user_123")
      Klime.identify("user_123", %{email: "user@example.com"})
      Klime.group("org_456", %{name: "Acme Inc"}, user_id: "user_123")

  ## Configuration Options

  See `Klime.Config` for all available configuration options.
  """

  @default_client :klime

  @doc """
  Tracks a user event (async).

  Events are queued and sent in batches. Returns immediately.

  ## Options

    * `:user_id` - User identifier (recommended for user events)
    * `:group_id` - Group identifier (for group-level events or explicit context)

  ## Examples

      Klime.track("Button Clicked", %{button: "signup"}, user_id: "user_123")
      Klime.track("Webhook Received", %{count: 10}, group_id: "org_456")

  """
  @spec track(String.t(), map(), keyword()) :: :ok
  def track(event_name, properties \\ %{}, opts \\ []) do
    GenServer.call(@default_client, {:track, event_name, properties, opts})
  end

  @doc """
  Tracks a user event (sync) - blocks until sent, returns result.

  Unlike `track/3`, this sends the event immediately and waits for the response.

  ## Examples

      {:ok, response} = Klime.track!("Button Clicked", %{button: "signup"}, user_id: "user_123")

  """
  @spec track!(String.t(), map(), keyword()) :: Klime.Client.sync_result()
  def track!(event_name, properties \\ %{}, opts \\ []) do
    GenServer.call(@default_client, {:track_sync, event_name, properties, opts}, :infinity)
  end

  @doc """
  Identifies a user with traits (async).

  Events are queued and sent in batches. Returns immediately.

  ## Examples

      Klime.identify("user_123", %{email: "user@example.com", name: "Stefan"})

  """
  @spec identify(String.t(), map()) :: :ok
  def identify(user_id, traits \\ %{}) do
    GenServer.call(@default_client, {:identify, user_id, traits})
  end

  @doc """
  Identifies a user with traits (sync) - blocks until sent, returns result.

  Unlike `identify/2`, this sends the event immediately and waits for the response.

  ## Examples

      {:ok, response} = Klime.identify!("user_123", %{email: "user@example.com"})

  """
  @spec identify!(String.t(), map()) :: Klime.Client.sync_result()
  def identify!(user_id, traits \\ %{}) do
    GenServer.call(@default_client, {:identify_sync, user_id, traits}, :infinity)
  end

  @doc """
  Associates a user with a group and/or sets group traits (async).

  Events are queued and sent in batches. Returns immediately.

  ## Options

    * `:user_id` - User identifier to link to the group

  ## Examples

      # Associate user with group and set traits
      Klime.group("org_456", %{name: "Acme Inc"}, user_id: "user_123")

      # Just set group traits (no user association)
      Klime.group("org_456", %{plan: "enterprise"})

  """
  @spec group(String.t(), map(), keyword()) :: :ok
  def group(group_id, traits \\ %{}, opts \\ []) do
    GenServer.call(@default_client, {:group, group_id, traits, opts})
  end

  @doc """
  Associates a user with a group (sync) - blocks until sent, returns result.

  Unlike `group/3`, this sends the event immediately and waits for the response.

  ## Examples

      {:ok, response} = Klime.group!("org_456", %{name: "Acme Inc"}, user_id: "user_123")

  """
  @spec group!(String.t(), map(), keyword()) :: Klime.Client.sync_result()
  def group!(group_id, traits \\ %{}, opts \\ []) do
    GenServer.call(@default_client, {:group_sync, group_id, traits, opts}, :infinity)
  end

  @doc """
  Manually flushes all queued events immediately.

  Blocks until all events are sent.

  ## Examples

      :ok = Klime.flush()

  """
  @spec flush() :: :ok
  def flush do
    GenServer.call(@default_client, :flush, :infinity)
  end

  @doc """
  Gracefully shuts down the client, flushing remaining events.

  ## Examples

      :ok = Klime.shutdown()

  """
  @spec shutdown() :: :ok
  def shutdown do
    GenServer.call(@default_client, :shutdown, :infinity)
  end

  @doc """
  Returns the current queue size (useful for debugging).
  """
  @spec queue_size() :: non_neg_integer()
  def queue_size do
    GenServer.call(@default_client, :queue_size)
  end
end
