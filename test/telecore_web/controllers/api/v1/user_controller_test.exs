defmodule TelecoreWeb.Api.V1.UserControllerTest do
  use TelecoreWeb.ConnCase, async: true

  import Telecore.AccountsFixtures

  alias Telecore.Accounts

  describe "POST /api/v1/users" do
    test "registers a user and returns a token", %{conn: conn} do
      attrs = %{
        "email" => unique_user_email(),
        "password" => valid_user_password()
      }

      conn = post(conn, ~p"/api/v1/users", %{"user" => attrs})

      assert %{"token" => token, "user" => %{"id" => id, "email" => email}} =
               json_response(conn, 201)

      assert email == attrs["email"]
      # Tighter than `is_binary` — Base64URL of 32 random bytes (unpadded).
      assert token =~ ~r/^[A-Za-z0-9_\-]{43}$/
      assert %{id: ^id} = Accounts.fetch_user_by_api_token(token)
    end

    test "registered user can log in with the same credentials", %{conn: conn} do
      attrs = %{
        "email" => unique_user_email(),
        "password" => valid_user_password()
      }

      register_conn = post(conn, ~p"/api/v1/users", %{"user" => attrs})
      assert %{"token" => _} = json_response(register_conn, 201)

      login_conn =
        post(build_conn(), ~p"/api/v1/sessions", %{
          "email" => attrs["email"],
          "password" => attrs["password"]
        })

      assert %{"token" => login_token, "user" => %{"email" => email}} =
               json_response(login_conn, 201)

      assert email == attrs["email"]
      assert is_binary(login_token)
    end

    test "rejects registration when password is missing", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/users", %{
          "user" => %{"email" => unique_user_email()}
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "password")
    end

    test "returns errors when params are invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/users", %{"user" => %{"email" => "bad", "password" => "x"}})
      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "email") or Map.has_key?(errors, "password")
    end

    test "returns 400 when no user params are sent", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/users", %{})
      assert %{"error" => "missing_user_params"} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/users/me" do
    test "returns the current user when authenticated", %{conn: conn} do
      user = user_fixture()
      token = Accounts.create_user_api_token(user)

      conn = put_req_header(conn, "authorization", "Bearer " <> token)
      conn = get(conn, ~p"/api/v1/users/me")

      assert %{"user" => %{"id" => id, "email" => email}} = json_response(conn, 200)
      assert id == user.id
      assert email == user.email
    end

    test "returns 401 without a token", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/users/me")
      assert json_response(conn, 401)
    end
  end
end
