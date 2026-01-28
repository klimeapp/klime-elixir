defmodule Klime.Config do
  @moduledoc """
  Default configuration values for the Klime SDK.
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
