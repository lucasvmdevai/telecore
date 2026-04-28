defmodule TelecoreWeb.PageController do
  use TelecoreWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
