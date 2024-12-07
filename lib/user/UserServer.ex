defmodule User.UserServer do
  require Logger
  alias User.User
  alias Utilities.Serialize
  import Serialize
  use GenServer, restart: :permanent

  @storage "users.bin"

  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link(_) do
    state = if File.exists?(@storage) do
      retrieve_object(@storage)
    else
      []
    end

    IO.inspect state

    GenServer.start_link(__MODULE__, state, name: :user_server)
  end

  def handle_call({:create_user, %User{} = user}, _caller_pid, state) do

    username_taken = state
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

    authenticated = state
    |> Enum.filter(&(User.is_valid?(&1, username, password)))
    |> Enum.any?()

    # Check if user is authenticated (exsits)
    # Return false if not
    cond do
      authenticated ->
        {:reply, true, state}

      true ->
        Logger.error("Failed authentication: #{username}")

        {:reply, false, state}
    end
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

  @doc """
  Check if user credentials are valid
  """
  @spec auth_user?(binary(), binary()) :: boolean()
  def auth_user?(username, password) when is_binary(username) and is_binary(password) do
    # Search locally
    callback = fn {pid, username, password} ->
      pid
      |> GenServer.call({:auth_user, username, password})
    end

    cond do
      callback.({Process.whereis(:user_server), username, password}) -> true

      # Search on other nodes
      # TODO: Replicate data if found would probably be a good idea
      true ->
        Node.list()
        |> Enum.any?(fn node ->
          pid = :rpc.call(node, Process, :whereis, [:user_server])
          callback.({pid, username, password})
        end)
    end
  end
end
