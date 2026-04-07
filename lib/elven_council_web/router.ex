defmodule ElvenCouncilWeb.Router do
  use ElvenCouncilWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElvenCouncilWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ElvenCouncilWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/game/:room_id", GameLive
    live "/join/:room_id", JoinLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", ElvenCouncilWeb do
  #   pipe_through :api
  # end
end
