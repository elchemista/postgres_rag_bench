# Phoenix Framework — Practical Guide and Command Cheatsheet

A developer-first field guide to Phoenix and LiveView. Covers project setup, Plug, routing, controllers, LiveView, templating, Ecto, PubSub, Presence, telemetry, testing, deployment, and command references.

---

## 0) Quickstart

```bash
# Install Phoenix project scaffold
mix phx.new my_app
cd my_app

# Set up deps and DB
mix deps.get
mix ecto.create

# Run the dev server
mix phx.server
# or
iex -S mix phx.server
```

Key directories:

```
lib/
  my_app/            # business logic (contexts)
  my_app_web/        # web interface (controllers, LiveView, components, router)
priv/
  repo/migrations/   # Ecto migrations
assets/              # JS/CSS build pipeline
```

---

## 1) Anatomy of a Phoenix App

- **Endpoint**: top-level Plug pipeline. Handles sockets, sessions, static assets, request logging, parsers.
- **Router**: declares routes, pipelines, scopes. For HTTP and LiveView.
- **Controllers**: action modules for request/response cycles.
- **LiveView**: server-rendered components with realtime DOM updates over WebSocket.
- **Components**: reusable HEEx UI building blocks.
- **Ecto**: database access. Schemas, changesets, queries, Repo.
- **PubSub**: message passing across nodes or processes.
- **Presence**: user/session tracking over PubSub.

---

## 2) Endpoint and Plug

`Endpoint` is a Plug. You can add plugs globally. Typical file: `lib/my_app_web/endpoint.ex`.

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  plug Phoenix.LiveDashboard.RequestLogger
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, store: :cookie, key: "_my_app_key", signing_salt: "..."

  plug MyAppWeb.Router
end
```

### Plug basics

A Plug is a module implementing two callbacks:

```elixir
def init(opts), do: opts

def call(conn, opts) do
  # mutate the conn then return it
  conn
end
```

**Common Plug.Conn functions**:

- `assign/3`, `get_assign/2`
- `put_resp_header/3`, `delete_resp_header/2`
- `put_status/2`
- `send_resp/3`, `send_file/3`
- `halt/1`
- `fetch_session/1`, `get_session/2`, `put_session/3`, `configure_session/2`, `clear_session/1`
- `fetch_cookies/1`, `put_resp_cookie/4`, `delete_resp_cookie/3`

**Adding custom plugs**

```elixir
defmodule MyAppWeb.RequireAuthPlug do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user], do: conn, else: conn |> redirect(to: ~p"/login") |> halt()
  end
end
```

Use it in endpoint or router pipelines.

---

## 3) Router

The Router declares pipelines and routes.

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    resources "/posts", PostController

    live "/live/clock", ClockLive
  end

  scope "/api", MyAppWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end
end
```

**Router macros**

- `get/3`, `post/3`, `put/3`, `patch/3`, `delete/3`
- `resources/4`
- `scope/2-3`
- `pipe_through/1`
- `forward/2-3`
- `live/2-3`, `live_session/3`

**Verified routes**

Phoenix ships the `~p` sigil for compile-time verified path helpers:

```elixir
redirect(conn, to: ~p"/posts/#{post}")
link to: ~p"/users/#{user}"
```

---

## 4) Controllers and HTML rendering

Controllers are thin. They delegate to contexts and render views or components.

```elixir
defmodule MyAppWeb.PostController do
  use MyAppWeb, :controller
  alias MyApp.Blog

  def index(conn, _params) do
    posts = Blog.list_posts()
    render(conn, :index, posts: posts)
  end

  def show(conn, %{"id" => id}) do
    post = Blog.get_post!(id)
    render(conn, :show, post: post)
  end

  def create(conn, %{"post" => attrs}) do
    case Blog.create_post(attrs) do
      {:ok, post} -> redirect(conn, to: ~p"/posts/#{post}")
      {:error, changeset} -> render(conn, :new, changeset: changeset)
    end
  end
end
```

Phoenix 1.7+ uses **HEEx** templates and **function components**. Traditional `View` modules are optional.

