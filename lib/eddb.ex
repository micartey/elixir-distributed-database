defmodule Eddb do
  alias User.UserServer
  alias Router.Router
  alias Database.Database
  alias Schedulers.SyncScheduler
  require Logger
  use Application

  def start(_type, _args) do
    children = [
      Database,
      ClusterMonitor,
      UserServer,
      SyncScheduler
    ]

    # Setting the 'EDDB_DISABLE_HTTP' env variable to ANY value will prevent the webserver to start
    # This might be usseful for tests or hosting multiple instances on the same server as integrated dependencies
    children =
      children ++
        case System.get_env("EDDB_DISABLE_HTTP") do
          nil -> [{Plug.Cowboy, scheme: :http, plug: Router, options: [port: 5342]}]
          _ -> []
        end

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: Eddb.Supervisor
    )
  end
end
