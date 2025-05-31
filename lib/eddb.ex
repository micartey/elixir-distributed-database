defmodule Eddb do
  alias User.UserServer
  alias Router.Router
  alias Database.Database
  use Application

  def start(_type, _args) do
    children = [
      Database,
      ClusterMonitor,
      UserServer,
      {Plug.Cowboy, scheme: :http, plug: Router, options: [port: 5342]}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: Eddb.Supervisor
    )
  end
end
