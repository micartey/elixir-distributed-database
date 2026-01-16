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
      else
        []
      end

    IO.inspect(state)

    GenServer.start_link(__MODULE__, state, name: :user_server)
  end

  def handle_call({:create_user, %User{} = user}, _caller_pid, state) do
    username_taken =
      state
      |> Enum.filter(&(&1.username == user.username))
      |> Enum.any?()

    # Check if username is alreay taken and password is long enough.
    # Create user and append to state if conditions are meet
    cond do
      username_taken ->
        Logger.error("Username #{user.username} is alreay taken")
        {:reply, nil, state}

      String.length(user.password) < 8 ->
        Logger.error("Password is to short")
        {:reply, nil, state}

      true ->
        Logger.info("User #{user.username} created")

        state = [user | state]
        store_object(@storage, state)

        {:reply, user, state}
    end
  end

  def handle_call({:auth_user, username, password}, _caller_pid, state) do
    user =
      state
      |> Enum.find(&User.is_valid?(&1, username, password))

    # Check if user is authenticated (exsits)
    # Return false if not
    case user do
      nil ->
        Logger.error("Failed authentication: #{username}")
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

  def handle_call({:get_state}, _caller_pid, state) do
    {:reply, state, state}
  end

  def create_user(username, password, permission) do
    user = User.new(username, password, permission)

    callback = fn {pid, user} ->
      pid
      |> GenServer.call({:create_user, user})
    end

    # Create user local
    callback.({Process.whereis(:user_server), user})

    # Replicate data on other nodes
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

    # Delete user local
    callback.(Process.whereis(:user_server))

    # Replicate on other nodes
    Node.list()
    |> Enum.each(fn node ->
      pid = :rpc.call(node, Process, :whereis, [:user_server])
      callback.(pid)
    end)
  end

  @doc """
  Check if user credentials are valid
  """
  def auth_user(username, password) when is_binary(username) and is_binary(password) do
    # Search locally
    # callback returns either nil or the User
    callback = fn {pid, username, password} ->
      pid
      |> GenServer.call({:auth_user, username, password})
    end

    case callback.({Process.whereis(:user_server), username, password}) do
      # Search on other nodes as this node does not contain the data
      nil ->
        Node.list()
        |> Enum.find(fn node ->
          pid = :rpc.call(node, Process, :whereis, [:user_server])
          callback.({pid, username, password})
        end)

      # Simply return the user
      user ->
        user
    end
  end
end
