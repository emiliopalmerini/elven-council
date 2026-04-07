defmodule ElvenCouncilWeb.PageController do
  use ElvenCouncilWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
