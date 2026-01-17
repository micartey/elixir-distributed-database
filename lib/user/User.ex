defmodule User.User do
  alias User.User

  defstruct username: nil, password: nil, permission: :READ, topics: []

  def new(username, password, permission) when is_atom(permission) do
    %User{
      username: username,
      password: password,
      permission: permission,
      topics: []
    }
  end

  def is_valid?(%User{} = user, username, password) do
    String.equivalent?(username, user.username) && String.equivalent?(password, user.password)
  end

  def is_valid?(%{username: username, password: password} = user, username, password) do
    String.equivalent?(username, user.username) && String.equivalent?(password, user.password)
  end

  def create_user(username, password, permission) do
    user = new(username, password, permission)

    callback = fn {pid, user} ->
      pid
      |> GenServer.call({:create_user, user})
    end

    callback.({Process.whereis(:user_server), user})

    Node.list()
    |> Enum.each(fn node ->
      pid = :rpc.call(node, Process, :whereis, [:user_server])
      callback.({pid, user})
    end)
  end

  def delete_user(username) do
    callback = fn pid ->
      GenServer.call(pid, {:delete_user, username})
    end

    callback.(Process.whereis(:user_server))

    Node.list()
    |> Enum.each(fn node ->
      pid = :rpc.call(node, Process, :whereis, [:user_server])
      callback.(pid)
    end)
  end

  def add_topic(username, topic) do
    callback = fn pid ->
      GenServer.call(pid, {:add_topic, username, topic})
    end

    callback.(Process.whereis(:user_server))

    Node.list()
    |> Enum.each(fn node ->
      pid = :rpc.call(node, Process, :whereis, [:user_server])
      callback.(pid)
    end)
  end

  def remove_topic(username, topic) do
    callback = fn pid ->
      GenServer.call(pid, {:remove_topic, username, topic})
    end

    callback.(Process.whereis(:user_server))

    Node.list()
    |> Enum.each(fn node ->
      pid = :rpc.call(node, Process, :whereis, [:user_server])
      callback.(pid)
    end)
  end

  def update_user(user) do
    callback = fn pid ->
      GenServer.call(pid, {:update_user, user})
    end

    callback.(Process.whereis(:user_server))

    Node.list()
    |> Enum.each(fn node ->
      pid = :rpc.call(node, Process, :whereis, [:user_server])
      if pid, do: callback.(pid)
    end)
  end

  def auth_user(username, password) when is_binary(username) and is_binary(password) do
    nodes = [node() | Node.list()]

    users =
      nodes
      |> Enum.map(fn node ->
        pid = :rpc.call(node, Process, :whereis, [:user_server])

        if pid do
          :rpc.call(node, GenServer, :call, [pid, {:auth_user, username, password}])
        end
      end)
      |> Enum.filter(& &1)

    case users do
      [] ->
        nil

      [first_user | _] ->
        merged_topics =
          users
          |> Enum.flat_map(& &1.topics)
          |> Enum.uniq()

        merged_user = %User{first_user | topics: merged_topics}
        update_user(merged_user)
        merged_user
    end
  end

  def reset_state do
    callback = fn pid ->
      GenServer.call(pid, {:reset_state})
    end

    callback.(Process.whereis(:user_server))

    Node.list()
    |> Enum.each(fn node ->
      pid = :rpc.call(node, Process, :whereis, [:user_server])
      if pid, do: callback.(pid)
    end)
  end
end
