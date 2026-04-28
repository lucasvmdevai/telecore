defmodule TelecoreWeb.Plugs.ApiAuth do
  @moduledoc """
  Authenticates an API request using a Bearer token in the Authorization header.

  On success, assigns `:current_user` to the conn. On failure, halts the
  pipeline with a 401 JSON response.
  """
  import Plug.Conn

  alias Telecore.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with [bearer] <- get_req_header(conn, "authorization"),
         {:ok, token} <- extract_token(bearer),
         %Accounts.User{} = user <- Accounts.fetch_user_by_api_token(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_api_token, token)
    else
      _ -> unauthorized(conn)
    end
  end

  defp extract_token("Bearer " <> token) when byte_size(token) > 0, do: {:ok, token}
  defp extract_token(_), do: :error

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, ~s({"error":"unauthorized"}))
    |> halt()
  end
end
