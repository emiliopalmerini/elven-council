defmodule ElvenCouncilWeb.JoinLive do
  use ElvenCouncilWeb, :live_view

  alias ElvenCouncil.Cards
  alias ElvenCouncil.GameServer

  def mount(%{"room_id" => room_id} = params, _session, socket) do
    if GameServer.exists?(room_id) do
      if connected?(socket), do: GameServer.subscribe(room_id)
      state = GameServer.get_state(room_id)
      player_name = params["name"]

      socket =
        assign(socket,
          room_id: room_id,
          player_name: player_name,
          players: state.players,
          phase: state.phase,
          current_card: state.current_card,
          votes: state.votes,
          current_voter_index: state.current_voter_index,
          illusion_of_choice: state.illusion_of_choice,
          error: nil
        )

      {:ok, socket}
    else
      {:ok, assign(socket, room_id: room_id, player_name: nil, players: [], phase: :error, current_card: nil, votes: [], current_voter_index: 0, illusion_of_choice: false, error: "Room not found")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto mt-6">
      <%= cond do %>
        <% @error -> %>
          <p class="text-red-500">{@error}</p>
        <% @phase == :card_select -> %>
          <.waiting_phase player_name={@player_name} />
        <% @phase == :voting -> %>
          <.player_voting_phase {assigns} />
        <% @phase == :results -> %>
          <.player_results_phase {assigns} />
      <% end %>
    </div>
    """
  end

  defp waiting_phase(assigns) do
    ~H"""
    <div class="text-center mt-10">
      <h2 class="text-xl font-bold mb-4">Waiting for host to select a card...</h2>
      <p :if={@player_name}>Playing as: {@player_name}</p>
    </div>
    """
  end

  defp player_voting_phase(assigns) do
    card = Cards.get(assigns.current_card)
    current_voter = Enum.at(assigns.players, assigns.current_voter_index)
    is_my_turn = current_voter == assigns.player_name
    options = resolve_options(card, assigns.players)
    already_voted = Enum.any?(assigns.votes, fn {p, _} -> p == assigns.player_name end)

    # For secret council, all players can vote simultaneously
    can_vote = cond do
      already_voted -> false
      card.mechanic == :secret_council -> true
      true -> is_my_turn
    end

    assigns =
      assigns
      |> Map.put(:card, card)
      |> Map.put(:current_voter, current_voter)
      |> Map.put(:is_my_turn, is_my_turn)
      |> Map.put(:can_vote, can_vote)
      |> Map.put(:already_voted, already_voted)
      |> Map.put(:options, options)
      |> Map.put(:mechanic_label, Cards.mechanic_label(card.mechanic))
      |> Map.put(:mechanic_rule, Cards.mechanic_rule(card.mechanic))

    ~H"""
    <div>
      <h3 class="font-bold mb-2">{@current_card}</h3>

      <.card_rules card={@card} mechanic_label={@mechanic_label} mechanic_rule={@mechanic_rule} />

      <%= if @already_voted do %>
        <p class="text-center mt-4">Vote submitted. Waiting for other players...</p>
      <% else %>
        <%= if @can_vote do %>
          <p class="mb-4">{@player_name}, cast your vote:</p>

          <%= if @card.mechanic == :secret_council && @card[:vote_type] == :free_text do %>
            <form phx-submit="vote_free_text">
              <input
                type="text"
                name="creature"
                placeholder="Name a creature"
                class="input input-bordered w-full mb-2"
              />
              <button type="submit" class="btn btn-primary w-full">Vote</button>
            </form>
          <% else %>
            <div class="grid gap-2">
              <%= for option <- @options do %>
                <button phx-click="vote" phx-value-choice={option} class="btn btn-primary btn-outline">
                  {option}
                </button>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <p class="text-center mt-4">Waiting for {@current_voter} to vote...</p>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp player_results_phase(assigns) do
    card = Cards.get(assigns.current_card)
    tally = tally_votes(assigns.votes)

    assigns =
      assigns
      |> Map.put(:card, card)
      |> Map.put(:tally, tally)

    ~H"""
    <div>
      <h3 class="font-bold mb-2">{@current_card}</h3>

      <div class="mb-4">
        <h4 class="font-medium">Votes:</h4>
        <%= for {option, count} <- @tally do %>
          <p>{option}: {count}</p>
        <% end %>
      </div>

      <%= if @card.mechanic == :secret_council do %>
        <div class="mb-4">
          <h4 class="font-medium">Revealed votes:</h4>
          <%= for {player, choice} <- @votes do %>
            <p>{player} voted: {choice}</p>
          <% end %>
        </div>
      <% end %>

      <p class="text-center mt-4 opacity-60">Waiting for host to start next vote...</p>
    </div>
    """
  end

  # -- Components --

  defp card_rules(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-3 mb-4 text-sm">
      <p class="font-medium">{@mechanic_label}</p>
      <p class="opacity-70 mb-2">{@mechanic_rule}</p>
      <%= if is_map(@card.resolution) do %>
        <ul class="space-y-1">
          <%= for {option, effect} <- @card.resolution do %>
            <li><span class="font-medium">{option}:</span> {effect}</li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  # -- Events --

  def handle_event("vote", %{"choice" => choice}, socket) do
    GameServer.cast_vote(socket.assigns.room_id, socket.assigns.player_name, choice)
    {:noreply, socket}
  end

  def handle_event("vote_free_text", %{"creature" => creature}, socket) do
    creature = String.trim(creature)
    GameServer.cast_vote(socket.assigns.room_id, socket.assigns.player_name, creature)
    {:noreply, socket}
  end

  # -- PubSub --

  def handle_info({:game_state, state}, socket) do
    {:noreply,
     assign(socket,
       phase: state.phase,
       current_card: state.current_card,
       votes: state.votes,
       current_voter_index: state.current_voter_index,
       illusion_of_choice: state.illusion_of_choice
     )}
  end

  # -- Helpers --

  defp resolve_options(card, players) do
    case card.options do
      :players -> players
      :free_text -> []
      options when is_list(options) -> options
    end
  end

  defp tally_votes(votes) do
    votes
    |> Enum.map(&elem(&1, 1))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
  end
end
