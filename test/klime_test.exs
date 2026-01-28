defmodule KlimeTest do
  # Note: async: false because we use application config and global :klime name
  use ExUnit.Case, async: false

  setup do
    bypass = Bypass.open()

    # Configure Klime via application env
    Application.put_env(:klime, :write_key, "test-write-key")
    Application.put_env(:klime, :endpoint, "http://localhost:#{bypass.port}")
    Application.put_env(:klime, :flush_interval, 60_000)
    Application.put_env(:klime, :max_batch_size, 10)
    Application.put_env(:klime, :retry_max_attempts, 1)
    Application.put_env(:klime, :retry_initial_delay, 10)

    # Start the client with default name :klime
    {:ok, pid} = Klime.Client.start_link()

    on_exit(fn ->
      # Stop client first
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)

      # Clean up application config
      Application.delete_env(:klime, :write_key)
      Application.delete_env(:klime, :endpoint)
      Application.delete_env(:klime, :flush_interval)
      Application.delete_env(:klime, :max_batch_size)
      Application.delete_env(:klime, :retry_max_attempts)
      Application.delete_env(:klime, :retry_initial_delay)
    end)

    {:ok, bypass: bypass, pid: pid}
  end

  describe "Klime module API (no client argument)" do
    test "track/3 queues event", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/batch", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["batch"]) == 1
        event = hd(decoded["batch"])
        assert event["type"] == "track"
        assert event["event"] == "Button Clicked"
        assert event["properties"]["button"] == "signup"
        assert event["userId"] == "user_123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"status" => "ok", "accepted" => 1, "failed" => 0}))
      end)

      assert :ok = Klime.track("Button Clicked", %{button: "signup"}, user_id: "user_123")
      assert Klime.queue_size() == 1

      :ok = Klime.flush()
      assert Klime.queue_size() == 0
    end

    test "track!/3 sends immediately and returns result", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"status" => "ok", "accepted" => 1, "failed" => 0}))
      end)

      result = Klime.track!("Sync Event", %{}, user_id: "user_123")
      assert {:ok, %Klime.BatchResponse{status: "ok", accepted: 1}} = result
    end

    test "identify/2 queues event", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/batch", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        event = hd(decoded["batch"])
        assert event["type"] == "identify"
        assert event["userId"] == "user_123"
        assert event["traits"]["email"] == "user@example.com"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"status" => "ok", "accepted" => 1, "failed" => 0}))
      end)

      assert :ok = Klime.identify("user_123", %{email: "user@example.com"})
      :ok = Klime.flush()
    end

    test "identify!/2 sends immediately", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"status" => "ok", "accepted" => 1, "failed" => 0}))
      end)

      result = Klime.identify!("user_123", %{name: "Test"})
      assert {:ok, %Klime.BatchResponse{}} = result
    end

    test "group/3 queues event", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/batch", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        event = hd(decoded["batch"])
        assert event["type"] == "group"
        assert event["groupId"] == "org_456"
        assert event["traits"]["name"] == "Acme Inc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"status" => "ok", "accepted" => 1, "failed" => 0}))
      end)

      assert :ok = Klime.group("org_456", %{name: "Acme Inc"}, user_id: "user_123")
      :ok = Klime.flush()
    end

    test "group!/3 sends immediately", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"status" => "ok", "accepted" => 1, "failed" => 0}))
      end)

      result = Klime.group!("org_456", %{plan: "enterprise"})
      assert {:ok, %Klime.BatchResponse{}} = result
    end

    test "flush/0 flushes all queued events", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/v1/batch", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["batch"]) == 3

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"status" => "ok", "accepted" => 3, "failed" => 0}))
      end)

      Klime.track("Event 1", %{}, user_id: "user_1")
      Klime.track("Event 2", %{}, user_id: "user_2")
      Klime.track("Event 3", %{}, user_id: "user_3")

      assert Klime.queue_size() == 3
      :ok = Klime.flush()
      assert Klime.queue_size() == 0
    end
  end
end
