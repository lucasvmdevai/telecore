defmodule TelecoreWeb.Api.V1.SessionController do
  @moduledoc """
  JSON API for Bearer-token sessions: exchange credentials for a token (login),
  and revoke the current token (logout).

  Error response shapes mirror `TelecoreWeb.Api.V1.UserController`:
  `%{"error" => "<code>"}` for non-field failures.
  """

  use TelecoreWeb, :controller

  alias Telecore.Accounts

  def create(conn, %{"email" => email, "password" => password})
      when is_binary(email) and is_binary(password) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %Accounts.User{} = user ->
        token = Accounts.create_user_api_token(user)

        conn
        |> put_status(:created)
        |> json(%{token: token, user: render_user(user)})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_credentials"})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_credentials"})
  end

  def delete(conn, _params) do
    Accounts.delete_user_api_token(conn.assigns.current_api_token)
    send_resp(conn, :no_content, "")
  end

  defp render_user(user) do
    %{id: user.id, email: user.email}
  end
end
