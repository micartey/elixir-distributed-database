defmodule Router.RouterTest do
  use ExUnit.Case
  use Plug.Test
  alias Router.Router, as: AppRouter
  alias User.User
  alias Router.Auth.JwtConfig

  @opts AppRouter.init([])

  setup do
    on_exit(fn ->
      # Cleanup users that might exist
      ["testuser", "admin"]
      |> Enum.each(&User.delete_user/1)

      # Cleanup topics
      ["topic1", "test_topic"]
      |> Enum.each(&Database.Database.delete_topic/1)
    end)

    # Create a test user
    User.create_user("testuser", "password123", :READ)
    User.add_topic("testuser", "test_topic")

    # Create an admin user
    User.create_user("admin", "adminpass", :ADMIN)

    :ok
  end

  describe "POST /auth" do
    test "returns 200 and a token with valid credentials" do
      body = %{username: "testuser", password: "password123"}

      conn =
        conn(:post, "/auth", Poison.encode!(body))
        |> AppRouter.call(@opts)

      assert conn.status == 200
      resp = Poison.decode!(conn.resp_body)
      assert Map.has_key?(resp, "token")

      # Verify token content
      {:ok, claims} = JwtConfig.verify_and_validate(resp["token"])
      assert claims["permission"] == "READ"
      assert "test_topic" in claims["topics"]
    end

    test "returns 401 with invalid credentials" do
      body = %{username: "testuser", password: "wrongpassword"}

      conn =
        conn(:post, "/auth", Poison.encode!(body))
        |> AppRouter.call(@opts)

      assert conn.status == 401
      resp = Poison.decode!(conn.resp_body)
      assert resp["error"] == "User not found or incorrect password"
    end
  end

  describe "GET /get" do
    test "returns 200 and value for authorized user and topic" do
      # First put some data
      User.add_topic("testuser", "topic1")

      {:ok, token, _} =
        JwtConfig.generate_token(%{"permission" => "READ", "topics" => ["topic1"]})

      # Put data via Database directly to avoid dependency on /put for this test
      Database.Database.get_worker("key1")
      |> GenServer.call({:put, "topic1", "key1", "value1"})

      conn =
        conn(:get, "/get?topic=topic1&key=key1")
        |> put_req_header("authorization", "Bearer #{token}")
        |> AppRouter.call(@opts)

      assert conn.status == 200
      resp = Poison.decode!(conn.resp_body)
      # result is a Database.Entry struct
      assert resp["key"] == "key1"
      assert List.first(resp["history"])["data"] == "value1"
    end

    test "returns 403 for unauthorized topic" do
      {:ok, token, _} =
        JwtConfig.generate_token(%{"permission" => "READ", "topics" => ["topic1"]})

      conn =
        conn(:get, "/get?topic=secret_topic&key=key1")
        |> put_req_header("authorization", "Bearer #{token}")
        |> AppRouter.call(@opts)

      assert conn.status == 403
      resp = Poison.decode!(conn.resp_body)
      assert resp["error"] == "Forbidden"
    end

    test "returns 401 when no token is provided" do
      conn =
        conn(:get, "/get?topic=topic1&key=key1")
        |> AppRouter.call(@opts)

      assert conn.status == 401
    end
  end

  describe "PUT /put" do
    test "returns 200 after successful put" do
      {:ok, token, _} =
        JwtConfig.generate_token(%{"permission" => "WRITE", "topics" => ["topic1"]})

      body = %{topic: "topic1", key: "key2", value: "value2"}

      conn =
        conn(:put, "/put", Poison.encode!(body))
        |> put_req_header("authorization", "Bearer #{token}")
        |> AppRouter.call(@opts)

      assert conn.status == 200

      # Verify it was actually put
      val =
        Database.Database.get_worker("key2")
        |> GenServer.call({:get, "topic1", "key2"})

      assert val.key == "key2"
      assert List.first(val.history).data == "value2"
    end

    test "returns 409 for optimistic locking conflict" do
      {:ok, token, _} =
        JwtConfig.generate_token(%{"permission" => "WRITE", "topics" => ["topic1"]})

      # Initialize value
      Database.Database.get_worker("key3")
      |> GenServer.call({:put, "topic1", "key3", "initial"})

      # Try to update with wrong old_value
      body = %{topic: "topic1", key: "key3", value: "new_value", old_value: "wrong_old"}

      conn =
        conn(:put, "/put", Poison.encode!(body))
        |> put_req_header("authorization", "Bearer #{token}")
        |> AppRouter.call(@opts)

      assert conn.status == 409
      resp = Poison.decode!(conn.resp_body)
      assert resp["error"] == "Conflict"
    end

    test "returns 200 for correct optimistic locking" do
      {:ok, token, _} =
        JwtConfig.generate_token(%{"permission" => "WRITE", "topics" => ["topic1"]})

      # Initialize value
      Database.Database.get_worker("key4")
      |> GenServer.call({:put, "topic1", "key4", "initial"})

      # Update with correct old_value
      body = %{topic: "topic1", key: "key4", value: "new_value", old_value: "initial"}

      conn =
        conn(:put, "/put", Poison.encode!(body))
        |> put_req_header("authorization", "Bearer #{token}")
        |> AppRouter.call(@opts)

      assert conn.status == 200
    end
  end

  test "returns 404 for unknown route" do
    # /auth is exempted from auth plug, but /unknown is not.
    # We need a token to even reach the 404 match if it's not exempted.
    {:ok, token, _} = JwtConfig.generate_token(%{"permission" => "READ", "topics" => []})

    conn =
      conn(:get, "/unknown")
      |> put_req_header("authorization", "Bearer #{token}")
      |> AppRouter.call(@opts)

    assert conn.status == 404
    assert conn.resp_body == "oops"
  end
end
