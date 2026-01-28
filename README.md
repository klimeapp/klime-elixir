# klime

Klime SDK for Elixir.

## Installation

Add `klime` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:klime, "~> 1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

1. Configure in `config/config.exs`:

```elixir
config :klime,
  write_key: System.get_env("KLIME_WRITE_KEY")
```

2. Add to your supervision tree in `application.ex`:

```elixir
children = [
  Klime.Client
]
```

3. Track events anywhere in your app:

```elixir
# Identify a user
Klime.identify("user_123", %{
  email: "user@example.com",
  name: "Stefan"
})

# Track an event
Klime.track("Button Clicked", %{
  button_name: "Sign up",
  plan: "pro"
}, user_id: "user_123")

# Associate user with a group
Klime.group("org_456", %{
  name: "Acme Inc",
  plan: "enterprise"
}, user_id: "user_123")
```

## Installation Prompt

Copy and paste this prompt into Cursor, Copilot, or your favorite AI editor to integrate Klime:

```
Integrate Klime for customer analytics. Klime tracks user activity to identify which customers are healthy vs at risk of churning.

ANALYTICS MODES (determine which applies):
- Companies & Teams: Your customers are companies with multiple team members (SaaS, enterprise tools)
  → Use identify() + group() + track()
- Individual Customers: Your customers are individuals with private accounts (consumer apps, creator tools)
  → Use identify() + track() only (no group() needed)

KEY CONCEPTS:
- Every track() call requires either user_id OR group_id (no anonymous events)
- Use group_id alone for org-level events (webhooks, cron jobs, system metrics)
- group() links a user to a company AND sets company traits (only for Companies & Teams mode)
- Order doesn't matter - events before identify/group still get attributed correctly

SETUP:
1. Add to mix.exs: {:klime, "~> 1.0"}
2. Run: mix deps.get
3. Configure in config/config.exs:
   config :klime, write_key: System.get_env("KLIME_WRITE_KEY")
4. Add Klime.Client to your application.ex supervision tree:
   children = [Klime.Client]

BEST PRACTICES:
- Store write key in KLIME_WRITE_KEY environment variable
- Client automatically handles graceful shutdown when supervisor stops

# Identify users at signup/login:
Klime.identify("usr_abc123", %{email: "jane@acme.com", name: "Jane Smith"})

# Track key activities:
Klime.track("Report Generated", %{report_type: "revenue"}, user_id: "usr_abc123")
Klime.track("Feature Used", %{feature: "export", format: "csv"}, user_id: "usr_abc123")
Klime.track("Teammate Invited", %{role: "member"}, user_id: "usr_abc123")

# If Companies & Teams mode: link user to their company and set company traits
Klime.group("org_456", %{name: "Acme Inc", plan: "enterprise"}, user_id: "usr_abc123")

INTEGRATION WORKFLOW:

Phase 1: Discover
Explore the codebase to understand:
1. What framework is used? (Phoenix, plug, Bandit, etc.)
2. Where is user identity available? (e.g., conn.assigns.current_user, socket.assigns.current_user)
3. Is this Companies & Teams or Individual Customers?
   - Look for: organization, workspace, tenant, team, account schemas → Companies & Teams (use group())
   - No company/org concept, just individual users → Individual Customers (skip group())
4. Where do core user actions happen? (controllers, live views, channels, contexts)
5. Is there existing analytics? (search: segment, posthog, mixpanel, amplitude, track)
Match your integration style to the framework's conventions.

Phase 2: Instrument
Add these calls using idiomatic patterns for the framework:
- Add Klime.Client to application.ex supervision tree
- identify() in auth/login success handler
- group() when user-org association is established (Companies & Teams mode only)
- track() for key user actions (see below)

WHAT TO TRACK:
Active engagement (primary): feature usage, resource creation, collaboration, completing flows
Session signals (secondary): login/session start, dashboard access - distinguishes "low usage" from "churned"
Do NOT track: every request, health checks, plugs that run on every request, background jobs

Phase 3: Verify
Confirm: client in supervision tree, identify/group/track calls added

Phase 4: Summarize
Report what you added:
- Files modified and what was added to each
- Events being tracked (list event names and what triggers them)
- How user_id is obtained (and group_id if Companies & Teams mode)
- Any assumptions made or questions
```

