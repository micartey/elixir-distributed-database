defmodule PermissionTest do
  use ExUnit.Case
  alias Eddb.Facade
  alias Router.Auth.JwtConfig
  use Plug.Test

  setup do
    on_exit(fn ->
      # Cleanup users that might exist
      ["admin", "user1", "user2", "user3", "reader", "writer"]
      |> Enum.each(&Facade.delete_user/1)

      # Cleanup topics
      ["secret", "public", "private", "news"]
      |> Enum.each(&Facade.delete_topic/1)
    end)

    :ok
  end

  test "admin can access any topic" do
    Facade.create_user("admin", "password123", :ADMIN)
    {:ok, token, _} = JwtConfig.generate_token(%{"permission" => "ADMIN", "topics" => []})

    conn =
      conn(:get, "/get?topic=secret&key=foo")
      |> put_req_header("authorization", "Bearer #{token}")
      |> Router.Router.call([])

    # Should not be 403. Might be 200 with nil if key doesn't exist
    assert conn.status != 403
  end

  test "regular user cannot access unassigned topic" do
    Facade.create_user("user1", "password123", :READ)
    {:ok, token, _} = JwtConfig.generate_token(%{"permission" => "READ", "topics" => ["public"]})

    conn =
      conn(:get, "/get?topic=private&key=foo")
      |> put_req_header("authorization", "Bearer #{token}")
      |> Router.Router.call([])

    assert conn.status == 403
    assert Poison.decode!(conn.resp_body)["error"] == "Forbidden"
  end

  test "regular user can access assigned topic" do
    Facade.create_user("user2", "password123", :READ)
    {:ok, token, _} = JwtConfig.generate_token(%{"permission" => "READ", "topics" => ["public"]})

    conn =
      conn(:get, "/get?topic=public&key=foo")
      |> put_req_header("authorization", "Bearer #{token}")
      |> Router.Router.call([])

    assert conn.status != 403
  end

  test "adding topic to user works" do
    Facade.create_user("user3", "password123", :READ)

    # Initially no topics
    users = Facade.list_users()
    user = Enum.find(users, &(&1.username == "user3"))
    assert user.topics == []

    # Add topic
    Facade.add_topic_to_user("user3", "news")

    users = Facade.list_users()
    user = Enum.find(users, &(&1.username == "user3"))
    assert "news" in user.topics

    # Remove topic
    Facade.remove_topic_from_user("user3", "news")
    users = Facade.list_users()
    user = Enum.find(users, &(&1.username == "user3"))
    assert "news" not in user.topics
  end

  test "user with READ permission cannot PUT" do
    Facade.create_user("reader", "password123", :READ)
    Facade.add_topic_to_user("reader", "public")
    {:ok, token, _} = JwtConfig.generate_token(%{"permission" => "READ", "topics" => ["public"]})

    body = %{topic: "public", key: "foo", value: "bar"}

    conn =
      conn(:put, "/put", Poison.encode!(body))
      |> put_req_header("authorization", "Bearer #{token}")
      |> Router.Router.call([])

    assert conn.status == 403
    assert Poison.decode!(conn.resp_body)["error"] == "Forbidden"
  end

  test "user with WRITE permission can PUT" do
    Facade.create_user("writer", "password123", :WRITE)
    Facade.add_topic_to_user("writer", "public")
    {:ok, token, _} = JwtConfig.generate_token(%{"permission" => "WRITE", "topics" => ["public"]})

    body = %{topic: "public", key: "foo", value: "bar"}

    conn =
      conn(:put, "/put", Poison.encode!(body))
      |> put_req_header("authorization", "Bearer #{token}")
      |> Router.Router.call([])

    assert conn.status == 200
  end
end