```elixir
# lib/my_app_web/controllers/post_html.ex

defmodule MyAppWeb.PostHTML do
  use MyAppWeb, :html
  embed_templates "post_html/*"
end
```

Templates live in `lib/my_app_web/controllers/post_html/` by default.

---

## 5) LiveView

Server-rendered HTML with realtime updates, no custom JS required for most cases.

```elixir
defmodule MyAppWeb.CounterLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def render(assigns) do
    ~H"""
    <h1>Count: <%= @count %></h1>
    <.button phx-click="inc">+1</.button>
    <.button phx-click="dec">-1</.button>
    """
  end

  def handle_event("inc", _params, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}
  def handle_event("dec", _params, socket), do: {:noreply, update(socket, :count, &(&1 - 1))}
end
```

### LiveView lifecycle

- `mount/3`: initialize assigns. When `connected?(socket)` is false, you are in the static render phase.
- `handle_params/3`: params for live navigation.
- `handle_event/3`: client events. `phx-click`, `phx-submit`, `phx-change`, `phx-blur`, `phx-focus`.
- `handle_info/2`: messages from processes or PubSub.
- `render/1`: HEEx returns.

### Assigns and updates

- `assign/3`, `assign_new/3`, `update/3`
- `temporary_assigns` to reduce diff size for large lists
- `stream/3` and `stream_insert/3` for append/prepend list UIs

### Components

- **Function components**:

```elixir
attr :href, :string, required: true
slot :inner_block

def my_link(assigns) do
  ~H"""
  <a href={@href} class="text-indigo-600"><%= render_slot(@inner_block) %></a>
  """
end
```

- **Stateful components** (`use Phoenix.LiveComponent`), keep local state and events.

### Live navigation

- `live_redirect/2` and `live_patch/2` for in-place route changes
- `push_navigate/2`, `push_patch/2` from the socket

### JS interop

Use `Phoenix.LiveView.JS` helpers:

```elixir
alias Phoenix.LiveView.JS

~H"""
<button phx-click={JS.toggle(to: "#panel")}>Toggle</button>
<div id="panel" class="hidden">...</div>
"""
```

Common helpers: `JS.navigate/1`, `JS.patch/1`, `JS.push/2`, `JS.toggle/1`, `JS.add_class/2`, `JS.remove_class/2`, `JS.show/1`, `JS.hide/1`, `JS.dispatch/2`.

### Uploads

```elixir
def mount(_,_,socket) do
  {:ok, allow_upload(socket, :avatar, accept: ~w(.jpg .png), max_entries: 1)}
end

def handle_event("save", _, socket) do
  consume_uploaded_entries(socket, :avatar, fn %{path: path}, _ ->
    File.cp!(path, "/tmp/avatar")
    {:ok, "/tmp/avatar"}
  end)
  {:noreply, socket}
end
```

### Presence with LiveView

Track users, broadcast diffs.

```elixir
# in your LiveView mount
:ok = Phoenix.PubSub.subscribe(MyApp.PubSub, "room:123")
{:ok, _} = MyAppWeb.Presence.track(self(), "room:123", socket.id, %{online_at: System.system_time(:second)})
```

React to diffs in `handle_info/2`.

---

## 6) HEEx and Components

- HEEx validates HTML at compile time.
- `attr` and `slot` declare component API.
- Use function components for reuse.
- Import your core UI in `my_app_web.ex` for global availability.

```elixir
# lib/my_app_web/components/core_components.ex

defmodule MyAppWeb.CoreComponents do
  use Phoenix.Component

  attr :type, :string, default: "button"
  slot :inner_block

  def button(assigns) do
    ~H"""
    <button type={@type} class="btn"><%= render_slot(@inner_block) %></button>
    """
  end
end
```

---

## 7) Ecto: Schemas, Changesets, Queries

### Schema

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :body, :string
    has_many :comments, MyApp.Blog.Comment
    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body])
    |> validate_required([:title])
    |> validate_length(:title, min: 3)
  end
