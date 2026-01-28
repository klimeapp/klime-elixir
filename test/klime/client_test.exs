defmodule Klime.ClientTest do
  use ExUnit.Case

  alias Klime.Client

  # Helper to create a client with auto-flush disabled for deterministic tests
  defp create_client(bypass, opts \\ []) do
    {:ok, client} =
      Client.start_link(
        Keyword.merge(
          [
            write_key: "test-write-key",
            endpoint: "http://localhost:#{bypass.port}",
            flush_interval: 999_999_999,
            flush_on_shutdown: false
          ],
          opts
        )
      )

    client
  end

  # Helper to capture requests
  defp setup_bypass_success(bypass, requests_agent) do
    Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      Agent.update(requests_agent, fn reqs -> reqs ++ [Jason.decode!(body)] end)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
    end)
  end

  setup do
    bypass = Bypass.open()
    {:ok, requests_agent} = Agent.start_link(fn -> [] end)
    {:ok, bypass: bypass, requests: requests_agent}
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Track Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "track/4" do
    test "sends correct payload", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass)

      Client.track(client, "Button Clicked", %{button: "signup"}, user_id: "user_123")
      Client.flush(client)

      [request] = Agent.get(requests, & &1)
      [event] = request["batch"]

      assert event["type"] == "track"
      assert event["event"] == "Button Clicked"
      assert event["userId"] == "user_123"
      assert event["properties"] == %{"button" => "signup"}
      assert Regex.match?(~r/^[0-9a-f-]{36}$/i, event["messageId"])
      assert Regex.match?(~r/^\d{4}-\d{2}-\d{2}T/, event["timestamp"])

      Client.shutdown(client)
    end

    test "includes library context", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass)

      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)

      [request] = Agent.get(requests, & &1)
      [event] = request["batch"]
      context = event["context"]

      assert context["library"]["name"] == "elixir-sdk"
      assert context["library"]["version"] == "1.0.0"

      Client.shutdown(client)
    end

    test "includes group_id when provided", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass)

      Client.track(client, "Test", %{}, user_id: "u1", group_id: "org_123")
      Client.flush(client)

      [request] = Agent.get(requests, & &1)
      [event] = request["batch"]

      assert event["userId"] == "u1"
      assert event["groupId"] == "org_123"

      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Identify Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "identify/3" do
    test "sends correct payload", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass)

      Client.identify(client, "user_123", %{email: "test@example.com", name: "Stefan"})
      Client.flush(client)

      [request] = Agent.get(requests, & &1)
      [event] = request["batch"]

      assert event["type"] == "identify"
      assert event["userId"] == "user_123"
      assert event["traits"] == %{"email" => "test@example.com", "name" => "Stefan"}

      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Group Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "group/4" do
    test "sends correct payload", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass)

      Client.group(client, "org_456", %{name: "Acme Inc", plan: "enterprise"}, user_id: "user_123")
      Client.flush(client)

      [request] = Agent.get(requests, & &1)
      [event] = request["batch"]

      assert event["type"] == "group"
      assert event["groupId"] == "org_456"
      assert event["userId"] == "user_123"
      assert event["traits"] == %{"name" => "Acme Inc", "plan" => "enterprise"}

      Client.shutdown(client)
    end

    test "works without user_id", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass)

      Client.group(client, "org_456", %{plan: "pro"})
      Client.flush(client)

      [request] = Agent.get(requests, & &1)
      [event] = request["batch"]

      assert event["groupId"] == "org_456"
      refute Map.has_key?(event, "userId")

      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Batching Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "batching" do
    test "multiple events batched in single request", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass)

      Client.track(client, "Event 1", %{}, user_id: "u1")
      Client.identify(client, "u1", %{name: "Test"})
      Client.group(client, "org1", %{name: "Acme"}, user_id: "u1")
      Client.flush(client)

      all_requests = Agent.get(requests, & &1)
      assert length(all_requests) == 1, "Should send single HTTP request"

      [request] = all_requests
      assert length(request["batch"]) == 3, "Batch should contain 3 events"

      types = Enum.map(request["batch"], & &1["type"])
      assert types == ["track", "identify", "group"]

      Client.shutdown(client)
    end

    test "respects max_batch_size", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass, max_batch_size: 3)

      for i <- 1..5, do: Client.track(client, "Event #{i}", %{}, user_id: "u1")
      Client.flush(client)

      all_requests = Agent.get(requests, & &1)
      # 5 events with max_batch_size=3 should result in 2 requests (3 + 2)
      assert length(all_requests) == 2
      assert length(Enum.at(all_requests, 0)["batch"]) == 3
      assert length(Enum.at(all_requests, 1)["batch"]) == 2

      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Authentication Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "authentication" do
    test "sends bearer token header", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert auth_header == ["Bearer test-write-key"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
      end)

      client = create_client(bypass)
      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)
      Client.shutdown(client)
    end

    test "sends json content type", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        content_type = Plug.Conn.get_req_header(conn, "content-type")
        assert content_type == ["application/json"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
      end)

      client = create_client(bypass)
      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)
      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Custom Endpoint Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "custom endpoint" do
    test "uses custom endpoint", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass, endpoint: "http://localhost:#{bypass.port}")

      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)

      all_requests = Agent.get(requests, & &1)
      assert length(all_requests) == 1

      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Error Handling Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "error handling" do
    test "retries on server error", %{bypass: bypass} do
      {:ok, call_count} = Agent.start_link(fn -> 0 end)

      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        count = Agent.get_and_update(call_count, fn c -> {c + 1, c + 1} end)

        if count < 3 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(503, ~s({"error":"Service unavailable"}))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
        end
      end)

      client = create_client(bypass, retry_initial_delay: 1, retry_max_attempts: 5)
      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)

      final_count = Agent.get(call_count, & &1)
      assert final_count == 3, "Should retry until success"

      Client.shutdown(client)
      Agent.stop(call_count)
    end

    test "does not retry on 400 bad request", %{bypass: bypass} do
      {:ok, call_count} = Agent.start_link(fn -> 0 end)

      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        Agent.update(call_count, &(&1 + 1))

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, ~s({"error":"Bad request"}))
      end)

      client = create_client(bypass, retry_max_attempts: 5)
      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)

      final_count = Agent.get(call_count, & &1)
      assert final_count == 1, "Should not retry 400 errors"

      Client.shutdown(client)
      Agent.stop(call_count)
    end

    test "does not retry on 401 unauthorized", %{bypass: bypass} do
      {:ok, call_count} = Agent.start_link(fn -> 0 end)

      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        Agent.update(call_count, &(&1 + 1))

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, ~s({"error":"Unauthorized"}))
      end)

      client = create_client(bypass, retry_max_attempts: 5)
      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)

      final_count = Agent.get(call_count, & &1)
      assert final_count == 1, "Should not retry 401 errors"

      Client.shutdown(client)
      Agent.stop(call_count)
    end

    test "retries on rate limit (429)", %{bypass: bypass} do
      {:ok, call_count} = Agent.start_link(fn -> 0 end)

      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        count = Agent.get_and_update(call_count, fn c -> {c + 1, c + 1} end)

        if count < 2 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(429, ~s({"error":"Rate limited"}))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
        end
      end)

      client = create_client(bypass, retry_initial_delay: 1, retry_max_attempts: 5)
      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)

      final_count = Agent.get(call_count, & &1)
      assert final_count == 2, "Should retry on 429"

      Client.shutdown(client)
      Agent.stop(call_count)
    end

    test "invokes on_error callback after max retries on network error" do
      test_pid = self()

      # Use an invalid port that will cause connection refused
      {:ok, client} =
        Client.start_link(
          write_key: "test-key",
          endpoint: "http://localhost:1",
          flush_interval: 999_999_999,
          flush_on_shutdown: false,
          retry_initial_delay: 1,
          retry_max_attempts: 2,
          on_error: fn error, _events ->
            send(test_pid, {:error, error})
          end
        )

      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)

      # Should receive error callback after retries exhausted
      assert_receive {:error, error}, 5000
      assert error.message =~ "Network error"

      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Shutdown Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "shutdown" do
    test "flushes remaining events", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)

      {:ok, client} =
        Client.start_link(
          write_key: "test-write-key",
          endpoint: "http://localhost:#{bypass.port}",
          flush_interval: 999_999_999,
          flush_on_shutdown: true
        )

      Client.track(client, "Event 1", %{}, user_id: "u1")
      Client.track(client, "Event 2", %{}, user_id: "u1")
      Client.shutdown(client)

      all_requests = Agent.get(requests, & &1)
      assert length(all_requests) == 1

      [request] = all_requests
      assert length(request["batch"]) == 2
    end

    test "events ignored after shutdown", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)

      {:ok, client} =
        Client.start_link(
          write_key: "test-write-key",
          endpoint: "http://localhost:#{bypass.port}",
          flush_interval: 999_999_999,
          flush_on_shutdown: true
        )

      Client.track(client, "Before", %{}, user_id: "u1")
      Client.shutdown(client)
      Client.track(client, "After", %{}, user_id: "u1")
      Client.flush(client)

      all_requests = Agent.get(requests, & &1)
      assert length(all_requests) == 1

      [request] = all_requests
      assert length(request["batch"]) == 1
      assert hd(request["batch"])["event"] == "Before"
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Configuration Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "configuration" do
    test "requires write_key" do
      Process.flag(:trap_exit, true)
      assert {:error, %Klime.ConfigurationError{message: "write_key is required"}} =
               Client.start_link([])
    end

    test "requires non-empty write_key" do
      Process.flag(:trap_exit, true)
      assert {:error, %Klime.ConfigurationError{message: "write_key is required"}} =
               Client.start_link(write_key: "")
    end

    test "child_spec returns valid supervisor spec" do
      spec = Client.child_spec(write_key: "test-key", name: MyKlime)

      assert spec.id == MyKlime
      assert spec.start == {Client, :start_link, [[write_key: "test-key", name: MyKlime]]}
      assert spec.type == :worker
      assert spec.restart == :permanent
      assert spec.shutdown == 5000
    end

    test "child_spec uses module name as default id" do
      spec = Client.child_spec(write_key: "test-key")

      assert spec.id == Client
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Queue Size Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "queue_size/1" do
    test "returns current queue size", %{bypass: bypass} do
      client = create_client(bypass)

      assert Client.queue_size(client) == 0

      Client.track(client, "Event 1", %{}, user_id: "u1")
      assert Client.queue_size(client) == 1

      Client.track(client, "Event 2", %{}, user_id: "u1")
      assert Client.queue_size(client) == 2

      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Queue Limits Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "queue limits" do
    test "drops oldest event when queue is full", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass, max_queue_size: 3)

      # Fill queue beyond capacity
      Client.track(client, "Event 1", %{}, user_id: "u1")
      Client.track(client, "Event 2", %{}, user_id: "u1")
      Client.track(client, "Event 3", %{}, user_id: "u1")
      Client.track(client, "Event 4", %{}, user_id: "u1")

      # Queue should still be at max size (oldest dropped)
      assert Client.queue_size(client) == 3

      Client.flush(client)

      [request] = Agent.get(requests, & &1)
      events = request["batch"]

      # Should have events 2, 3, 4 (event 1 was dropped)
      event_names = Enum.map(events, & &1["event"])
      assert event_names == ["Event 2", "Event 3", "Event 4"]

      Client.shutdown(client)
    end

    test "flushes immediately when batch size reached", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass, max_batch_size: 2)

      # Track events equal to batch size - should trigger immediate flush
      Client.track(client, "Event 1", %{}, user_id: "u1")
      Client.track(client, "Event 2", %{}, user_id: "u1")

      # Give a moment for the flush to complete
      Process.sleep(50)

      # Should have flushed automatically without explicit flush call
      all_requests = Agent.get(requests, & &1)
      assert length(all_requests) == 1
      assert length(hd(all_requests)["batch"]) == 2

      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Callback Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "callbacks" do
    test "invokes on_success callback", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
      end)

      {:ok, client} =
        Client.start_link(
          write_key: "test-write-key",
          endpoint: "http://localhost:#{bypass.port}",
          flush_interval: 999_999_999,
          flush_on_shutdown: false,
          on_success: fn response ->
            send(test_pid, {:success, response})
          end
        )

      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)

      assert_receive {:success, response}, 1000
      assert response.accepted == 1
      assert response.failed == 0

      Client.shutdown(client)
    end

    test "invokes on_error callback", %{bypass: bypass} do
      test_pid = self()

      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, ~s({"error":"Bad request"}))
      end)

      {:ok, client} =
        Client.start_link(
          write_key: "test-write-key",
          endpoint: "http://localhost:#{bypass.port}",
          flush_interval: 999_999_999,
          flush_on_shutdown: false,
          on_error: fn error, _events ->
            send(test_pid, {:error, error})
          end
        )

      Client.track(client, "Test", %{}, user_id: "u1")
      Client.flush(client)

      assert_receive {:error, error}, 1000
      assert error.status_code == 400

      Client.shutdown(client)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Sync (Bang) Method Tests
  # ─────────────────────────────────────────────────────────────────────────────

  describe "track!/4 (sync)" do
    test "returns {:ok, response} on success", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
      end)

      client = create_client(bypass)
      result = Client.track!(client, "Test Event", %{key: "value"}, user_id: "u1")

      assert {:ok, response} = result
      assert response.accepted == 1
      assert response.failed == 0

      Client.shutdown(client)
    end

    test "returns {:error, error} on failure", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, ~s({"error":"Bad request"}))
      end)

      client = create_client(bypass)
      result = Client.track!(client, "Test Event", %{}, user_id: "u1")

      assert {:error, error} = result
      assert error.status_code == 400

      Client.shutdown(client)
    end

    test "sends event immediately without batching", %{bypass: bypass, requests: requests} do
      setup_bypass_success(bypass, requests)
      client = create_client(bypass)

      # track! should send immediately
      {:ok, _} = Client.track!(client, "Sync Event", %{}, user_id: "u1")

      # Should have been sent immediately (1 request)
      all_requests = Agent.get(requests, & &1)
      assert length(all_requests) == 1
      assert hd(all_requests)["batch"] |> hd() |> Map.get("event") == "Sync Event"

      Client.shutdown(client)
    end
  end

  describe "identify!/3 (sync)" do
    test "returns {:ok, response} on success", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
      end)

      client = create_client(bypass)
      result = Client.identify!(client, "user_123", %{email: "test@example.com"})

      assert {:ok, response} = result
      assert response.accepted == 1

      Client.shutdown(client)
    end
  end

  describe "group!/4 (sync)" do
    test "returns {:ok, response} on success", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/v1/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"status":"ok","accepted":1,"failed":0}))
      end)

      client = create_client(bypass)
      result = Client.group!(client, "org_456", %{name: "Acme"}, user_id: "user_123")

      assert {:ok, response} = result
      assert response.accepted == 1

      Client.shutdown(client)
    end
  end

  describe "sync methods when shutdown" do
    test "returns error when client is shutdown", %{bypass: bypass} do
      client = create_client(bypass)
      Client.shutdown(client)

      result = Client.track!(client, "Test", %{}, user_id: "u1")
      assert {:error, error} = result
      assert error.message == "Client is shutdown"
    end
  end
end
