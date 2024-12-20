defmodule KubernetesHealthCheck do
  @moduledoc """
  Health check with Kubernetes semantics.

  This module is called by `KubernetesHealthCheck.Plug` to perform
  application-specific logic.

  To avoid bringing in excess dependencies, this module is a dummy that always
  returns `:ok`. You should implement your own functions that perform useful checks.
  """

  @type check_return ::
          :ok
          | {:error, {status_code :: non_neg_integer(), reason :: binary()}}
          | {:error, reason :: binary()}

  @doc """
  Basic health check.

  This is a sanity check that the app is running and responding to requests.
  It should always succeed.
  """
  @spec basic :: check_return()
  def basic do
    :ok
  end

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
    liveness()
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
    basic()
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
end