end
```

### Contexts

Group domain logic in contexts.

```elixir
defmodule MyApp.Blog do
  import Ecto.Query
  alias MyApp.Repo
  alias MyApp.Blog.Post

  def list_posts, do: Repo.all(from p in Post, order_by: [desc: p.inserted_at])
  def get_post!(id), do: Repo.get!(Post, id)
  def create_post(attrs), do: %Post{} |> Post.changeset(attrs) |> Repo.insert()
  def update_post(post, attrs), do: post |> Post.changeset(attrs) |> Repo.update()
  def delete_post(post), do: Repo.delete(post)
end
```

### Queries

```elixir
import Ecto.Query

q = from p in Post, where: ilike(p.title, ^"%phoenix%"), select: {p.id, p.title}
Repo.all(q)
```

### Transactions and Multi

```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:post, Post.changeset(%Post{}, attrs))
|> Ecto.Multi.run(:audit, fn _repo, %{post: post} ->
  MyApp.Audit.log(:create, post)
end)
|> Repo.transaction()
```

### Migrations

```elixir
mix ecto.gen.migration create_posts

# priv/repo/migrations/*_create_posts.exs
def change do
  create table(:posts) do
    add :title, :string, null: false
    add :body, :text
    timestamps()
  end
  create index(:posts, [:inserted_at])
end
```

Run with `mix ecto.migrate`.

---

## 8) Channels and PubSub

LiveView covers many cases, but Channels are still useful for custom websocket protocols.

```elixir
defmodule MyAppWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> _id, _params, socket), do: {:ok, socket}
  def handle_in("ping", payload, socket), do: {:reply, {:ok, payload}, socket}
end
```

PubSub:

```elixir
Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
Phoenix.PubSub.broadcast(MyApp.PubSub, "topic", {:event, data})
```

---

## 9) Presence

Track online users per topic with automatic diffs.

```elixir
defmodule MyAppWeb.Presence do
  use Phoenix.Presence, otp_app: :my_app, pubsub_server: MyApp.PubSub
end
```

```elixir
MyAppWeb.Presence.track(self(), "room:lobby", user_id, %{meta: %{name: name}})
MyAppWeb.Presence.list("room:lobby")
```

Handle presence diffs in LiveView or Channels.

---

## 10) Security

- Enable CSRF protection in browser pipeline.
- Sign and encrypt session cookies as needed.
- Use `:put_secure_browser_headers`.
- Validate params at the boundary. Use changesets for input.
- Rate-limit where needed (e.g., via plug or reverse proxy).
- Enforce content security policy in endpoint or reverse proxy.

---

## 11) Telemetry and Metrics

Phoenix and Ecto emit telemetry events. Attach handlers or export to Prometheus/StatsD.

```elixir
:telemetry.attach("ecto-logger", [:my_app, :repo, :query], fn _event, measurements, metadata, _config ->
  IO.inspect({measurements.total_time, metadata.query})
end, nil)
```

Use libraries like `telemetry_metrics` and `telemetry_poller` for aggregation.

---

## 12) Testing

Use ExUnit. Useful helpers:

- `ConnCase` for controller/router tests
- `DataCase` for Ecto logic
- `Phoenix.LiveViewTest` for LiveViews

```elixir
# test/my_app_web/controllers/post_controller_test.exs
use MyAppWeb.ConnCase, async: true

test "GET /posts lists posts", %{conn: conn} do
  conn = get(conn, ~p"/posts")
  assert html_response(conn, 200) =~ "Posts"
end
```

```elixir
# test/my_app_web/live/counter_live_test.exs
use MyAppWeb.ConnCase
import Phoenix.LiveViewTest

test "increments", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/live/counter")
  view |> element("button", "+1") |> render_click()
  assert render(view) =~ "Count: 1"
end
```

Factories: use `ex_machina` or simple helper modules.

---

## 13) Auth

Generate a full auth stack with tokens, sessions, reset, confirmation:

```bash
mix phx.gen.auth Accounts User users
mix ecto.migrate
```

This adds routes, controllers, LiveViews, emails, plugs.

---

## 14) Asset pipeline

Phoenix ships with esbuild and Tailwind configurations.

- Dev: watchers run via endpoint config
- Prod: `mix assets.deploy` builds and digests

```bash
mix assets.deploy
# runs npm build, tailwind, and mix phx.digest
```

Serve static files via `Plug.Static` in endpoint.

---

## 15) Deployment

### Releases

```bash
MIX_ENV=prod mix release
_build/prod/rel/my_app/bin/my_app start
```

Set env via `RELEASE_*` or runtime.exs.

### Runtime config (`config/runtime.exs`)

```elixir
config :my_app, MyApp.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE" || "10"))

