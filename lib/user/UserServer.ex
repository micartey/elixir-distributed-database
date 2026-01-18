defmodule User.UserServer do
  require Logger
  alias User.User
  alias Utilities.Serialize
  import Serialize
  use GenServer, restart: :permanent

  @storage "users.json"

  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link(_) do
    state =
      if File.exists?(@storage) do
        retrieve_object(@storage)
        |> Enum.map(fn
          %User{} = user -> user
          map when is_map(map) -> struct(User, map)
          other -> other
        end)
      else
        []
      end

    IO.inspect(state)

    GenServer.start_link(__MODULE__, state, name: :user_server)
  end

  def handle_call({:create_user, %User{} = user}, _caller_pid, state) do
    username_taken = Enum.any?(state, &(&1.username == user.username))

    cond do
      username_taken ->
        Logger.error("Username #{user.username} is alreay taken")
        {:reply, nil, state}

      String.length(user.password) < 8 ->
        Logger.error("Password is to short")
        {:reply, nil, state}

      true ->
        Logger.info("User #{user.username} created")
        new_state = [user | state]
        store_object(@storage, new_state)
        {:reply, user, new_state}
    end
  end

  def handle_call({:update_user, %User{} = merged_user}, _caller_pid, state) do
    user_index = Enum.find_index(state, &(&1.username == merged_user.username))

    new_state =
      if user_index do
        List.replace_at(state, user_index, merged_user)
      else
        [merged_user | state]
      end

    store_object(@storage, new_state)
    {:reply, :ok, new_state}
  end

  def handle_call({:auth_user, username, password}, _caller_pid, state) do
    user = Enum.find(state, &User.is_valid?(&1, username, password))

    case user do
      nil ->
        {:reply, nil, state}

      user ->
        {:reply, user, state}
    end
  end

  def handle_call({:delete_user, username}, _caller_pid, state) do
    user_exists = Enum.any?(state, &(&1.username == username))

    if user_exists do
      Logger.info("User #{username} deleted")
      new_state = Enum.filter(state, &(&1.username != username))

      store_object(@storage, new_state)

      {:reply, :ok, new_state}
    else
      Logger.error("User #{username} not found")
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:add_topic, username, topic}, _caller_pid, state) do
    user_index = Enum.find_index(state, &(&1.username == username))

    if user_index do
      user = Enum.at(state, user_index)
      new_user = %User{user | topics: Enum.uniq([topic | user.topics])}
      new_state = List.replace_at(state, user_index, new_user)

      store_object(@storage, new_state)

      Logger.info("Topic #{topic} added to user #{username}")
      {:reply, {:ok, new_user}, new_state}
    else
      Logger.error("User #{username} not found")
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:remove_topic, username, topic}, _caller_pid, state) do
    user_index = Enum.find_index(state, &(&1.username == username))

    if user_index do
      user = Enum.at(state, user_index)
      new_user = %User{user | topics: List.delete(user.topics, topic)}
      new_state = List.replace_at(state, user_index, new_user)

      store_object(@storage, new_state)

      Logger.info("Topic #{topic} removed from user #{username}")
      {:reply, {:ok, new_user}, new_state}
    else
      Logger.error("User #{username} not found")
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:get_state}, _caller_pid, state) do
    {:reply, state, state}
  end

  def handle_call({:sync}, _caller_pid, state) do
    all_users = get_all_users(state)

    new_state =
      all_users
      |> Enum.group_by(& &1.username)
      |> Enum.map(fn {_username, users} ->
        first = List.first(users)
        merged_topics = users |> Enum.flat_map(& &1.topics) |> Enum.uniq()
        %{first | topics: merged_topics}
      end)

    store_object(@storage, new_state)
    {:reply, {:ok, new_state}, new_state}
  end

  def get_all_users(state) do
    remote_users =
      Node.list()
      |> Enum.flat_map(fn node ->
        remote_server_pid = :rpc.call(node, Process, :whereis, [:user_server])

        if remote_server_pid do
          :rpc.call(node, GenServer, :call, [remote_server_pid, {:get_state}])
        else
          []
        end
      end)

    (state ++ remote_users)
    |> Enum.filter(& &1)
  end
end
