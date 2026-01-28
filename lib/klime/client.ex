defmodule Klime.ConfigurationError do
  @moduledoc """
  Raised when the client is configured incorrectly.
  """
  defexception [:message]
end

defmodule Klime.SendError do
  @moduledoc """
  Raised when sending events fails permanently.
  """
  defexception [:message, :status_code, :events]

  @type t :: %__MODULE__{
          message: String.t(),
          status_code: integer() | nil,
          events: [Klime.Event.t()] | nil
        }

  def new(message, opts \\ []) do
    %__MODULE__{
      message: message,
      status_code: Keyword.get(opts, :status_code),
      events: Keyword.get(opts, :events)
    }
  end
end

defmodule Klime.Client do
  @moduledoc """
  GenServer-based client for the Klime analytics SDK.

  ## Usage

  Start the client as part of your application's supervision tree:

      children = [
        {Klime.Client, write_key: "your-write-key", name: Klime}
      ]

  Or start it directly:

      {:ok, client} = Klime.Client.start_link(write_key: "your-write-key")

  Then use it to track events:

      Klime.Client.track(client, "Button Clicked", %{button: "signup"}, user_id: "user_123")
      Klime.Client.identify(client, "user_123", %{email: "user@example.com"})
      Klime.Client.group(client, "org_456", %{name: "Acme Inc"}, user_id: "user_123")

  ## Configuration Options

    * `:write_key` - Required. Your Klime write key.
    * `:endpoint` - API endpoint URL. Default: `"https://i.klime.com"`
    * `:flush_interval` - Milliseconds between auto-flushes. Default: `2000`
    * `:max_batch_size` - Maximum events per batch. Default: `20`, max: `100`
    * `:max_queue_size` - Maximum queued events. Default: `1000`
    * `:retry_max_attempts` - Maximum retry attempts. Default: `5`
    * `:retry_initial_delay` - Initial retry delay in ms. Default: `1000`
    * `:flush_on_shutdown` - Auto-flush on shutdown. Default: `true`
    * `:on_error` - Callback function `(error, events) -> any()` for batch failures
    * `:on_success` - Callback function `(response) -> any()` for batch success
    * `:name` - Optional name to register the GenServer

  """

  use GenServer
  require Logger

  alias Klime.{Config, Event, EventType, EventContext, LibraryInfo, BatchResponse}

  @version "1.0.1"

  @typedoc "Client process reference (pid or registered name)"
  @type client :: GenServer.server()

  @typedoc "Track/group options"
  @type track_opts :: [user_id: String.t(), group_id: String.t()]

  @typedoc "Sync method result"
  @type sync_result :: {:ok, BatchResponse.t()} | {:error, Klime.SendError.t()}

  # Client API

  @doc """
  Returns a child specification for starting the client under a supervisor.

  ## Examples

      children = [
        {Klime.Client, write_key: "your-write-key", name: Klime}
      ]

  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: opts[:name] || __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Starts the Klime client GenServer.

  ## Options

  See module documentation for available options.

  ## Examples

      {:ok, client} = Klime.Client.start_link(write_key: "your-write-key")

      # With a registered name
      {:ok, _} = Klime.Client.start_link(write_key: "your-write-key", name: MyApp.Klime)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Tracks a user event (async).

  Events are queued and sent in batches. Returns immediately without waiting
  for the event to be sent.

  ## Options

    * `:user_id` - User identifier (recommended for user events)
    * `:group_id` - Group identifier (for group-level events or explicit context)

  ## Examples

      Klime.Client.track(client, "Button Clicked", %{button: "signup"}, user_id: "user_123")
      Klime.Client.track(client, "Webhook Received", %{count: 10}, group_id: "org_456")

  """
  @spec track(client(), String.t(), map(), track_opts()) :: :ok
  def track(client, event_name, properties \\ %{}, opts \\ []) do
    GenServer.call(client, {:track, event_name, properties, opts})
  end

  @doc """
  Tracks a user event (sync) - blocks until sent, raises on error.

  Unlike `track/4`, this sends the event immediately and waits for the response.
  Use this when you need guaranteed delivery or want to handle errors explicitly.

  ## Options

    * `:user_id` - User identifier (recommended for user events)
    * `:group_id` - Group identifier (for group-level events or explicit context)

  ## Examples

      {:ok, response} = Klime.Client.track!(client, "Button Clicked", %{button: "signup"}, user_id: "user_123")

  ## Returns

    * `{:ok, %Klime.BatchResponse{}}` on success
    * `{:error, %Klime.SendError{}}` on failure

  """
  @spec track!(client(), String.t(), map(), track_opts()) :: sync_result()
  def track!(client, event_name, properties \\ %{}, opts \\ []) do
    GenServer.call(client, {:track_sync, event_name, properties, opts}, :infinity)
  end

  @doc """
  Identifies a user with traits (async).

  Events are queued and sent in batches. Returns immediately without waiting
  for the event to be sent.

  ## Examples

      Klime.Client.identify(client, "user_123", %{email: "user@example.com", name: "Stefan"})

  """
  @spec identify(client(), String.t(), map()) :: :ok
  def identify(client, user_id, traits \\ %{}) do
    GenServer.call(client, {:identify, user_id, traits})
  end

  @doc """
  Identifies a user with traits (sync) - blocks until sent, raises on error.

  Unlike `identify/3`, this sends the event immediately and waits for the response.
  Use this when you need guaranteed delivery or want to handle errors explicitly.

  ## Examples

      {:ok, response} = Klime.Client.identify!(client, "user_123", %{email: "user@example.com"})

  ## Returns

    * `{:ok, %Klime.BatchResponse{}}` on success
    * `{:error, %Klime.SendError{}}` on failure

  """
  @spec identify!(client(), String.t(), map()) :: sync_result()
  def identify!(client, user_id, traits \\ %{}) do
    GenServer.call(client, {:identify_sync, user_id, traits}, :infinity)
  end

  @doc """
  Associates a user with a group and/or sets group traits (async).

  Events are queued and sent in batches. Returns immediately without waiting
  for the event to be sent.

  ## Options

    * `:user_id` - User identifier to link to the group

  ## Examples

      # Associate user with group and set traits
      Klime.Client.group(client, "org_456", %{name: "Acme Inc"}, user_id: "user_123")

      # Just set group traits (no user association)
      Klime.Client.group(client, "org_456", %{plan: "enterprise"})

  """
  @spec group(client(), String.t(), map(), track_opts()) :: :ok
  def group(client, group_id, traits \\ %{}, opts \\ []) do
    GenServer.call(client, {:group, group_id, traits, opts})
  end

  @doc """
  Associates a user with a group (sync) - blocks until sent, raises on error.

  Unlike `group/4`, this sends the event immediately and waits for the response.
  Use this when you need guaranteed delivery or want to handle errors explicitly.

  ## Options

    * `:user_id` - User identifier to link to the group

  ## Examples

      {:ok, response} = Klime.Client.group!(client, "org_456", %{name: "Acme Inc"}, user_id: "user_123")

  ## Returns

    * `{:ok, %Klime.BatchResponse{}}` on success
    * `{:error, %Klime.SendError{}}` on failure

  """
  @spec group!(client(), String.t(), map(), track_opts()) :: sync_result()
  def group!(client, group_id, traits \\ %{}, opts \\ []) do
    GenServer.call(client, {:group_sync, group_id, traits, opts}, :infinity)
  end

  @doc """
  Manually flushes all queued events immediately.

  Blocks until all events are sent.

  ## Examples

      :ok = Klime.Client.flush(client)

  """
  @spec flush(client()) :: :ok
  def flush(client) do
    GenServer.call(client, :flush, :infinity)
  end

  @doc """
  Gracefully shuts down the client, flushing remaining events.

  ## Examples

      :ok = Klime.Client.shutdown(client)

  """
  @spec shutdown(client()) :: :ok
  def shutdown(client) do
    GenServer.call(client, :shutdown, :infinity)
  end

  @doc """
  Returns the current queue size (useful for debugging).
  """
  @spec queue_size(client()) :: non_neg_integer()
  def queue_size(client) do
    GenServer.call(client, :queue_size)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    write_key = Keyword.get(opts, :write_key)

    if is_nil(write_key) or write_key == "" do
      {:stop, %Klime.ConfigurationError{message: "write_key is required"}}
    else
      state = %{
        write_key: write_key,
        endpoint: Keyword.get(opts, :endpoint, Config.default_endpoint()),
        flush_interval: Keyword.get(opts, :flush_interval, Config.default_flush_interval()),
        max_batch_size: min(
          Keyword.get(opts, :max_batch_size, Config.default_max_batch_size()),
          Config.max_batch_size()
        ),
        max_queue_size: Keyword.get(opts, :max_queue_size, Config.default_max_queue_size()),
        retry_max_attempts: Keyword.get(opts, :retry_max_attempts, Config.default_retry_max_attempts()),
        retry_initial_delay: Keyword.get(opts, :retry_initial_delay, Config.default_retry_initial_delay()),
        flush_on_shutdown: Keyword.get(opts, :flush_on_shutdown, true),
        on_error: Keyword.get(opts, :on_error),
        on_success: Keyword.get(opts, :on_success),
        queue: [],
        shutdown: false,
        flush_timer: nil
      }

      # Schedule first flush
      state = schedule_flush(state)

      Logger.debug("Klime client initialized (endpoint: #{state.endpoint}, flush_interval: #{state.flush_interval}ms)")

      {:ok, state}
    end
  end

  @impl true
  def handle_call({:track, event_name, properties, opts}, _from, state) do
    if state.shutdown do
      {:reply, :ok, state}
    else
      event = Event.new(EventType.track(),
        event: event_name,
        properties: properties,
        user_id: Keyword.get(opts, :user_id),
        group_id: Keyword.get(opts, :group_id),
        context: build_context()
      )

      state = enqueue(event, state)
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:identify, user_id, traits}, _from, state) do
    if state.shutdown do
      {:reply, :ok, state}
    else
      event = Event.new(EventType.identify(),
        user_id: user_id,
        traits: traits,
        context: build_context()
      )

      state = enqueue(event, state)
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:group, group_id, traits, opts}, _from, state) do
    if state.shutdown do
      {:reply, :ok, state}
    else
      event = Event.new(EventType.group(),
        group_id: group_id,
        traits: traits,
        user_id: Keyword.get(opts, :user_id),
        context: build_context()
      )

      state = enqueue(event, state)
      {:reply, :ok, state}
    end
  end

  # Synchronous handlers - send immediately and return result

  @impl true
  def handle_call({:track_sync, event_name, properties, opts}, _from, state) do
    if state.shutdown do
      {:reply, {:error, Klime.SendError.new("Client is shutdown")}, state}
    else
      event = Event.new(EventType.track(),
        event: event_name,
        properties: properties,
        user_id: Keyword.get(opts, :user_id),
        group_id: Keyword.get(opts, :group_id),
        context: build_context()
      )

      result = send_sync([event], state)
      {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:identify_sync, user_id, traits}, _from, state) do
    if state.shutdown do
      {:reply, {:error, Klime.SendError.new("Client is shutdown")}, state}
    else
      event = Event.new(EventType.identify(),
        user_id: user_id,
        traits: traits,
        context: build_context()
      )

      result = send_sync([event], state)
      {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:group_sync, group_id, traits, opts}, _from, state) do
    if state.shutdown do
      {:reply, {:error, Klime.SendError.new("Client is shutdown")}, state}
    else
      event = Event.new(EventType.group(),
        group_id: group_id,
        traits: traits,
        user_id: Keyword.get(opts, :user_id),
        context: build_context()
      )

      result = send_sync([event], state)
      {:reply, result, state}
    end
  end

  @impl true
  def handle_call(:flush, _from, state) do
    if state.shutdown do
      {:reply, :ok, state}
    else
      state = do_flush(state)
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:shutdown, _from, state) do
    Logger.info("Klime client shutting down...")

    # Cancel any pending flush timer
    state = cancel_flush_timer(state)

    # Flush remaining events
    state = if state.flush_on_shutdown, do: do_flush(state), else: state

    # Mark as shutdown
    state = %{state | shutdown: true}

    Logger.info("Klime client shutdown complete")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:queue_size, _from, state) do
    {:reply, length(state.queue), state}
  end

  @impl true
  def handle_info(:flush, state) do
    if state.shutdown or Enum.empty?(state.queue) do
      state = schedule_flush(state)
      {:noreply, state}
    else
      state = do_flush(state)
      state = schedule_flush(state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    # Flush remaining events on graceful shutdown
    if state.flush_on_shutdown and not state.shutdown do
      Logger.debug("Klime: terminate called (reason: #{inspect(reason)}), flushing remaining events")
      do_flush(state)
    end

    :ok
  end

  # Private Functions

  defp build_context do
    EventContext.new(
      library: LibraryInfo.new("elixir-sdk", @version)
    )
  end

  defp enqueue(event, state) do
    # Check event size
    event_size = Event.estimate_size(event)

    if event_size > Config.max_event_size_bytes() do
      Logger.warning("Klime: Event rejected - size (#{event_size} bytes) exceeds #{Config.max_event_size_bytes()} bytes limit")
      state
    else
      queue = state.queue
      queue_len = length(queue)

      # Drop oldest if queue is full (FIFO eviction)
      queue =
        if queue_len >= state.max_queue_size do
          Logger.warning("Klime: Queue full (#{state.max_queue_size}), dropped oldest event")
          # Note: For high-throughput scenarios, consider using :queue for O(1) operations
          Enum.drop(queue, 1)
        else
          queue
        end

      # Append new event
      queue = queue ++ [event]
      Logger.debug("Klime: Event enqueued (#{event.type}, queue_size: #{length(queue)})")

      state = %{state | queue: queue}

      # Flush immediately if batch size reached
      if length(state.queue) >= state.max_batch_size do
        Logger.debug("Klime: Batch size reached (#{state.max_batch_size}), triggering immediate flush")
        do_flush(state)
      else
        state
      end
    end
  end

  defp do_flush(state) do
    flush_all_batches(state)
  end

  defp flush_all_batches(%{queue: []} = state), do: state
  defp flush_all_batches(state) do
    {batch, remaining} = extract_batch(state.queue, state.max_batch_size)

    if Enum.empty?(batch) do
      state
    else
      send_batch(batch, state)
      flush_all_batches(%{state | queue: remaining})
    end
  end

  defp extract_batch(queue, max_size) do
    extract_batch(queue, [], 0, max_size, 0)
  end

  defp extract_batch([], batch, _batch_size, _max_size, _count) do
    {Enum.reverse(batch), []}
  end

  defp extract_batch(remaining, batch, _batch_size, _max_size, count) when count >= 100 do
    # Hard limit of 100 events per batch
    {Enum.reverse(batch), remaining}
  end

  defp extract_batch(remaining, batch, _batch_size, max_size, count) when count >= max_size do
    {Enum.reverse(batch), remaining}
  end

  defp extract_batch([event | rest], batch, batch_size, max_size, count) do
    event_size = Event.estimate_size(event)
    new_batch_size = batch_size + event_size

    if new_batch_size > Config.max_batch_size_bytes() and count > 0 do
      # Would exceed batch size limit, stop here
      {Enum.reverse(batch), [event | rest]}
    else
      extract_batch(rest, [event | batch], new_batch_size, max_size, count + 1)
    end
  end

  # Synchronous send for bang methods - sends immediately, returns result
  defp send_sync(events, state) do
    url = "#{state.endpoint}/v1/batch"
    body = %{"batch" => Enum.map(events, &Event.to_map/1)} |> Jason.encode!()

    Logger.debug("Klime: Sending sync (size: #{length(events)})")

    case make_request(url, body, state.write_key) do
      {:ok, status, response_body} when status >= 200 and status < 300 ->
        case Jason.decode(response_body) do
          {:ok, data} ->
            response = BatchResponse.from_map(data)
            Logger.debug("Klime: Sync send successful (accepted: #{response.accepted})")
            {:ok, response}

          {:error, _} ->
            response = BatchResponse.from_map(%{"accepted" => length(events), "failed" => 0})
            {:ok, response}
        end

      {:ok, status, response_body} when status in [400, 401] ->
        error = Klime.SendError.new("Request failed (#{status}): #{response_body}", status_code: status, events: events)
        Logger.error("Klime: #{error.message}")
        {:error, error}

      {:ok, status, response_body} ->
        error = Klime.SendError.new("Request failed (#{status}): #{response_body}", status_code: status, events: events)
        Logger.error("Klime: #{error.message}")
        {:error, error}

      {:error, reason} ->
        error = Klime.SendError.new("Network error: #{inspect(reason)}", events: events)
        Logger.error("Klime: #{error.message}")
        {:error, error}
    end
  end

  defp send_batch(batch, state) do
    url = "#{state.endpoint}/v1/batch"
    body = %{"batch" => Enum.map(batch, &Event.to_map/1)} |> Jason.encode!()

    Logger.debug("Klime: Sending batch (size: #{length(batch)}, bytes: #{byte_size(body)})")

    send_with_retry(url, body, batch, state, 0, state.retry_initial_delay)
  end

  defp send_with_retry(_url, _body, batch, state, attempt, _delay) when attempt >= state.retry_max_attempts do
    error_msg = "Failed to send batch after #{state.retry_max_attempts} attempts"
    Logger.error("Klime: #{error_msg}")
    invoke_on_error(Klime.SendError.new(error_msg, events: batch), batch, state)
  end

  defp send_with_retry(url, body, batch, state, attempt, delay) do
    case make_request(url, body, state.write_key) do
      {:ok, status, response_body} when status >= 200 and status < 300 ->
        handle_success_response(response_body, batch, state)

      {:ok, status, response_body} when status in [400, 401] ->
        # Permanent error - don't retry
        error_msg = "Permanent error (#{status}): #{response_body}"
        Logger.error("Klime: #{error_msg}")
        invoke_on_error(Klime.SendError.new(error_msg, status_code: status, events: batch), batch, state)

      {:ok, status, response_body} when status == 429 ->
        # Rate limited - check Retry-After header and retry
        retry_after = parse_retry_after(response_body)
        actual_delay = if retry_after > 0, do: retry_after * 1000, else: delay

        if attempt + 1 < state.retry_max_attempts do
          Logger.warning("Klime: Rate limited (#{status}), retrying in #{actual_delay}ms (attempt #{attempt + 1}/#{state.retry_max_attempts})")
          Process.sleep(actual_delay)
          send_with_retry(url, body, batch, state, attempt + 1, min(delay * 2, 16_000))
        else
          send_with_retry(url, body, batch, state, state.retry_max_attempts, delay)
        end

      {:ok, status, _response_body} when status >= 500 ->
        # Server error - retry
        if attempt + 1 < state.retry_max_attempts do
          Logger.warning("Klime: Server error (#{status}), retrying in #{delay}ms (attempt #{attempt + 1}/#{state.retry_max_attempts})")
          Process.sleep(delay)
          send_with_retry(url, body, batch, state, attempt + 1, min(delay * 2, 16_000))
        else
          send_with_retry(url, body, batch, state, state.retry_max_attempts, delay)
        end

      {:ok, status, response_body} ->
        # Other errors
        if attempt + 1 < state.retry_max_attempts do
          Logger.warning("Klime: Request failed (#{status}), retrying in #{delay}ms (attempt #{attempt + 1}/#{state.retry_max_attempts})")
          Process.sleep(delay)
          send_with_retry(url, body, batch, state, attempt + 1, min(delay * 2, 16_000))
        else
          error_msg = "Request failed (#{status}): #{response_body}"
          Logger.error("Klime: #{error_msg}")
          invoke_on_error(Klime.SendError.new(error_msg, status_code: status, events: batch), batch, state)
        end

      {:error, reason} ->
        # Network error - retry
        if attempt + 1 < state.retry_max_attempts do
          Logger.warning("Klime: Network error (#{inspect(reason)}), retrying in #{delay}ms (attempt #{attempt + 1}/#{state.retry_max_attempts})")
          Process.sleep(delay)
          send_with_retry(url, body, batch, state, attempt + 1, min(delay * 2, 16_000))
        else
          error_msg = "Network error: #{inspect(reason)}"
          Logger.error("Klime: #{error_msg}")
          invoke_on_error(Klime.SendError.new(error_msg, events: batch), batch, state)
        end
    end
  end

  defp handle_success_response(response_body, batch, state) do
    case Jason.decode(response_body) do
      {:ok, data} ->
        response = BatchResponse.from_map(data)

        if response.failed > 0 do
          Logger.warning("Klime: Batch partially failed (accepted: #{response.accepted}, failed: #{response.failed})")
          if response.errors do
            Enum.each(response.errors, fn err ->
              Logger.warning("Klime:   Event #{err.index}: #{err.message} (#{err.code})")
            end)
          end
        else
          Logger.debug("Klime: Batch sent successfully (accepted: #{response.accepted})")
        end

        invoke_on_success(response, state)

      {:error, _} ->
        Logger.debug("Klime: Batch sent successfully (#{length(batch)} events)")
        invoke_on_success(BatchResponse.from_map(%{"accepted" => length(batch), "failed" => 0}), state)
    end
  end

  defp make_request(url, body, write_key) do
    # Ensure inets is started
    :inets.start()
    :ssl.start()

    headers = [
      {~c"Content-Type", ~c"application/json"},
      {~c"Authorization", String.to_charlist("Bearer #{write_key}")}
    ]

    request = {String.to_charlist(url), headers, ~c"application/json", body}
    http_options = [timeout: 10_000, connect_timeout: 10_000]
    options = [body_format: :binary]

    case :httpc.request(:post, request, http_options, options) do
      {:ok, {{_http_version, status, _reason}, _headers, response_body}} ->
        {:ok, status, to_string(response_body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_retry_after(_body) do
    # TODO: Parse Retry-After from response headers if available
    0
  end

  defp schedule_flush(%{flush_interval: interval} = state) do
    timer = Process.send_after(self(), :flush, interval)
    %{state | flush_timer: timer}
  end

  defp cancel_flush_timer(%{flush_timer: nil} = state), do: state
  defp cancel_flush_timer(%{flush_timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | flush_timer: nil}
  end

  defp invoke_on_error(_error, _batch, %{on_error: nil}), do: :ok
  defp invoke_on_error(error, batch, %{on_error: callback}) do
    try do
      callback.(error, batch)
    rescue
      e -> Logger.error("Klime: on_error callback raised: #{inspect(e)}")
    end
  end

  defp invoke_on_success(_response, %{on_success: nil}), do: :ok
  defp invoke_on_success(response, %{on_success: callback}) do
    try do
      callback.(response)
    rescue
      e -> Logger.error("Klime: on_success callback raised: #{inspect(e)}")
    end
  end
end
