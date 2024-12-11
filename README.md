# kubernetes_health_check

Health check Plug with Kubernetes semantics.

Kubernetes has well defined semantics for how health checks should behave,
distinguishing between between startup, liveness, and readiness:

**Liveness** is the core health check. It determines whether the app is alive
and able to respond to requests. It should be relatively fast, as it is called
frequently, but should include checks for dependencies, e.g. whether the app
can connect to a database or back end service. If the liveness check fails for
a specified period, Kubernetes kills and replaces the instance.

**Startup** checks whether the app has finished booting up. It is useful when
the app may take significant time to start, e.g. because it is loading data
from a cache. Separating this from liveness allows us to use different
timeouts, rather than making the liveness timeout long enough to support
startup. Once startup has completed successfully, Kubernetes does not call it
again, it uses the liveness check.

**Readiness** checks whether the app should receive requests. Kubernetes uses
it to decide whether to route traffic to the the instance. If the readiness
probe fails, Kubernetes doesn't kill and restart the container, instead it
marks the pod as "unready" and stops sending traffic to it, e.g. in the
ingress. It is useful to temporarily stop serving traffic, e.g. when the
instance is overloaded or it has transient problems connecting to a back end
service.

See this blog post for more background:
https://www.cogini.com/blog/kubernetes-health-checks-for-elixir-apps/

Links:

* https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
* https://shyr.io/blog/kubernetes-health-probes-elixir

Following is an example Kubernetes deployment yaml configuration:

```yaml
  startupProbe:
    httpGet:
      path: /healthz/startup
      port: http
    periodSeconds: 3
    failureThreshold: 5

  livenessProbe:
    httpGet:
      path: /healthz/liveness
      port: http
    periodSeconds: 10
    failureThreshold: 6

  readinessProbe:
    httpGet:
      path: /healthz/readiness
      port: http
    periodSeconds: 10
    failureThreshold: 1
  ```

## Installation

Add the package to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kubernetes_health_check, "~> 0.7.0"}
  ]
end
```

## Usage

Add `KubernetesHealthCheck.Plug` to your endpoint or router.
Place it at the very top to avoid noise in your logs from health checks.

```elixir
plug KubernetesHealthCheck.Plug,
  mod: Foo.Health,
  base_path: "/healthz"
```

Options:

* `:mod` - Callback module which implements the health checks for the app, default `KubernetesHealthCheck`
* `:base_path` - Base request_path for health checks, default `/healthz`
* `:startup_path` - Path for startup check, default `<base_path>/startup`
* `:liveness_path` - Path for liveness check, default `<base_path>/liveness`
* `:readiness_path` - Path for readiness check, default `<base_path>/readiness`

Add a module which provides the app-specific health checks.
Following is an example:

```elixir
defmodule Example.Health do
  @moduledoc """
  Collect app status for Kubernetes health checks.
  """
  alias Example.Repo

  @app :example
  @repos Application.compile_env(@app, :ecto_repos) || []

  @type check_return ::
          :ok
          | {:error, {status_code :: non_neg_integer(), reason :: binary()}}
          | {:error, reason :: binary()}

  @doc """
  Check if the app has finished booting up.

  This returns app status for the Kubernetes `startupProbe`.
  Kubernetes checks this probe repeatedly until it returns a successful
  response. After that, Kubernetes switches to executing the other two probes.
  If the app fails to successfully start before the `failureThreshold` time is
  reached, Kubernetes kills the container and restarts it.

  For example, this check might return OK when the app has started the
  web-server, connected to a DB, connected to external services, and performed
  initial setup tasks such as loading a large cache.
  """
  @spec startup :: check_return()
  def startup do
    # Return error if there are available migrations which have not been executed.
    # This supports deployment to AWS ECS using the following strategy:
    # https://engineering.instawork.com/elegant-database-migrations-on-ecs-74f3487da99f
    #
    # By default Elixir migrations lock the database migration table, so they
    # will only run from a single instance.
    migrations =
      @repos
      |> Enum.map(&Ecto.Migrator.migrations/1)
      |> List.flatten()

    if Enum.empty?(migrations) do
      liveness()
    else
      {:error, "Database not migrated"}
    end
  end

  @doc """
  Check if the app is alive and working properly.

  This returns app status for the Kubernetes `livenessProbe`.
  Kubernetes continuously checks if the app is alive and working as expected.
  If it crashes or becomes unresponsive for a specified period of time,
  Kubernetes kills and replaces the container.

  This check should be lightweight, only determining if the server is
  responding to requests and can connect to the DB.
  """
  @spec liveness :: check_return()
  def liveness do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1") do
      {:ok, %{num_rows: 1, rows: [[1]]}} ->
        :ok

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  rescue
    e ->
      {:error, inspect(e)}
  end

  @doc """
  Check if app should be serving public traffic.

  This returns app status for the Kubernetes `readinessProbe`.
  Kubernetes continuously checks if the app should serve traffic. If the
  readiness probe fails, Kubernetes doesn't kill and restart the container,
  instead it marks the pod as "unready" and stops sending traffic to it, e.g.
  in the ingress.

  This is useful to temporarily stop serving requests. For example, if the app
  gets a timeout connecting to a back end service, it might return an error for
  the readiness probe. After multiple failed attempts, it would switch to
  returning false for the `livenessProbe`, triggering a restart.

  Similarly, the app might return an error if it is overloaded, shedding
  traffic until it has caught up.
  """
  @spec readiness :: check_return()
  def readiness do
    liveness()
  end

  @spec basic :: check_return()
  def basic do
    :ok
  end
end
```

Docs can be found at <https://hexdocs.pm/kubernetes_health_check>.
