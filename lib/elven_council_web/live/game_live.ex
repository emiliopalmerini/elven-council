defmodule ElvenCouncilWeb.GameLive do
  use ElvenCouncilWeb, :live_view

  def mount(%{"room_id" => _room_id}, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>Game</div>
    """
  end
end
