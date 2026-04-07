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
          <div class="text-center mt-10">
            <p class="text-error text-lg">{@error}</p>
          </div>
        <% @player_name == nil -> %>
          <.pick_name_phase players={@players} room_id={@room_id} />
        <% @phase == :card_select -> %>
          <.waiting_phase player_name={@player_name} players={@players} room_id={@room_id} />
        <% @phase == :voting -> %>
          <.player_voting_phase {assigns} />
        <% @phase == :results -> %>
          <.player_results_phase {assigns} />
      <% end %>
    </div>
    """
  end

  defp pick_name_phase(assigns) do
    ~H"""
    <div class="text-center mt-6">
      <h2 class="text-xl font-bold mb-2">Join Game</h2>
      <p class="opacity-60 mb-6">Room: {@room_id}</p>
      <h3 class="font-medium mb-3">Who are you?</h3>
      <div class="grid gap-2 max-w-xs mx-auto">
        <%= for name <- @players do %>
          <button phx-click="pick_name" phx-value-name={name} class="btn btn-primary btn-outline">
            {name}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp waiting_phase(assigns) do
    ~H"""
    <div class="text-center mt-6">
      <h2 class="text-xl font-bold mb-2">Waiting for host...</h2>
      <p class="opacity-60 mb-4">Room: {@room_id}</p>

      <div class="card bg-base-200 p-4 mb-4 inline-block">
        <p class="text-sm opacity-60 mb-1">Playing as</p>
        <p class="font-bold text-lg text-primary">{@player_name}</p>
      </div>

      <div class="mt-4">
        <p class="text-sm opacity-60 mb-2">Players in game:</p>
        <div class="flex flex-wrap gap-2 justify-center">
          <%= for name <- @players do %>
            <span class={["badge badge-lg", if(name == @player_name, do: "badge-primary", else: "badge-neutral")]}>
              {name}
            </span>
          <% end %>
        </div>
      </div>
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
      <.card_hero name={@current_card} image={@card.image} mechanic={@card.mechanic} />

      <.card_rules card={@card} mechanic_label={@mechanic_label} mechanic_rule={@mechanic_rule} />

      <%= if @already_voted do %>
        <p class="text-center mt-4 opacity-60">Vote submitted. Waiting for other players...</p>
      <% else %>
        <%= if @can_vote do %>
          <p class="mb-4 font-medium text-center">{@player_name}, cast your vote:</p>

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
            <div class="grid grid-cols-2 gap-3">
              <%= for option <- @options do %>
                <button phx-click="vote" phx-value-choice={option} class="btn btn-primary btn-outline btn-lg flex-1">
                  {option}
                </button>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <p class="text-center mt-4 opacity-60">Waiting for {@current_voter} to vote...</p>
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
      <.card_hero name={@current_card} image={@card.image} mechanic={@card.mechanic} />

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

  defp card_hero(assigns) do
    ~H"""
    <div class="mb-4">
      <div class="rounded-lg overflow-hidden shadow-md">
        <img src={@image} alt={@name} class="w-full aspect-[5/2] object-cover" />
      </div>
      <div class="flex items-center justify-between mt-2">
        <h3 class="font-bold text-lg">{@name}</h3>
        <span class={["badge badge-sm", mechanic_badge_class(@mechanic)]}>
          {Cards.mechanic_label(@mechanic)}
        </span>
      </div>
    </div>
    """
  end

  defp mechanic_badge_class(:will_of_the_council), do: "badge-primary"
  defp mechanic_badge_class(:councils_dilemma), do: "badge-secondary"
  defp mechanic_badge_class(:secret_council), do: "badge-accent"

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

  def handle_event("pick_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, player_name: name)}
  end

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
