defmodule KubernetesHealthCheck.Plug do
  if Code.ensure_loaded?(Plug) do
    @moduledoc """
    Plug to return health check results.

    It calls the app module which does the actual checking.

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

    Add the plug to your endpoint or router.
    It whould normally be placed above the logger to avoid noise in your logs
    from health checks.

    ```
    plug KubernetesHealthCheck.Plug,
      mod: KubernetesHealthCheck.Health,
      base_path: "/healthz"
    ```

    ### Init Options

    - `:mod` - Callback module which implements the health checks for the app, default `KubernetesHealthCheck`
    - `:base_path` - "Base request_path for health checks, default "/healthz"
    - `:startup_path` - "Path for startup check, default "<base_path>/startup"
    - `:liveness_path` - "Path for liveness check, default "<base_path>/liveness"
    - `:readiness_path` - "Path for readiness check, default "<base_path>/readiness"
    """
    import Plug.Conn

    def init(opts) do
      base_path = Keyword.get(opts, :base_path, "/healthz")
      startup_path = Keyword.get(opts, :startup_path, "#{base_path}/startup")
      liveness_path = Keyword.get(opts, :liveness_path, "#{base_path}/liveness")
      readiness_path = Keyword.get(opts, :readiness_path, "#{base_path}/readiness")

      %{
        mod: Keyword.get(opts, :mod, KubernetesHealthCheck),
        base_path: base_path,
        startup_path: startup_path,
        liveness_path: liveness_path,
        readiness_path: readiness_path
      }
    end

    def call(%Plug.Conn{request_path: rp} = conn, %{base_path: path, mod: mod}) when rp == path do
      case mod.basic() do
        :ok ->
          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(200, "OK")
          |> halt()

        {:error, {status_code, reason}} when is_integer(status_code) ->
          send_resp(conn, status_code, inspect(reason))
          |> halt()

        {:error, reason} ->
          conn
          |> send_resp(503, inspect(reason))
          |> halt()
      end
    end

    def call(%Plug.Conn{request_path: rp} = conn, %{startup_path: path, mod: mod}) when rp == path do
      case mod.startup() do
        :ok ->
          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(200, "OK")
          |> halt()

        {:error, {status_code, reason}} when is_integer(status_code) ->
          send_resp(conn, status_code, inspect(reason))
          |> halt()

        {:error, reason} ->
          conn
          |> send_resp(503, inspect(reason))
          |> halt()
      end
    end

    def call(%Plug.Conn{request_path: rp} = conn, %{liveness_path: path, mod: mod}) when rp == path do
      case mod.liveness() do
        :ok ->
          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(200, "OK")
          |> halt()

        {:error, {status_code, reason}} when is_integer(status_code) ->
          send_resp(conn, status_code, inspect(reason))
          |> halt()

        {:error, reason} ->
          conn
          |> send_resp(503, inspect(reason))
          |> halt()
      end
    end

    def call(%Plug.Conn{request_path: rp} = conn, %{readiness_path: path, mod: mod}) when rp == path do
      case mod.readiness() do
        :ok ->
          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(200, "OK")
          |> halt()

        {:error, {status_code, reason}} when is_integer(status_code) ->
          send_resp(conn, status_code, inspect(reason))
          |> halt()

        {:error, reason} ->
          conn
          |> send_resp(503, inspect(reason))
          |> halt()
      end
    end

    def call(conn, _opts), do: conn
  end
end
