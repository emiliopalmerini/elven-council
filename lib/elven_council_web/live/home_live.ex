defmodule ElvenCouncilWeb.HomeLive do
  use ElvenCouncilWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, players: ["", ""], error: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-10">
      <div class="text-center mb-8">
        <h1 class="text-4xl font-bold text-primary mb-2">Elven Council</h1>
        <p class="text-sm opacity-60">Vote wisely, council member</p>
      </div>

      <form phx-submit="create_game" class="card bg-base-200 p-6">
        <div class="space-y-2 mb-4">
          <label class="block font-medium text-sm">Players (in turn order)</label>
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

        <div class="mb-4">
          <button type="button" phx-click="add_player" class="btn btn-sm btn-outline btn-ghost">
            + Add Player
          </button>
        </div>

        <p :if={@error} class="text-error text-sm mb-2">{@error}</p>

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