config :my_app, MyAppWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST", "example.com"), port: 443],
  http: [ip: {0,0,0,0,0,0,0,0}, port: String.to_integer(System.get_env("PORT" || "4000"))],
  secret_key_base: System.get_env("SECRET_KEY_BASE")
```

### Reverse proxy

- Use Fly.io, Gigalixir, Render, or nginx. Ensure websockets are proxied.

---

## 16) Mix tasks you will use often

```bash
mix phx.new my_app                # scaffold project
mix phx.new --live my_app        # scaffold with LiveView ready
mix phx.server                   # run server
iex -S mix phx.server            # server with IEx

mix deps.get                     # fetch deps
mix deps.update --all            # update deps

mix ecto.create                  # create DB
mix ecto.migrate                 # run migrations
mix ecto.rollback                # rollback migration
mix ecto.gen.migration NAME      # new migration

mix phx.gen.html Ctx Sch tbl ... # HTML scaffolds
mix phx.gen.json Ctx Sch tbl ... # JSON API
mix phx.gen.live Ctx Sch tbl ... # LiveView CRUD
mix phx.gen.context Ctx Sch tbl  # context + schema
mix phx.gen.auth Accounts User users  # auth

mix phx.routes                   # print routes
mix assets.deploy                # build assets + digest
mix phx.digest                   # static digest
```

---

## 17) Router patterns and scopes

```elixir
scope "/admin", MyAppWeb.Admin do
  pipe_through [:browser, :require_authenticated]
  resources "/users", UserController
end

# API versioning
scope "/api", MyAppWeb.Api do
  pipe_through :api
  scope "/v1" do
    get "/posts", PostController, :index
  end
  scope "/v2" do
    get "/posts", PostV2Controller, :index
  end
end

# Forwarding to external plugs
forward "/dashboard", Phoenix.LiveDashboard,
  metrics: MyAppWeb.Telemetry
```

---

## 18) Controller patterns

### Fallback controller

```elixir
action_fallback MyAppWeb.FallbackController
```

```elixir
defmodule MyAppWeb.FallbackController do
  use MyAppWeb, :controller

  def call(conn, {:error, :not_found}), do: send_resp(conn, 404, "not found")
  def call(conn, {:error, %Ecto.Changeset{} = cs}), do: render(conn, :error, changeset: cs)
end
```

### Plugs per action

```elixir
plug :require_admin when action in [:delete]
```

---

## 19) LiveView patterns

### Form with changesets

```elixir
def render(assigns) do
  ~H"""
  <.simple_form for={@form} phx-change="validate" phx-submit="save">
    <.input field={@form[:title]} label="Title" />
    <.input field={@form[:body]} type="textarea" label="Body" />
    <.button>Save</.button>
  </.simple_form>
  """
end

def mount(_,_,socket) do
  cs = Post.changeset(%Post{}, %{})
  {:ok, assign(socket, form: to_form(cs))}
end

def handle_event("validate", %{"post" => params}, socket) do
  cs = %Post{} |> Post.changeset(params) |> Map.put(:action, :validate)
  {:noreply, assign(socket, form: to_form(cs))}
end

def handle_event("save", %{"post" => params}, socket) do
  case Blog.create_post(params) do
    {:ok, post} -> {:noreply, socket |> put_flash(:info, "Saved") |> push_navigate(to: ~p"/posts/#{post}")}
    {:error, cs} -> {:noreply, assign(socket, form: to_form(cs))}
  end
end
```

### Streams for lists

```elixir
def mount(_,_,socket) do
  {:ok, stream(socket, :posts, Blog.list_posts())}
end

# later when an item is created
{:noreply, stream_insert(socket, :posts, post)}
```

### Live layout and sessions

```elixir
# router
live_session :default, on_mount: [MyAppWeb.RequireAuthLive] do
  live "/settings", SettingsLive
