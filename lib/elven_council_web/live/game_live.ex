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
          cards: Cards.all() |> Enum.sort_by(&elem(&1, 0)),
          current_card: state.current_card,
          votes: state.votes,
          current_voter_index: state.current_voter_index,
          error: nil,
          illusion_of_choice: state.illusion_of_choice,
          host_player: nil
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
        <% @host_player == nil -> %>
          <.pick_host_phase players={@players} room_id={@room_id} />
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

  defp pick_host_phase(assigns) do
    ~H"""
    <div class="text-center mt-6">
      <h2 class="text-xl font-bold mb-2">Who are you?</h2>
      <p class="opacity-60 mb-6">Room: {@room_id}</p>
      <div class="grid gap-2 max-w-xs mx-auto">
        <%= for name <- @players do %>
          <button phx-click="pick_host" phx-value-name={name} class="btn btn-primary btn-outline">
            {name}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp card_select_phase(assigns) do
    join_url = ElvenCouncilWeb.Endpoint.url() <> "/join/#{assigns.room_id}"
    assigns = Map.put(assigns, :join_url, join_url)

    ~H"""
    <div>
      <p :if={@error} class="text-error text-sm mb-2">{@error}</p>

      <div class="card bg-base-200 p-3 mb-4">
        <p class="text-xs font-medium opacity-60 mb-1">Share with players:</p>
        <div class="flex items-center gap-2">
          <code id="join-url" class="text-xs flex-1 truncate">{@join_url}</code>
          <button
            phx-click={JS.dispatch("phx:copy", to: "#join-url")}
            class="btn btn-xs btn-ghost"
            title="Copy link"
          >
            <.icon name="hero-clipboard-document-micro" class="size-4" />
          </button>
        </div>
      </div>

      <div class="mb-4 flex items-center gap-3">
        <button
          :if={!@illusion_of_choice}
          phx-click="toggle_illusion"
          class="btn btn-sm btn-outline"
        >
          Illusion of Choice
        </button>
        <div :if={@illusion_of_choice} class="badge badge-warning gap-1">
          <.icon name="hero-eye-slash-micro" class="size-3" />
          Illusion of Choice active
        </div>
      </div>

      <h3 class="font-medium mb-3">Select a card to vote on:</h3>
      <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
        <%= for {name, card} <- @cards do %>
          <button
            phx-click="select_card"
            phx-value-card={name}
            class="group card bg-base-200 shadow-sm hover:shadow-md hover:scale-[1.03] transition-all duration-150 cursor-pointer overflow-hidden"
          >
            <figure class="aspect-[3/2] overflow-hidden">
              <img
                src={card.image}
                alt={name}
                class="w-full h-full object-cover group-hover:brightness-110 transition-all"
              />
            </figure>
            <div class="p-2">
              <p class="text-xs font-medium leading-tight">{name}</p>
              <span class={[
                "badge badge-xs mt-1",
                mechanic_badge_class(card.mechanic)
              ]}>
                {Cards.mechanic_label(card.mechanic)}
              </span>
            </div>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp mechanic_badge_class(:will_of_the_council), do: "badge-primary"
  defp mechanic_badge_class(:councils_dilemma), do: "badge-secondary"
  defp mechanic_badge_class(:secret_council), do: "badge-accent"

  defp voting_phase(assigns) do
    card = Cards.get(assigns.current_card)
    host_player = assigns.host_player
    voter = Enum.at(assigns.players, assigns.current_voter_index)
    options = resolve_options(card, assigns.players)
    vote_count = length(assigns.votes)
    player_count = length(assigns.players)
    host_already_voted = Enum.any?(assigns.votes, fn {p, _} -> p == host_player end)

    host_can_vote = cond do
      assigns.illusion_of_choice -> true
      host_already_voted -> false
      card.mechanic == :secret_council -> true
      true -> voter == host_player
    end

    assigns =
      assigns
      |> Map.put(:card, card)
      |> Map.put(:host_player, host_player)
      |> Map.put(:voter, voter)
      |> Map.put(:options, options)
      |> Map.put(:vote_count, vote_count)
      |> Map.put(:player_count, player_count)
      |> Map.put(:host_can_vote, host_can_vote)
      |> Map.put(:host_already_voted, host_already_voted)
      |> Map.put(:mechanic_label, Cards.mechanic_label(card.mechanic))
      |> Map.put(:mechanic_rule, Cards.mechanic_rule(card.mechanic))

    ~H"""
    <div>
      <.card_hero name={@current_card} image={@card.image} mechanic={@card.mechanic} />

      <.card_rules card={@card} mechanic_label={@mechanic_label} mechanic_rule={@mechanic_rule} />

      <%= if @host_can_vote do %>
        <div class="text-center mb-4">
          <%= if @illusion_of_choice do %>
            <p class="font-medium text-warning">You choose for all players</p>
          <% else %>
            <p class="font-medium">{@host_player}, cast your vote:</p>
          <% end %>
        </div>

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
        <div class="text-center mb-4">
          <%= if @host_already_voted do %>
            <p class="font-medium">Vote submitted.</p>
          <% end %>
          <%= if @card.mechanic == :secret_council do %>
            <p class="opacity-60">Waiting for all players to vote secretly...</p>
          <% else %>
            <p class="opacity-60">Waiting for {@voter} to vote...</p>
          <% end %>
          <p class="text-sm opacity-60 mt-2">{@vote_count} / {@player_count} votes cast</p>
        </div>
      <% end %>
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
      <.card_hero name={@current_card} image={@card.image} mechanic={@card.mechanic} />

      <div class="card bg-base-200 p-4 mb-4">
        <h4 class="font-medium mb-2">Vote Tally</h4>
        <div class="space-y-2">
          <%= for {option, count} <- @tally do %>
            <div class="flex items-center justify-between">
              <span class="font-medium">{option}</span>
              <span class="badge badge-neutral">{count}</span>
            </div>
          <% end %>
        </div>
      </div>

      <%= if @card.mechanic == :will_of_the_council do %>
        <div class="card bg-primary/10 border border-primary/30 p-4 mb-4">
          <p class="font-bold text-primary">{@winner} wins!</p>
          <p class="text-sm mt-1">{@card.resolution[@winner]}</p>
        </div>
      <% end %>

      <%= if @card.mechanic in [:councils_dilemma, :unnamed_voting] do %>
        <div class="card bg-secondary/10 border border-secondary/30 p-4 mb-4 space-y-2">
          <%= for {option, count} <- @tally do %>
            <p><span class="font-medium">{count}x {option}:</span> <span class="text-sm">{@card.resolution[option]}</span></p>
          <% end %>
        </div>
      <% end %>

      <%= if @card.mechanic == :secret_council do %>
        <div class="card bg-accent/10 border border-accent/30 p-4 mb-4">
          <h4 class="font-medium mb-2">Revealed Votes</h4>
          <div class="space-y-1">
            <%= for {player, choice} <- @votes do %>
              <p class="text-sm">{player} voted: {choice}</p>
            <% end %>
          </div>

          <%= if @card[:vote_type] == :player do %>
            <div class="mt-3 pt-3 border-t border-accent/20 space-y-1">
              <% voted_players = Enum.map(@votes, &elem(&1, 1)) |> Enum.uniq() %>
              <% unvoted = @players -- voted_players %>
              <%= for p <- unvoted do %>
                <p class="text-sm">{p} received no votes; may put a permanent card from their hand onto the battlefield</p>
              <% end %>
              <%= for {option, count} <- @tally do %>
                <p class="text-sm font-medium">{option} draws {count} cards</p>
              <% end %>
            </div>
          <% end %>

          <%= if @card[:vote_type] == :free_text do %>
            <div class="mt-3 pt-3 border-t border-accent/20 space-y-1">
              <%= for {creature, count} <- @tally do %>
                <p class="text-sm">{creature}: {count} stun counters, tapped</p>
              <% end %>
            </div>
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
    <div class="card bg-base-200 p-3 mb-3">
      <h4 class="font-medium text-sm">Erestor of the Council</h4>
      <p class="text-sm mt-1">Opponents who matched: {Enum.join(@matched, ", ")} ; each creates a Treasure token</p>
      <p class="text-sm">You scry {@scry_x}, then draw a card</p>
    </div>
    """
  end

  defp model_of_unity_summary(assigns) do
    matched = Enum.filter(assigns.votes, fn {_p, v} -> v == assigns.caster_vote end) |> Enum.map(&elem(&1, 0))

    assigns = Map.put(assigns, :matched, matched)

    ~H"""
    <div class="card bg-base-200 p-3 mb-3">
      <h4 class="font-medium text-sm">Model of Unity</h4>
      <p class="text-sm mt-1">{Enum.join(@matched, ", ")} may scry 2</p>
    </div>
    """
  end

  # -- Events --

  def handle_event("pick_host", %{"name" => name}, socket) do
    {:noreply, assign(socket, host_player: name)}
  end

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
    GameServer.cast_vote(socket.assigns.room_id, socket.assigns.host_player, choice)
    state = GameServer.get_state(socket.assigns.room_id)
    {:noreply, sync_state(socket, state)}
  end

  def handle_event("vote_free_text", %{"creature" => creature}, socket) do
    creature = String.trim(creature)
    GameServer.cast_vote(socket.assigns.room_id, socket.assigns.host_player, creature)
    state = GameServer.get_state(socket.assigns.room_id)
    {:noreply, sync_state(socket, state)}
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
    {:noreply, sync_state(socket, state)}
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
