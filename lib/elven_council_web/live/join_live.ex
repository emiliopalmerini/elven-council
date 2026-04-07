defmodule ElvenCouncilWeb.JoinLive do
  use ElvenCouncilWeb, :live_view

  alias ElvenCouncil.GameServer

  def mount(%{"room_id" => room_id}, _session, socket) do
    if GameServer.exists?(room_id) do
      state = GameServer.get_state(room_id)

      socket =
        assign(socket,
          room_id: room_id,
          players: state.players,
          error: nil
        )

      {:ok, socket}
    else
      {:ok, assign(socket, room_id: room_id, players: [], error: "Room not found")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-10">
      <%= if @error do %>
        <p class="text-red-500">{@error}</p>
      <% else %>
        <h1 class="text-2xl font-bold mb-4">Join game</h1>
        <p class="mb-2">Room: {@room_id}</p>
        <p>Players: {Enum.join(@players, ", ")}</p>
      <% end %>
    </div>
    """
  end
end
