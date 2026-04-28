defmodule TelecoreWeb.Api.V1.UserController do
  @moduledoc """
  JSON API for user registration and "current user" lookup.

  Error response shapes:
    * `%{"error" => "<code>"}` — non-field-level failures (400, 401)
    * `%{"errors" => %{"<field>" => ["<msg>"]}}` — changeset validation (422)
  Clients can branch on `error` vs `errors` key presence.
  """

  use TelecoreWeb, :controller

  alias Telecore.Accounts

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user_with_password(user_params) do
      {:ok, user} ->
        token = Accounts.create_user_api_token(user)

        conn
        |> put_status(:created)
        |> json(%{token: token, user: render_user(user)})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_user_params"})
  end

  def me(conn, _params) do
    json(conn, %{user: render_user(conn.assigns.current_user)})
  end

  defp render_user(user) do
    %{id: user.id, email: user.email}
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
