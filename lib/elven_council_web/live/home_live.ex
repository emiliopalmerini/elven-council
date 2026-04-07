defmodule ElvenCouncilWeb.HomeLive do
  use ElvenCouncilWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, players: ["", ""], error: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-10">
      <h1 class="text-3xl font-bold text-center mb-8">Elven Council</h1>

      <form phx-submit="create_game">
        <div class="space-y-2 mb-4">
          <label class="block font-medium">Players (in turn order)</label>
          <%= for {player, i} <- Enum.with_index(@players) do %>
            <input
              type="text"
              name="players[]"
              value={player}
              placeholder={"Player #{i + 1}"}
              class="input input-bordered w-full"
            />
          <% end %>
        </div>

        <div class="flex gap-2 mb-4">
          <button type="button" phx-click="add_player" class="btn btn-sm btn-outline">
            + Add Player
          </button>
        </div>

        <p :if={@error} class="text-red-500 text-sm mb-2">{@error}</p>

        <button type="submit" class="btn btn-primary w-full">Create Game</button>
      </form>
    </div>
    """
  end

  def handle_event("add_player", _params, socket) do
    {:noreply, assign(socket, players: socket.assigns.players ++ [""])}
  end

  def handle_event("create_game", %{"players" => players}, socket) do
    players = Enum.map(players, &String.trim/1) |> Enum.reject(&(&1 == ""))

    cond do
      length(players) < 2 ->
        {:noreply, assign(socket, error: "Need at least 2 players", players: players)}

      length(players) != length(Enum.uniq(players)) ->
        {:noreply, assign(socket, error: "Player names must be unique", players: players)}

      true ->
        room_id = generate_room_id()
        {:ok, _pid} = ElvenCouncil.GameServer.start_game(room_id, players)
        {:noreply, push_navigate(socket, to: ~p"/game/#{room_id}")}
    end
  end

  defp generate_room_id do
    :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
  end
end
