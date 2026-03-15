defmodule BlocknotWeb.PageController do
  use BlocknotWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