## API Reference

### Configuration

Configure Klime in `config/config.exs`:

```elixir
config :klime,
  write_key: System.get_env("KLIME_WRITE_KEY"),        # Required
  endpoint: "https://i.klime.com",                     # Optional (default)
  flush_interval: 2000,                                # Optional: ms between flushes (default: 2000)
  max_batch_size: 20,                                  # Optional: max events per batch (default: 20, max: 100)
  max_queue_size: 1000,                                # Optional: max queued events (default: 1000)
  retry_max_attempts: 5,                               # Optional: max retry attempts (default: 5)
  retry_initial_delay: 1000,                           # Optional: initial retry delay in ms (default: 1000)
  flush_on_shutdown: true,                             # Optional: auto-flush on shutdown (default: true)
  on_error: &MyApp.Analytics.handle_error/2,           # Optional: callback for batch failures
  on_success: &MyApp.Analytics.handle_success/1       # Optional: callback for successful sends
```

### Starting the Client

Add to your supervision tree in `application.ex`:

```elixir
children = [
  Klime.Client
]
```

The client reads configuration from the application environment and registers itself as `:klime` by default.

### Methods

#### `track(event_name, properties \\ %{}, opts \\ [])`

Track an event. Events can be attributed in two ways:
- **User events**: Provide `user_id:` to track user activity (most common)
- **Group events**: Provide `group_id:` without `user_id:` for organization-level events

```elixir
# User event (most common)
Klime.track("Button Clicked", %{
  button_name: "Sign up",
  plan: "pro"
}, user_id: "user_123")

# Group event (for webhooks, cron jobs, system events)
Klime.track("Events Received", %{
  count: 100,
  source: "webhook"
}, group_id: "org_456")
```

> **Note**: The `group_id:` option can also be combined with `user_id:` for multi-tenant scenarios where you need to specify which organization context a user event occurred in.

### Synchronous Methods (Bang Methods)

For cases where you need guaranteed delivery or want to handle errors explicitly, use the synchronous versions that block until the event is sent:

```elixir
# Sync track - blocks until sent, returns {:ok, response} or {:error, error}
{:ok, response} = Klime.track!("Button Clicked", %{button: "signup"}, user_id: "user_123")

# Sync identify
{:ok, response} = Klime.identify!("user_123", %{email: "user@example.com"})

# Sync group
{:ok, response} = Klime.group!("org_456", %{name: "Acme Inc"}, user_id: "user_123")
```

These methods:
- Send the event immediately (no batching)
- Block until the HTTP request completes
- Return `{:ok, %Klime.BatchResponse{}}` on success
- Return `{:error, %Klime.SendError{}}` on failure

Use sync methods sparingly - they add latency to your code. The async methods are preferred for most use cases.

#### `identify(user_id, traits \\ %{})`

Identify a user with traits.

```elixir
Klime.identify("user_123", %{
  email: "user@example.com",
  name: "Stefan"
})
```

#### `group(group_id, traits \\ %{}, opts \\ [])`

Associate a user with a group and/or set group traits.

```elixir
# Associate user with a group and set group traits (most common)
Klime.group("org_456", %{
  name: "Acme Inc",
  plan: "enterprise"
}, user_id: "user_123")

# Just link a user to a group (traits already set or not needed)
Klime.group("org_456", %{}, user_id: "user_123")

# Just update group traits (e.g., from a webhook or background job)
Klime.group("org_456", %{
  plan: "enterprise",
  employee_count: 50
})
```

#### `flush()`

Manually flush queued events immediately.

```elixir
:ok = Klime.flush()
```

#### `shutdown()`

Gracefully shutdown the client, flushing remaining events.

```elixir
:ok = Klime.shutdown()
```

## Features

