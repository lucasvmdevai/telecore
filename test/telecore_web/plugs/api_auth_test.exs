defmodule TelecoreWeb.Plugs.ApiAuthTest do
  use TelecoreWeb.ConnCase, async: true

  import Telecore.AccountsFixtures, only: [user_fixture: 0, offset_user_token: 3]

  alias Telecore.Accounts
  alias TelecoreWeb.Plugs.ApiAuth

  setup do
    user = user_fixture()
    token = Accounts.create_user_api_token(user)
    %{user: user, token: token}
  end

  test "assigns current_user when a valid Bearer token is present", %{
    conn: conn,
    user: user,
    token: token
  } do
    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> ApiAuth.call([])

    assert conn.assigns.current_user.id == user.id
    refute conn.halted
  end

  test "returns 401 when no Authorization header is present", %{conn: conn} do
    conn = ApiAuth.call(conn, [])
    assert conn.status == 401
    assert conn.halted
  end

  test "returns 401 when the token is invalid", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer not-a-valid-token")
      |> ApiAuth.call([])

    assert conn.status == 401
    assert conn.halted
  end

  test "returns 401 when the header is malformed", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Basic abc123")
      |> ApiAuth.call([])

    assert conn.status == 401
    assert conn.halted
  end

  test "returns 401 when the token has aged out beyond api validity", %{
    conn: conn,
    token: token
  } do
    # The plug enforces a 60-day validity window. Roll the row's
    # inserted_at back by 61 days and confirm lookups are rejected.
    {:ok, raw} = Base.url_decode64(token, padding: false)
    hashed = :crypto.hash(:sha256, raw)
    {1, _} = offset_user_token(hashed, -61, :day)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> ApiAuth.call([])

    assert conn.status == 401
    assert conn.halted
  end
end
