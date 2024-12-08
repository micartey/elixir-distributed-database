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
      # Assign claims to the connection for downstream use
      # TODO: Figure out how to use this on downstream
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
end
