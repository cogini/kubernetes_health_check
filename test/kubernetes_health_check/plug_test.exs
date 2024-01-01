defmodule KubernetesHealthCheck.PlugTest do
  use ExUnit.Case
  use Plug.Test

  defmodule HealthErrorMessage do
    def basic do
      {:error, :basic}
    end

    def startup do
      {:error, :startup}
    end

    def liveness do
      {:error, :liveness}
    end

    def readiness do
      {:error, :readiness}
    end
  end

  defmodule HealthErrorCode do
    def basic do
      {:error, {500, :basic}}
    end

    def startup do
      {:error, {500, :startup}}
    end

    def liveness do
      {:error, {500, :liveness}}
    end

    def readiness do
      {:error, {500, :readiness}}
    end
  end

  defmodule DefaultsPlug do
    use Plug.Builder

    plug KubernetesHealthCheck.Plug
    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule PathPlug do
    use Plug.Builder

    plug KubernetesHealthCheck.Plug, base_path: "/foo"

    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule CustomPathPlug do
    use Plug.Builder

    plug KubernetesHealthCheck.Plug,
      mod: HealthErrorMessage,
      base_path: "/health",
      startup_path: "/startup",
      liveness_path: "/liveness",
      readiness_path: "/readiness"

    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule ErrorMessagePlug do
    use Plug.Builder

    plug KubernetesHealthCheck.Plug, mod: HealthErrorMessage

    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule ErrorCodePlug do
    use Plug.Builder

    plug KubernetesHealthCheck.Plug, mod: HealthErrorCode

    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  describe "low level" do
    test "request_path does not match" do
      conn = conn(:get, "/")
      assert KubernetesHealthCheck.Plug.call(conn, KubernetesHealthCheck.Plug.init([])) == conn
    end

    test "/healthz request" do
      conn = conn(:get, "/healthz")
      result = KubernetesHealthCheck.Plug.call(conn, KubernetesHealthCheck.Plug.init([]))
      assert result.status == 200
      assert result.resp_body == "OK"
    end

    test "/healthz/startup request" do
      conn = conn(:get, "/healthz/startup")
      result = KubernetesHealthCheck.Plug.call(conn, KubernetesHealthCheck.Plug.init([]))
      assert result.status == 200
      assert result.resp_body == "OK"
    end

    test "/healthz/liveness request" do
      conn = conn(:get, "/healthz/liveness")
      result = KubernetesHealthCheck.Plug.call(conn, KubernetesHealthCheck.Plug.init([]))
      assert result.status == 200
      assert result.resp_body == "OK"
    end

    test "/healthz/readiness request" do
      conn = conn(:get, "/healthz/readiness")
      result = KubernetesHealthCheck.Plug.call(conn, KubernetesHealthCheck.Plug.init([]))
      assert result.status == 200
      assert result.resp_body == "OK"
    end
  end

  describe "path" do
    test "request_path does not match" do
      conn = conn(:get, "/")
      result = PathPlug.call(conn, [])
      assert result.resp_body == "Passthrough"
    end

    test "/healthz request" do
      conn = conn(:get, "/foo")
      result = PathPlug.call(conn, [])
      assert result.status == 200
      assert result.resp_body == "OK"
    end

    test "/healthz/startup request" do
      conn = conn(:get, "/foo/startup")
      result = PathPlug.call(conn, [])
      assert result.status == 200
      assert result.resp_body == "OK"
    end

    test "/healthz/liveness request" do
      conn = conn(:get, "/foo/liveness")
      result = PathPlug.call(conn, [])
      assert result.status == 200
      assert result.resp_body == "OK"
    end

    test "/healthz/readiness request" do
      conn = conn(:get, "/foo/readiness")
      result = PathPlug.call(conn, [])
      assert result.status == 200
      assert result.resp_body == "OK"
    end
  end

  describe "error message mod" do
    test "request_path does not match" do
      conn = conn(:get, "/")
      result = ErrorMessagePlug.call(conn, [])
      assert result.resp_body == "Passthrough"
    end

    test "/healthz request" do
      conn = conn(:get, "/healthz")
      result = ErrorMessagePlug.call(conn, [])
      assert result.status == 503
      assert result.resp_body == ":basic"
    end

    test "/healthz/startup request" do
      conn = conn(:get, "/healthz/startup")
      result = ErrorMessagePlug.call(conn, [])
      assert result.status == 503
      assert result.resp_body == ":startup"
    end

    test "/healthz/liveness request" do
      conn = conn(:get, "/healthz/liveness")
      result = ErrorMessagePlug.call(conn, [])
      assert result.status == 503
      assert result.resp_body == ":liveness"
    end

    test "/healthz/readiness request" do
      conn = conn(:get, "/healthz/readiness")
      result = ErrorMessagePlug.call(conn, [])
      assert result.status == 503
      assert result.resp_body == ":readiness"
    end
  end

  describe "error code mod" do
    test "request_path does not match" do
      conn = conn(:get, "/")
      result = ErrorCodePlug.call(conn, [])
      assert result.resp_body == "Passthrough"
    end

    test "/healthz request" do
      conn = conn(:get, "/healthz")
      result = ErrorCodePlug.call(conn, [])
      assert result.status == 500
      assert result.resp_body == ":basic"
    end

    test "/healthz/startup request" do
      conn = conn(:get, "/healthz/startup")
      result = ErrorCodePlug.call(conn, [])
      assert result.status == 500
      assert result.resp_body == ":startup"
    end

    test "/healthz/liveness request" do
      conn = conn(:get, "/healthz/liveness")
      result = ErrorCodePlug.call(conn, [])
      assert result.status == 500
      assert result.resp_body == ":liveness"
    end

    test "/healthz/readiness request" do
      conn = conn(:get, "/healthz/readiness")
      result = ErrorCodePlug.call(conn, [])
      assert result.status == 500
      assert result.resp_body == ":readiness"
    end
  end

  describe "custom paths" do
    test "request_path does not match" do
      conn = conn(:get, "/")
      result = CustomPathPlug.call(conn, [])
      assert result.resp_body == "Passthrough"
    end

    test "custom basic request" do
      conn = conn(:get, "/health")
      result = CustomPathPlug.call(conn, [])
      assert result.status == 503
      assert result.resp_body == ":basic"
    end

    test "custom startup request" do
      conn = conn(:get, "/startup")
      result = CustomPathPlug.call(conn, [])
      assert result.status == 503
      assert result.resp_body == ":startup"
    end

    test "custom liveness request" do
      conn = conn(:get, "/liveness")
      result = CustomPathPlug.call(conn, [])
      assert result.status == 503
      assert result.resp_body == ":liveness"
    end

    test "custom readiness request" do
      conn = conn(:get, "/readiness")
      result = CustomPathPlug.call(conn, [])
      assert result.status == 503
      assert result.resp_body == ":readiness"
    end
  end
end
