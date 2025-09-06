defmodule User.User do
  alias User.User

  defstruct username: nil, password: nil, permission: :READ

  def new(username, password, permission) when is_atom(permission) do
    %User{
      username: username,
      password: password,
      permission: permission
    }
  end

  def is_valid?(%User{} = user, username, password) do
    String.equivalent?(username, user.username) && String.equivalent?(password, user.password)
  end

  def is_valid?(%{username: username, password: password} = user, username, password) do
    String.equivalent?(username, user.username) && String.equivalent?(password, user.password)
  end
end
