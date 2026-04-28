defmodule TelecoreWeb.Api.V1.SessionControllerTest do
  use TelecoreWeb.ConnCase, async: true

  import Telecore.AccountsFixtures

  alias Telecore.Accounts

  describe "POST /api/v1/sessions" do
    test "returns a token for valid credentials", %{conn: conn} do
      user = user_fixture() |> set_password()
      password = valid_user_password()

      conn =
        post(conn, ~p"/api/v1/sessions", %{
          "email" => user.email,
          "password" => password
        })

      assert %{"token" => token, "user" => %{"id" => id, "email" => email}} =
               json_response(conn, 201)

      assert id == user.id
      assert email == user.email
      assert is_binary(token)
      refute is_nil(Accounts.fetch_user_by_api_token(token))
    end

    test "returns 401 for wrong password", %{conn: conn} do
      user = user_fixture() |> set_password()

      conn =
        post(conn, ~p"/api/v1/sessions", %{
          "email" => user.email,
          "password" => "wrongpassword"
        })

      assert %{"error" => "invalid_credentials"} = json_response(conn, 401)
    end

    test "returns 400 when params are missing", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/sessions", %{})
      assert %{"error" => "missing_credentials"} = json_response(conn, 400)
    end
  end

  describe "DELETE /api/v1/sessions" do
    test "revokes the current token", %{conn: conn} do
      # No `set_password` here: logout exercises only the API-token path,
      # so the user doesn't need a usable password.
      user = user_fixture()
      token = Accounts.create_user_api_token(user)

      conn = put_req_header(conn, "authorization", "Bearer " <> token)
      conn = delete(conn, ~p"/api/v1/sessions")

      assert response(conn, 204)
      assert is_nil(Accounts.fetch_user_by_api_token(token))
    end

    test "returns 401 without auth header", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/sessions")
      assert json_response(conn, 401)
    end
  end
end
