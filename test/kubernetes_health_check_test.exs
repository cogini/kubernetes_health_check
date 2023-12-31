defmodule KubernetesHealthCheckTest do
  use ExUnit.Case
  doctest KubernetesHealthCheck

  test "greets the world" do
    assert KubernetesHealthCheck.hello() == :world
  end
end