- **Automatic Batching**: Events are automatically batched and sent every 2 seconds or when the batch size reaches 20 events
- **Automatic Retries**: Failed requests are automatically retried with exponential backoff
- **Async & Sync Methods**: Use async methods for fire-and-forget, or sync (`track!`, `identify!`, `group!`) for guaranteed delivery
- **OTP Supervision**: GenServer-based client integrates naturally with OTP supervision trees
- **Application Config**: Configure once in `config.exs`, no need to pass client around
- **Plug Middleware**: Optional `Klime.Plug` for per-request flush in Phoenix/Plug apps
- **Graceful Shutdown**: Automatically flushes events when the supervisor stops (with `flush_on_shutdown: true`)
- **Callbacks**: `on_error` and `on_success` callbacks for monitoring
- **Minimal Dependencies**: Only requires `jason` for JSON encoding (`plug` optional for middleware)

## Performance

When you call `track/3`, `identify/2`, or `group/3`, the SDK:

1. Adds the event to an in-memory queue (microseconds)
2. Returns immediately without waiting for network I/O

Events are sent to Klime's servers asynchronously. This means:

- **No network blocking**: HTTP requests happen in the GenServer process, not your request handler
- **No latency impact**: Tracking calls add < 1ms to your request handling time
- **Automatic batching**: Events are queued and sent in batches (default: every 2 seconds or 20 events)

```elixir
# This returns immediately - no HTTP request is made here
Klime.track("Button Clicked", %{button: "signup"}, user_id: "user_123")

# Your code continues without waiting
json(conn, %{success: true})
```

The only blocking operation is `flush/0`, which waits for all queued events to be sent. This is typically only called during graceful shutdown.

## Configuration

### Default Values

- `flush_interval`: 2000ms
- `max_batch_size`: 20 events
- `max_queue_size`: 1000 events
- `retry_max_attempts`: 5 attempts
- `retry_initial_delay`: 1000ms
- `flush_on_shutdown`: true

### Callbacks

```elixir
# In config/config.exs
config :klime,
  write_key: System.get_env("KLIME_WRITE_KEY"),
  on_error: fn error, _events ->
    Logger.error("Klime error: #{inspect(error)}")
    Sentry.capture_exception(error)
  end,
  on_success: fn response ->
    Logger.info("Sent #{response.accepted} events")
  end
```

### Plug Middleware

For guaranteed per-request delivery, use `Klime.Plug` to flush events after each request:

```elixir
# In your Phoenix endpoint.ex or router.ex
plug Klime.Plug, client: :klime
```

> **Note**: This adds latency to every request as it waits for the flush.
> Only use this if you need guaranteed per-request delivery.
> For most use cases, the background worker is sufficient.

## Error Handling

The SDK automatically handles:

- **Transient errors** (429, 503, network failures): Retries with exponential backoff
- **Permanent errors** (400, 401): Logs error and drops event
- **Rate limiting**: Respects `Retry-After` header

## Size Limits

- Maximum event size: 200KB
- Maximum batch size: 10MB
- Maximum events per batch: 100

Events exceeding these limits are rejected and logged.

## Phoenix Example

```elixir
# config/config.exs
config :klime,
  write_key: System.get_env("KLIME_WRITE_KEY")
```

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyAppWeb.Endpoint,
      Klime.Client
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

```elixir
# lib/my_app_web/controllers/button_controller.ex
defmodule MyAppWeb.ButtonController do
  use MyAppWeb, :controller

  def click(conn, %{"button_name" => button_name}) do
    user_id = conn.assigns[:current_user] && conn.assigns.current_user.id

    Klime.track("Button Clicked", %{
      button_name: button_name
    }, user_id: user_id)

    json(conn, %{success: true})
  end
end
```

## Phoenix LiveView Example

```elixir
# lib/my_app_web/live/dashboard_live.ex
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    Klime.track("Dashboard Viewed", %{}, user_id: user.id)

    {:ok, socket}
  end

  def handle_event("export", %{"format" => format}, socket) do
    user = socket.assigns.current_user

    Klime.track("Export Clicked", %{format: format}, user_id: user.id)

    {:noreply, socket}
  end
end
```

## Requirements

- Elixir 1.15 or higher
- OTP 25 or higher
- `jason` ~> 1.4

## License

MIT
