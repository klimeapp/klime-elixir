defmodule Klime.PlugTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn

  alias Klime.Client

  describe "Klime.Plug" do
    test "flushes events after request" do
      bypass = Bypass.open()
      {:ok, requests_agent} = Agent.start_link(fn -> [] end)

      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        Agent.update(requests_agent, fn reqs -> reqs ++ [Jason.decode!(body)] end)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
      end)

      {:ok, client} =
        Client.start_link(
          write_key: "test-write-key",
          endpoint: "http://localhost:#{bypass.port}",
          flush_interval: 999_999_999,
          flush_on_shutdown: false
        )

      # Track an event
      Client.track(client, "Test Event", %{}, user_id: "u1")

      # Event should be queued, not sent yet
      assert Agent.get(requests_agent, & &1) == []

      # Build a simple Plug pipeline with Klime.Plug
      opts = Klime.Plug.init(client: client)

      # Simulate a request going through the plug
      test_conn =
        conn(:get, "/test")
        |> Klime.Plug.call(opts)
        |> send_resp(200, "OK")

      assert test_conn.status == 200

      # After the request, events should have been flushed
      all_requests = Agent.get(requests_agent, & &1)
      assert length(all_requests) == 1
      assert hd(all_requests)["batch"] |> hd() |> Map.get("event") == "Test Event"

      Client.shutdown(client)
    end

    test "requires :client option" do
      assert_raise KeyError, fn ->
        Klime.Plug.init([])
      end
    end

    test "does not break request when client is dead" do
      # Start and immediately stop a client
      bypass = Bypass.open()

      {:ok, client} =
        Client.start_link(
          write_key: "test-key",
          endpoint: "http://localhost:#{bypass.port}",
          flush_interval: 999_999_999,
          flush_on_shutdown: false
        )

      Client.shutdown(client)
      GenServer.stop(client)

      # Wait for process to die
      Process.sleep(50)

      # Plug should not crash when client is dead
      opts = Klime.Plug.init(client: client)

      test_conn =
        conn(:get, "/test")
        |> Klime.Plug.call(opts)
        |> send_resp(200, "OK")

      # Request should complete successfully despite flush error
      assert test_conn.status == 200
    end
  end
end
