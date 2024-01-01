defmodule KubernetesHealthCheckTest do
  use ExUnit.Case

  test "basic" do
    assert KubernetesHealthCheck.basic() == :ok
  end

  test "startup" do
    assert KubernetesHealthCheck.startup() == :ok
  end

  test "liveness" do
    assert KubernetesHealthCheck.liveness() == :ok
  end

  test "readiness" do
    assert KubernetesHealthCheck.readiness() == :ok
  end
end
