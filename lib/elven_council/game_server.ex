defmodule ElvenCouncil.GameServer do
  use GenServer

  # -- Client API --

  def start_game(room_id, players) do
    GenServer.start_link(__MODULE__, %{room_id: room_id, players: players},
      name: via(room_id)
    )
  end

  def get_state(room_id) do
    GenServer.call(via(room_id), :get_state)
  end

  def exists?(room_id) do
    case Registry.lookup(ElvenCouncil.GameRegistry, room_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  # -- Server Callbacks --

  @impl true
  def init(%{room_id: room_id, players: players}) do
    state = %{
      room_id: room_id,
      players: players,
      phase: :lobby
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # -- Private --

  defp via(room_id) do
    {:via, Registry, {ElvenCouncil.GameRegistry, room_id}}
  end
end
