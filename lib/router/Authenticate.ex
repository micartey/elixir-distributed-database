defmodule Router.Authenticate do
  import Plug.Conn
  alias Router.Auth.JwtConfig

  @exempt_paths ["/auth"]

  def init(opts), do: opts

  def call(conn, _opts) do
    if Enum.member?(@exempt_paths, conn.request_path) do
      # Bypass authentication for exempted paths
      conn
    else
      authenticate_request(conn)
    end
  end

  @doc """
  Get JWT from Authorization header and check if token is valid.
  If token is invalid, return 401 with error
  """
  def authenticate_request(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- verify_token(token) do
      # Convert permission to atom if it's a string, so we can use :ADMIN etc.
      claims =
        case claims["permission"] do
          p when is_binary(p) -> Map.put(claims, "permission", String.to_existing_atom(p))
          _ -> claims
        end

      # Assign claims to the connection for downstream use
      assign(conn, :current_user, claims)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Poison.encode!(%{error: "Unauthorized"}))
        |> halt()
    end
  end

  defp verify_token(token) do
    JwtConfig.verify_and_validate(token)
  end

  @doc """
  Check if user is authorized to access a certain topic with a required permission level.
  """
  def authorized?(claims, topic, required_permission \\ :READ) do
    permission = claims["permission"]
    topics = claims["topics"] || []

    # Admin has all permissions on all topics
    if permission == :ADMIN do
      true
    else
      # Check if user has access to the topic
      has_topic_access = Enum.member?(topics, topic)

      # Check if user has sufficient permission level
      has_permission_level =
        case {required_permission, permission} do
          {:READ, :READ} -> true
          {:READ, :WRITE} -> true
          {:WRITE, :WRITE} -> true
          _ -> false
        end

      has_topic_access and has_permission_level
    end
  end
end