end
```

---

## 20) JSON APIs

Use `render/3` with `:json` or declare `accepts` plug.

```elixir
defmodule MyAppWeb.Api.PostController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    json(conn, %{data: [%{id: 1, title: "Hi"}]})
  end
end
```

Or use `phx.gen.json`.

---

## 21) Error handling

- Use `FallbackController` for pattern-based errors.
- `put_status/2` to set HTTP status.
- Custom error pages via `MyAppWeb.ErrorHTML` and `ErrorJSON`.

---

## 22) Observability quick hooks

- Endpoint logs include request ids.
- Attach telemetry to Ecto and Phoenix events.
- Use LiveDashboard in dev/prod behind auth.

```elixir
# router development-only
if Application.compile_env(:my_app, :dev_routes) do
  import Phoenix.LiveDashboard.Router
  scope "/dev" do
    pipe_through :browser
    live_dashboard "/dashboard", metrics: MyAppWeb.Telemetry
  end
end
```

---

## 23) Performance tips

- Use `temporary_assigns` for big lists.
- Use `stream` for append-heavy feeds.
- Preload associations to avoid N+1.
- Cache computed content with ETS or process state where appropriate.
- Prefer LiveView over heavy client JS when possible.

---

## 24) Security checklist

- HTTPS everywhere.
- Set `secret_key_base` from env.
- CSRF on browser pipeline.
- SameSite and secure cookies.
- Validate and cast all inputs.
- Limit uploads and validate content types.
- Use rate limiting and auth on sensitive routes.

---

## 25) Debugging

- `IEx.pry` in dev to break and inspect.
- `IO.inspect/2` with labels.
- `:observer.start()` for processes.
- `mix phx.routes` to confirm routing.

---

## 26) Common code snippets

### Plug: require JSON content type

```elixir
defmodule MyAppWeb.Plugs.RequireJSON do
  import Plug.Conn

  def init(opts), do: opts
  def call(%{req_headers: headers} = conn, _opts) do
    case List.keyfind(headers, "content-type", 0) do
      {_, "application/json" <> _} -> conn
      _ -> conn |> send_resp(415, "Unsupported Media Type") |> halt()
    end
  end
end
```

### Router: nested resources

```elixir
resources "/posts", PostController do
  resources "/comments", CommentController, only: [:create, :delete]
