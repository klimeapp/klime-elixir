defmodule Klime.Plug do
  @moduledoc """
  Plug middleware that flushes events after each request.

  This is useful when you need guaranteed delivery of events within the
  request lifecycle, rather than relying on background flushing.

  ## Usage in Phoenix

      # In your endpoint.ex or router.ex
      plug Klime.Plug, client: Klime

      # Or with a dynamic client
      plug Klime.Plug, client: MyApp.Klime

  ## Usage in a Plug application

      plug Klime.Plug, client: klime_client

  ## Options

    * `:client` - The Klime client process (name or pid). Required.

  ## Note

  This adds latency to every request as it waits for the flush.
  Only use this if you need guaranteed per-request delivery.
  For most use cases, the background worker is sufficient.
  """

  require Logger

  @behaviour Plug

  @impl true
  def init(opts) do
    client = Keyword.fetch!(opts, :client)
    %{client: client}
  end

  @impl true
  def call(conn, %{client: client}) do
    Plug.Conn.register_before_send(conn, fn conn ->
      flush_client(client)
      conn
    end)
  end

  defp flush_client(client) do
    Klime.Client.flush(client)
  rescue
    e ->
      # Don't let flush errors break the request
      Logger.error("Klime.Plug flush error: #{inspect(e)}")
  catch
    :exit, reason ->
      # Don't let flush errors break the request (e.g., if client process is dead)
      Logger.error("Klime.Plug flush error: #{inspect(reason)}")
  end
end
