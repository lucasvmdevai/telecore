defmodule Telecore.Repo do
  use Ecto.Repo,
    otp_app: :telecore,
    adapter: Ecto.Adapters.Postgres
end
