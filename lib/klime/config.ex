defmodule Klime.Config do
  @moduledoc """
  Configuration for the Klime SDK.

  ## Application Configuration

  Configure Klime in your `config/config.exs`:

      config :klime,
        write_key: System.get_env("KLIME_WRITE_KEY")

  Or with all options:

      config :klime,
        write_key: System.get_env("KLIME_WRITE_KEY"),
        endpoint: "https://i.klime.com",
        flush_interval: 2000,
        max_batch_size: 20,
        max_queue_size: 1000

  ## Available Options

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
  """

  @default_endpoint "https://i.klime.com"
  @default_flush_interval 2000
  @default_max_batch_size 20
  @default_max_queue_size 1000
  @default_retry_max_attempts 5
  @default_retry_initial_delay 1000

  # Hard limits enforced by the server
  @max_batch_size 100
  @max_event_size_bytes 200 * 1024
  @max_batch_size_bytes 10 * 1024 * 1024

  @doc """
  Returns the configuration from application environment.

  Reads from `Application.get_env(:klime, key)` with defaults applied.
  """
  @spec get_config() :: keyword()
  def get_config do
    [
      write_key: get(:write_key),
      endpoint: get(:endpoint, @default_endpoint),
      flush_interval: get(:flush_interval, @default_flush_interval),
      max_batch_size: get(:max_batch_size, @default_max_batch_size),
      max_queue_size: get(:max_queue_size, @default_max_queue_size),
      retry_max_attempts: get(:retry_max_attempts, @default_retry_max_attempts),
      retry_initial_delay: get(:retry_initial_delay, @default_retry_initial_delay),
      flush_on_shutdown: get(:flush_on_shutdown, true),
      on_error: get(:on_error),
      on_success: get(:on_success)
    ]
  end

  @doc "Get a config value from application environment"
  @spec get(atom(), any()) :: any()
  def get(key, default \\ nil) do
    Application.get_env(:klime, key, default)
  end

  @doc "Default API endpoint URL"
  def default_endpoint, do: @default_endpoint

  @doc "Default flush interval in milliseconds"
  def default_flush_interval, do: @default_flush_interval

  @doc "Default maximum events per batch"
  def default_max_batch_size, do: @default_max_batch_size

  @doc "Default maximum queued events"
  def default_max_queue_size, do: @default_max_queue_size

  @doc "Default maximum retry attempts"
  def default_retry_max_attempts, do: @default_retry_max_attempts

  @doc "Default initial retry delay in milliseconds"
  def default_retry_initial_delay, do: @default_retry_initial_delay

  @doc "Hard limit: maximum events per batch (server enforced)"
  def max_batch_size, do: @max_batch_size

  @doc "Hard limit: maximum event size in bytes"
  def max_event_size_bytes, do: @max_event_size_bytes

  @doc "Hard limit: maximum batch size in bytes"
  def max_batch_size_bytes, do: @max_batch_size_bytes
end
