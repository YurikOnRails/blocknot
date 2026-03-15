defmodule Blocknot.Repo do
  use Ecto.Repo,
    otp_app: :blocknot,
    adapter: Ecto.Adapters.Postgres
end
