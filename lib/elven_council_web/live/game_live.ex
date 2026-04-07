defmodule ElvenCouncilWeb.GameLive do
  use ElvenCouncilWeb, :live_view

  alias ElvenCouncil.Cards
  alias ElvenCouncil.GameServer

  def mount(%{"room_id" => room_id}, _session, socket) do
    if GameServer.exists?(room_id) do
      if connected?(socket), do: GameServer.subscribe(room_id)
      state = GameServer.get_state(room_id)

      socket =
        socket
        |> assign(
          room_id: room_id,
          players: state.players,
          phase: state.phase,
          card_names: Cards.voteable_names() |> Enum.sort(),
          current_card: state.current_card,
          votes: state.votes,
          current_voter_index: state.current_voter_index,
          error: nil,
          illusion_of_choice: state.illusion_of_choice,
          # Single-device pass screen (not used in multi-device)
          pass_screen: false
        )

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto mt-6">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-xl font-bold">Game</h2>
        <span class="text-sm opacity-60">room: {@room_id}</span>
      </div>

      <%= cond do %>
        <% @pass_screen -> %>
          <.pass_phase />
        <% @phase == :card_select -> %>
          <.card_select_phase {assigns} />
        <% @phase == :voting -> %>
          <.voting_phase {assigns} />
        <% @phase == :results -> %>
          <.results_phase {assigns} />
      <% end %>
    </div>
    """
  end

  defp card_select_phase(assigns) do
    ~H"""
    <div>
      <p :if={@error} class="text-red-500 text-sm mb-2">{@error}</p>

      <div class="mb-4">
        <button
          :if={!@illusion_of_choice}
          phx-click="toggle_illusion"
          class="btn btn-sm btn-outline"
        >
          Illusion of Choice
        </button>
        <div :if={@illusion_of_choice} class="badge badge-warning">
          Illusion of Choice active
        </div>
      </div>

      <h3 class="font-medium mb-2">Select a card to vote on:</h3>
      <div class="grid gap-2">
        <%= for name <- @card_names do %>
          <button phx-click="select_card" phx-value-card={name} class="btn btn-outline btn-sm text-left">
            {name}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp voting_phase(assigns) do
    card = Cards.get(assigns.current_card)
    voter = Enum.at(assigns.players, assigns.current_voter_index)
    options = resolve_options(card, assigns.players)

    assigns =
      assigns
      |> Map.put(:card, card)
      |> Map.put(:voter, voter)
      |> Map.put(:options, options)

    ~H"""
    <div>
      <h3 class="font-bold mb-2">{@current_card}</h3>
      <%= if @illusion_of_choice do %>
        <p class="mb-4">You choose for all players</p>
      <% else %>
        <p class="mb-4">{@voter}'s turn to vote</p>
      <% end %>

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
    </div>
    """
  end

  defp pass_phase(assigns) do
    ~H"""
    <div class="text-center">
      <h3 class="font-bold mb-4">Vote recorded!</h3>
      <p class="mb-4">Please pass to the next player</p>
      <button phx-click="ready" class="btn btn-primary">Ready</button>
    </div>
    """
  end

  defp results_phase(assigns) do
    card = Cards.get(assigns.current_card)
    tally = tally_votes(assigns.votes)
    winner = resolve_winner(card, tally)
    caster_vote = List.first(assigns.votes) |> elem(1)

    assigns =
      assigns
      |> Map.put(:card, card)
      |> Map.put(:tally, tally)
      |> Map.put(:winner, winner)
      |> Map.put(:caster_vote, caster_vote)

    ~H"""
    <div>
      <h3 class="font-bold mb-2">{@current_card}</h3>

      <div class="mb-4">
        <h4 class="font-medium">Votes:</h4>
        <%= for {option, count} <- @tally do %>
          <p>{option}: {count}</p>
        <% end %>
      </div>

      <%= if @card.mechanic == :will_of_the_council do %>
        <div class="mb-4">
          <p class="font-medium">{@winner} wins!</p>
          <p>{@card.resolution[@winner]}</p>
        </div>
      <% end %>

      <%= if @card.mechanic in [:councils_dilemma, :unnamed_voting] do %>
        <div class="mb-4">
          <%= for {option, count} <- @tally do %>
            <p>{count}x {option}: {@card.resolution[option]}</p>
          <% end %>
        </div>
      <% end %>

      <%= if @card.mechanic == :secret_council do %>
        <div class="mb-4">
          <h4 class="font-medium">Revealed votes:</h4>
          <%= for {player, choice} <- @votes do %>
            <p>{player} voted: {choice}</p>
          <% end %>

          <%= if @card[:vote_type] == :player do %>
            <% voted_players = Enum.map(@votes, &elem(&1, 1)) |> Enum.uniq() %>
            <% unvoted = @players -- voted_players %>
            <%= for p <- unvoted do %>
              <p>{p} received no votes; may put a permanent card from their hand onto the battlefield</p>
            <% end %>
            <%= for {option, count} <- @tally do %>
              <p>{option} draws {count} cards</p>
            <% end %>
          <% end %>

          <%= if @card[:vote_type] == :free_text do %>
            <%= for {creature, count} <- @tally do %>
              <p>{creature}: {count} stun counters, tapped</p>
            <% end %>
          <% end %>
        </div>
      <% end %>

      <.erestor_summary votes={@votes} caster_vote={@caster_vote} players={@players} />
      <.model_of_unity_summary votes={@votes} caster_vote={@caster_vote} players={@players} />

      <button phx-click="new_vote" class="btn btn-primary w-full mt-4">New Vote</button>
    </div>
    """
  end

  defp erestor_summary(assigns) do
    caster = List.first(assigns.players)
    opponents = Enum.drop(assigns.players, 1)
    matched = Enum.filter(assigns.votes, fn {p, v} -> p != caster && v == assigns.caster_vote end) |> Enum.map(&elem(&1, 0))
    mismatched = opponents -- matched
    scry_x = length(mismatched)

    assigns =
      assigns
      |> Map.put(:matched, matched)
      |> Map.put(:scry_x, scry_x)

    ~H"""
    <div class="border-t pt-2 mt-2">
      <h4 class="font-medium">Erestor of the Council</h4>
      <p>Opponents who matched: {Enum.join(@matched, ", ")} - each creates a Treasure token</p>
      <p>You scry {@scry_x}, then draw a card</p>
    </div>
    """
  end

  defp model_of_unity_summary(assigns) do
    matched = Enum.filter(assigns.votes, fn {_p, v} -> v == assigns.caster_vote end) |> Enum.map(&elem(&1, 0))

    assigns = Map.put(assigns, :matched, matched)

    ~H"""
    <div class="border-t pt-2 mt-2">
      <h4 class="font-medium">Model of Unity</h4>
      <p>{Enum.join(@matched, ", ")} may scry 2</p>
    </div>
    """
  end

  # -- Events --

  def handle_event("select_card", %{"card" => card_name}, socket) do
    case GameServer.select_card(socket.assigns.room_id, card_name, socket.assigns.illusion_of_choice) do
      :ok ->
        state = GameServer.get_state(socket.assigns.room_id)
        {:noreply, sync_state(socket, state)}

      {:error, msg} ->
        {:noreply, assign(socket, error: msg)}
    end
  end

  def handle_event("vote", %{"choice" => choice}, socket) do
    voter = Enum.at(socket.assigns.players, socket.assigns.current_voter_index)
    GameServer.cast_vote(socket.assigns.room_id, voter, choice)

    state = GameServer.get_state(socket.assigns.room_id)

    if state.phase == :results do
      {:noreply, sync_state(socket, state)}
    else
      {:noreply, socket |> sync_state(state) |> assign(pass_screen: true)}
    end
  end

  def handle_event("vote_free_text", %{"creature" => creature}, socket) do
    creature = String.trim(creature)
    voter = Enum.at(socket.assigns.players, socket.assigns.current_voter_index)
    GameServer.cast_vote(socket.assigns.room_id, voter, creature)

    state = GameServer.get_state(socket.assigns.room_id)

    if state.phase == :results do
      {:noreply, sync_state(socket, state)}
    else
      {:noreply, socket |> sync_state(state) |> assign(pass_screen: true)}
    end
  end

  def handle_event("ready", _params, socket) do
    state = GameServer.get_state(socket.assigns.room_id)
    {:noreply, socket |> sync_state(state) |> assign(pass_screen: false)}
  end

  def handle_event("new_vote", _params, socket) do
    GameServer.new_vote(socket.assigns.room_id)
    state = GameServer.get_state(socket.assigns.room_id)
    {:noreply, sync_state(socket, state)}
  end

  def handle_event("toggle_illusion", _params, socket) do
    {:noreply, assign(socket, illusion_of_choice: true)}
  end

  # -- PubSub --

  def handle_info({:game_state, state}, socket) do
    pass_screen =
      if socket.assigns.pass_screen && state.phase == :voting do
        true
      else
        false
      end

    {:noreply, socket |> sync_state(state) |> assign(pass_screen: pass_screen)}
  end

  # -- Helpers --

  defp sync_state(socket, state) do
    assign(socket,
      phase: state.phase,
      current_card: state.current_card,
      votes: state.votes,
      current_voter_index: state.current_voter_index,
      illusion_of_choice: state.illusion_of_choice
    )
  end

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

  defp resolve_winner(card, tally) do
    if card.mechanic == :will_of_the_council do
      [opt_a, opt_b] = card.options
      count_a = Map.get(Enum.into(tally, %{}), opt_a, 0)
      count_b = Map.get(Enum.into(tally, %{}), opt_b, 0)

      if count_a > count_b, do: opt_a, else: opt_b
    else
      nil
    end
  end
end
