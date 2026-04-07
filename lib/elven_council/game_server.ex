defmodule ElvenCouncil.GameServer do
  use GenServer

  alias ElvenCouncil.Cards

  @topic_prefix "game:"

  # -- Client API --

  def start_game(room_id, players) do
    DynamicSupervisor.start_child(
      ElvenCouncil.GameSupervisor,
      {__MODULE__, %{room_id: room_id, players: players}}
    )
  end

  def get_state(room_id), do: GenServer.call(via(room_id), :get_state)

  def exists?(room_id) do
    case Registry.lookup(ElvenCouncil.GameRegistry, room_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  def select_card(room_id, card_name, illusion_of_choice \\ false) do
    GenServer.call(via(room_id), {:select_card, card_name, illusion_of_choice})
  end

  def cast_vote(room_id, player, choice) do
    GenServer.call(via(room_id), {:cast_vote, player, choice})
  end

  def new_vote(room_id), do: GenServer.call(via(room_id), :new_vote)

  def subscribe(room_id) do
    Phoenix.PubSub.subscribe(ElvenCouncil.PubSub, @topic_prefix <> room_id)
  end

  def topic(room_id), do: @topic_prefix <> room_id

  # -- GenServer plumbing --

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: via(init_arg.room_id))
  end

  def child_spec(init_arg) do
    %{
      id: {__MODULE__, init_arg.room_id},
      start: {__MODULE__, :start_link, [init_arg]},
      restart: :temporary
    }
  end

  # -- Server Callbacks --

  @impl true
  def init(%{room_id: room_id, players: players}) do
    state = %{
      room_id: room_id,
      players: players,
      phase: :card_select,
      current_card: nil,
      votes: [],
      current_voter_index: 0,
      illusion_of_choice: false,
      error: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:select_card, card_name, illusion_of_choice}, _from, state) do
    if state.phase != :card_select do
      {:reply, {:error, "A vote already in progress"}, state}
    else
      state = %{state |
        current_card: card_name,
        phase: :voting,
        votes: [],
        current_voter_index: 0,
        illusion_of_choice: illusion_of_choice,
        error: nil
      }

      broadcast(state)
      {:reply, :ok, state}
    end
  end

  def handle_call({:cast_vote, player, choice}, _from, state) do
    card = Cards.get(state.current_card)

    if state.illusion_of_choice do
      votes = Enum.map(state.players, fn p -> {p, choice} end)
      state = %{state | votes: votes, phase: :results}
      broadcast(state)
      {:reply, :ok, state}
    else
      votes = state.votes ++ [{player, choice}]
      next_index = state.current_voter_index + 1

      state = if next_index >= length(state.players) do
        %{state | votes: votes, phase: :results}
      else
        if card.mechanic == :secret_council do
          # Secret: just advance to next voter, no pass screen in multi-device
          %{state | votes: votes, current_voter_index: next_index}
        else
          %{state | votes: votes, current_voter_index: next_index}
        end
      end

      broadcast(state)
      {:reply, :ok, state}
    end
  end

  def handle_call(:new_vote, _from, state) do
    state = %{state |
      phase: :card_select,
      current_card: nil,
      votes: [],
      current_voter_index: 0,
      illusion_of_choice: false,
      error: nil
    }

    broadcast(state)
    {:reply, :ok, state}
  end

  # -- Private --

  defp via(room_id) do
    {:via, Registry, {ElvenCouncil.GameRegistry, room_id}}
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(
      ElvenCouncil.PubSub,
      @topic_prefix <> state.room_id,
      {:game_state, state}
    )
  end
end