end
```

### Ecto: upsert

```elixir
Repo.insert(changeset, on_conflict: {:replace, [:title]}, conflict_target: :unique_key)
```

### LiveView: throttle event

```elixir
<button phx-click="like" phx-throttle="like">Like</button>
```

### LiveView: debounce input

```elixir
<input type="text" name="q" phx-debounce="300" phx-change="search" />
```

---

## 27) Cheatsheets

### Plug.Conn

- `assign/3`, `put_session/3`, `get_session/2`, `clear_session/1`
- `put_resp_header/3`, `delete_resp_header/2`
- `put_status/2`, `send_resp/3`, `halt/1`

### Router

- `get/3`, `post/3`, `resources/4`, `live/2-3`
- `scope/2-3`, `pipe_through/1`, `forward/2-3`
- `~p"..."` verified routes

### Controller

- `render/3`, `redirect/2`, `json/2`, `put_flash/3`

### LiveView

- Lifecycle: `mount/3`, `handle_params/3`, `handle_event/3`, `handle_info/2`, `render/1`
- Helpers: `assign/3`, `update/3`, `put_flash/3`, `push_navigate/2`, `push_patch/2`
- JS: `JS.navigate/1`, `JS.patch/1`, `JS.push/2`, `JS.toggle/1`
- Streams: `stream/3`, `stream_insert/3`, `stream_delete/3`

### Ecto

- `Repo.all/1`, `Repo.get/2`, `Repo.insert/1`, `Repo.update/1`, `Repo.delete/1`, `Repo.transaction/1`
- Changesets: `cast/3`, `validate_required/2`, `validate_length/3`, `unique_constraint/3`
- Query: `from/2`, `where/3`, `order_by/3`, `join/5`, `select/3`, `preload/3`

### Mix

- `mix phx.new`, `mix phx.server`, `mix phx.routes`
- `mix ecto.create`, `mix ecto.migrate`, `mix ecto.rollback`
- `mix phx.gen.html`, `mix phx.gen.json`, `mix phx.gen.live`, `mix phx.gen.context`, `mix phx.gen.auth`
- `mix assets.deploy`, `mix phx.digest`

---

## 28) Minimal end-to-end example

Create a blog with LiveView listing and CRUD via contexts.

```bash
mix phx.new blog --live
cd blog
mix ecto.create
mix phx.gen.live Blog Post posts title:string body:text
mix ecto.migrate
mix phx.server
```

Visit `/posts`. You get index, new, edit, show with LiveView.

---

## 29) Production checklist

- Runtime config in `runtime.exs`
- DATABASE_URL and SECRET_KEY_BASE set
- Migrations run on deploy
- Reverse proxy websocket support
- Health endpoint for load balancer
- Telemetry export wired
- Logs JSON formatted in prod
- Asset digests built

---

## 30) Where features live

- `lib/my_app/` — contexts, domain
- `lib/my_app_web/router.ex` — routes
- `lib/my_app_web/endpoint.ex` — global plugs and sockets
- `lib/my_app_web/controllers/*` — actions and HTML modules
- `lib/my_app_web/live/*` — LiveViews and components
- `lib/my_app_web/components/*` — reusable UI components
- `priv/repo/*` — migration and seeds

---

## 31) Gotchas

- Don’t do heavy work in `render/1`. Use assigns prepared in `mount/3` or handlers.
- Always return updated socket. Never mutate in place.
- Use `put_flash/3` only on redirects or same-render cycles.
- Preload associations in contexts to avoid N+1.
- Don’t block in LiveView handlers. Offload to Tasks and return.

---

## 32) Example custom pipeline

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :admin_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug MyAppWeb.RequireAdminPlug
  end

  scope "/admin", MyAppWeb.Admin do
    pipe_through :admin_browser
    live "/dashboard", DashboardLive
  end
end
```

---

## 33) Example socket and channels wiring

```elixir
# endpoint.ex
socket "/socket", MyAppWeb.UserSocket, websocket: [connect_info: [:user_agent, :peer_data]]
```

```elixir
defmodule MyAppWeb.UserSocket do
  use Phoenix.Socket
  channel "room:*", MyAppWeb.RoomChannel
  def connect(_params, socket, _connect_info), do: {:ok, socket}
  def id(_socket), do: nil
end
```

---

## 34) Seeds and fixtures

```elixir
# priv/repo/seeds.exs
alias MyApp.{Repo}
alias MyApp.Blog.Post

Repo.insert!(%Post{title: "Hello", body: "Phoenix"})
```

Run via `mix run priv/repo/seeds.exs`.

---

## 35) IEx helpers

```elixir
iex -S mix
recompile()      # recompile project
h Enum.map       # docs
i some_term      # introspect
:observer.start
```

---

## 36) Internationalization

- Use Gettext. Extract with `mix gettext.extract` and merge with `mix gettext.merge`.

---

## 37) Mailers

- Use Swoosh. Configure adapter and call `MyApp.Mailer.deliver(email)`.

---

## 38) Background jobs

- Use Oban or Broadway for jobs and pipelines.

---

## 39) Rate limiting example (ETS token bucket sketch)

```elixir
defmodule MyApp.RateLimit do
  @table :rate_limit
  def setup, do: :ets.new(@table, [:named_table, :public, read_concurrency: true])
  def allow?(key, limit_per_minute \\ 60) do
    now = System.system_time(:second)
    :ets.update_counter(@table, {key, div(now, 60)}, {3, 1}, {{key, div(now, 60)}, 0, 0}) <= limit_per_minute
  end
end
```

Wire as a plug to guard endpoints.

---

## 40) Final advice

- Keep controllers thin. Move logic to contexts.
- Prefer LiveView for interactive UIs.
- Test contexts deeply. Feature test LiveViews and controllers.
- Observe telemetry. Fix slow queries first.
- Keep pipelines explicit. Add plugs only where needed.

---

Use this guide as a working reference. Expand with your own patterns as the codebase grows.

