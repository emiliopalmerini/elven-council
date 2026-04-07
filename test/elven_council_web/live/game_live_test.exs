defmodule ElvenCouncilWeb.GameLiveTest do
  use ElvenCouncilWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # -- Game Setup --

  describe "game creation" do
    test "home page shows a form to create a game", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Elven Council"
      assert has_element?(view, "input[name='players[]']")
      assert has_element?(view, "button", "Create Game")
    end

    test "creating a game with valid players redirects to the game page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"/game/.+"
    end

    test "creating a game with fewer than 2 players shows an error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("form", %{"players" => ["Emilio"]})
        |> render_submit()

      assert html =~ "at least 2 players"
    end

    test "creating a game with duplicate player names shows an error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("form", %{"players" => ["Emilio", "Emilio", "Marco"]})
        |> render_submit()

      assert html =~ "unique"
    end
  end

  # -- Card Selection --

  describe "card selection" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      game_view |> element("button", "Emilio") |> render_click()

      %{game_view: game_view, game_path: path}
    end

    test "game page lists all 13 voteable cards", %{game_view: view} do
      html = render(view)

      # Will of the Council
      assert html =~ "Coercive Portal"
      assert html =~ "Galadriel, Elven-Queen"
      assert html =~ "Plea for Power"
      assert html =~ "Sail into the West"
      assert html =~ "Split Decision"

      # Council's Dilemma
      assert html =~ "Expropriate"
      assert html =~ "Messenger Jays"
      assert has_element?(view, "button", "Selvala's Stampede")
      assert html =~ "Travel Through Caradhras"

      # Unnamed (Council's Dilemma behavior)
      assert html =~ "Emissary Green"

      # Secret Council
      assert html =~ "Cirdan the Shipwright"
      assert html =~ "Elrond of the White Council"
      assert html =~ "Trap the Trespassers"
    end

    test "selecting a card starts a vote", %{game_view: view} do
      html =
        view
        |> element("button", "Plea for Power")
        |> render_click()

      assert html =~ "Time"
      assert html =~ "Knowledge"
    end

    test "cannot start a vote while another is in progress", %{game_view: view} do
      view
      |> element("button", "Plea for Power")
      |> render_click()

      # Card selection buttons are not rendered during voting
      refute has_element?(view, "button", "Expropriate")
    end
  end

  # -- Helper: create game with host + JoinLive for non-host players --

  defp create_game(conn, players, host_name \\ nil) do
    {:ok, view, _html} = live(conn, ~p"/")
    view |> form("form", %{"players" => players}) |> render_submit()
    {game_path, _flash} = assert_redirect(view)
    "/game/" <> room_code = game_path

    {:ok, host, _html} = live(conn, game_path)

    # Host picks their identity (defaults to first player)
    host_name = host_name || List.first(players)
    host |> element("button", host_name) |> render_click()

    # Non-host players join via JoinLive
    player_views =
      players
      |> Enum.reject(&(&1 == host_name))
      |> Enum.map(fn name ->
        {:ok, pv, _html} = live(conn, ~p"/join/#{room_code}?name=#{name}")
        {name, pv}
      end)
      |> Map.new()

    {host, player_views, room_code}
  end

  # -- Will of the Council (public, sequential, majority wins) --

  describe "Will of the Council voting" do
    setup %{conn: conn} do
      {host, players, _room} = create_game(conn, ["Emilio", "Marco", "Luca"])

      host |> element("button", "Plea for Power") |> render_click()

      %{host: host, marco: players["Marco"], luca: players["Luca"]}
    end

    test "host (caster) votes first, then other players in turn order", ctx do
      # Host sees vote prompt
      host_html = render(ctx.host)
      assert host_html =~ "Emilio, cast your vote"

      # Host votes
      ctx.host |> element("button", "Time") |> render_click()

      # Host now sees waiting view
      host_html = render(ctx.host)
      assert host_html =~ "Vote submitted"

      # Marco's turn
      marco_html = render(ctx.marco)
      assert marco_html =~ "Marco, cast your vote"
    end

    test "majority wins the vote", ctx do
      ctx.host |> element("button", "Time") |> render_click()
      ctx.marco |> element("button", "Time") |> render_click()
      ctx.luca |> element("button", "Knowledge") |> render_click()

      host_html = render(ctx.host)
      assert host_html =~ "Time"
      assert host_html =~ "wins"
    end

    test "tie resolves to the second option", %{conn: conn} do
      {host, players, _room} = create_game(conn, ["Emilio", "Marco"])

      host |> element("button", "Coercive Portal") |> render_click()

      host |> element("button", "Carnage") |> render_click()
      players["Marco"] |> element("button", "Homage") |> render_click()

      host_html = render(host)
      assert host_html =~ "Homage"
      assert host_html =~ "wins"
    end
  end

  # -- Council's Dilemma (public, sequential, each vote scales) --

  describe "Council's Dilemma voting" do
    setup %{conn: conn} do
      {host, players, _room} = create_game(conn, ["Emilio", "Marco", "Luca"])

      host |> element("button", "Expropriate") |> render_click()

      %{host: host, marco: players["Marco"], luca: players["Luca"]}
    end

    test "resolution shows individual vote counts", ctx do
      ctx.host |> element("button", "Time") |> render_click()
      ctx.marco |> element("button", "Money") |> render_click()
      ctx.luca |> element("button", "Time") |> render_click()

      host_html = render(ctx.host)
      assert host_html =~ "Time"
      assert host_html =~ "2"
      assert host_html =~ "Money"
      assert host_html =~ "1"
    end

    test "resolution describes per-vote effects", ctx do
      ctx.host |> element("button", "Time") |> render_click()
      ctx.marco |> element("button", "Money") |> render_click()
      ctx.luca |> element("button", "Time") |> render_click()

      host_html = render(ctx.host)
      assert host_html =~ "extra turn"
      assert host_html =~ "control"
    end
  end

  # -- Secret Council (secret, simultaneous) --

  describe "Secret Council voting" do
    setup %{conn: conn} do
      {host, players, _room} = create_game(conn, ["Emilio", "Marco", "Luca"])

      %{conn: conn, host: host, marco: players["Marco"], luca: players["Luca"]}
    end

    test "Elrond: votes are hidden until all players have voted", ctx do
      ctx.host |> element("button", "Elrond of the White Council") |> render_click()

      # Host and Marco vote
      ctx.host |> element("button", "Fellowship") |> render_click()
      ctx.marco |> element("button", "Aid") |> render_click()

      # Host sees "Vote submitted", results not yet visible
      host_html = render(ctx.host)
      assert host_html =~ "Vote submitted"
      refute host_html =~ "Emilio voted"

      # Luca votes; all revealed
      ctx.luca |> element("button", "Fellowship") |> render_click()

      host_html = render(ctx.host)
      assert host_html =~ "Emilio voted"
      assert host_html =~ "Marco voted"
      assert host_html =~ "Luca voted"
      assert host_html =~ "Fellowship"
      assert host_html =~ "Aid"
    end

    test "Cirdan: players vote for a player from the list", ctx do
      ctx.host |> element("button", "Cirdan the Shipwright") |> render_click()

      # Host sees player names as vote options
      host_html = render(ctx.host)
      assert has_element?(ctx.host, "button", "Emilio")
      assert has_element?(ctx.host, "button", "Marco")
      assert has_element?(ctx.host, "button", "Luca")

      # All players vote
      ctx.host |> element("button", "Marco") |> render_click()
      ctx.marco |> element("button", "Marco") |> render_click()
      ctx.luca |> element("button", "Emilio") |> render_click()

      host_html = render(ctx.host)
      assert host_html =~ "Marco"
      assert host_html =~ "draws"
      assert host_html =~ "Luca"
      assert host_html =~ "permanent"
    end

    test "Trap the Trespassers: free-text creature input", ctx do
      ctx.host |> element("button", "Trap the Trespassers") |> render_click()

      assert has_element?(ctx.host, "input[name='creature']")

      ctx.host |> form("form", %{"creature" => "Sol Ring"}) |> render_submit()
      ctx.marco |> form("form", %{"creature" => "Sol Ring"}) |> render_submit()
      ctx.luca |> form("form", %{"creature" => "Beast Whisperer"}) |> render_submit()

      host_html = render(ctx.host)
      assert host_html =~ "Sol Ring"
      assert host_html =~ "2"
      assert host_html =~ "Beast Whisperer"
      assert host_html =~ "1"
      assert host_html =~ "stun"
    end
  end

  # -- Vote Modifiers --

  describe "Erestor payoff" do
    test "resolution shows Erestor trigger summary", %{conn: conn} do
      {host, players, _room} = create_game(conn, ["Emilio", "Marco", "Luca"])

      host |> element("button", "Plea for Power") |> render_click()

      # Emilio (caster) votes Time from host
      host |> element("button", "Time") |> render_click()
      # Marco votes Time (matches caster)
      players["Marco"] |> element("button", "Time") |> render_click()
      # Luca votes Knowledge (doesn't match)
      players["Luca"] |> element("button", "Knowledge") |> render_click()

      host_html = render(host)
      assert host_html =~ "Erestor"
      assert host_html =~ "Treasure"
      assert host_html =~ "scry"
    end
  end

  describe "Model of Unity payoff" do
    test "resolution shows Model of Unity scry info", %{conn: conn} do
      {host, players, _room} = create_game(conn, ["Emilio", "Marco", "Luca"])

      host |> element("button", "Plea for Power") |> render_click()

      host |> element("button", "Time") |> render_click()
      players["Marco"] |> element("button", "Time") |> render_click()
      players["Luca"] |> element("button", "Knowledge") |> render_click()

      host_html = render(host)
      assert host_html =~ "Model of Unity"
      assert host_html =~ "scry 2"
    end
  end

  describe "Illusion of Choice" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      game_view |> element("button", "Emilio") |> render_click()

      %{game_view: game_view}
    end

    test "toggling Illusion of Choice lets caster set all votes", %{game_view: view} do
      view |> element("button", "Illusion of Choice") |> render_click()

      html = render(view)
      assert html =~ "Illusion of Choice"
      assert html =~ "active"

      view |> element("button", "Expropriate") |> render_click()

      html = render(view)
      assert html =~ "choose for all"

      html = view |> element("button", "Time") |> render_click()

      assert html =~ "Time"
      assert html =~ "3"
    end

    test "Illusion of Choice overrides Secret Council secrecy", %{game_view: view} do
      view |> element("button", "Illusion of Choice") |> render_click()

      view |> element("button", "Elrond of the White Council") |> render_click()

      html = view |> element("button", "Fellowship") |> render_click()

      assert html =~ "Fellowship"
      assert html =~ "3"
    end
  end

  # -- Multi-device Mode --

  describe "multi-device mode" do
    test "game page shows a room code for sharing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, _game_view, html} = live(conn, path)

      assert html =~ "room"
    end

    test "player can join via room code", %{conn: conn} do
      {:ok, host_view, _html} = live(conn, ~p"/")

      host_view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {game_path, _flash} = assert_redirect(host_view)
      "/game/" <> room_code = game_path

      {:ok, join_view, html} = live(conn, ~p"/join/#{room_code}")
      assert html =~ "Who are you?"

      html = join_view |> element("button", "Marco") |> render_click()
      assert html =~ "Waiting for host"
    end

    test "joining a nonexistent room shows an error", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/join/nonexistent")

      assert html =~ "Room not found"
    end
  end

  # -- Multi-device Voting --

  describe "multi-device voting" do
    setup %{conn: conn} do
      {host, players, room_code} = create_game(conn, ["Emilio", "Marco", "Luca"])

      %{host: host, marco: players["Marco"], luca: players["Luca"], room_code: room_code}
    end

    test "host selects a card and players see it on their devices", ctx do
      ctx.host |> element("button", "Plea for Power") |> render_click()

      marco_html = render(ctx.marco)
      luca_html = render(ctx.luca)

      assert marco_html =~ "Plea for Power"
      assert luca_html =~ "Plea for Power"
    end

    test "public vote: host votes first, then players on their devices", ctx do
      ctx.host |> element("button", "Expropriate") |> render_click()

      # Host (Emilio) votes first
      ctx.host |> element("button", "Time") |> render_click()

      # Marco's turn
      marco_html = render(ctx.marco)
      assert marco_html =~ "Marco"
      ctx.marco |> element("button", "Money") |> render_click()

      # Luca's turn
      luca_html = render(ctx.luca)
      assert luca_html =~ "Luca"
      ctx.luca |> element("button", "Time") |> render_click()

      # All devices show results
      host_html = render(ctx.host)
      marco_html = render(ctx.marco)
      luca_html = render(ctx.luca)

      assert host_html =~ "Time"
      assert host_html =~ "2"
      assert marco_html =~ "Time"
      assert luca_html =~ "Money"
    end

    test "secret vote: host and players vote simultaneously", ctx do
      ctx.host |> element("button", "Elrond of the White Council") |> render_click()

      ctx.host |> element("button", "Fellowship") |> render_click()
      ctx.marco |> element("button", "Aid") |> render_click()

      # Results not yet visible (Luca hasn't voted)
      host_html = render(ctx.host)
      refute host_html =~ "Emilio voted"

      ctx.luca |> element("button", "Fellowship") |> render_click()

      host_html = render(ctx.host)
      marco_html = render(ctx.marco)
      luca_html = render(ctx.luca)

      assert host_html =~ "Emilio voted"
      assert host_html =~ "Marco voted"
      assert marco_html =~ "Fellowship"
      assert luca_html =~ "Aid"
    end

    test "host starts new vote and all devices return to card select", ctx do
      ctx.host |> element("button", "Plea for Power") |> render_click()
      ctx.host |> element("button", "Time") |> render_click()
      ctx.marco |> element("button", "Knowledge") |> render_click()
      ctx.luca |> element("button", "Time") |> render_click()

      ctx.host |> element("button", "New Vote") |> render_click()

      marco_html = render(ctx.marco)
      luca_html = render(ctx.luca)

      assert marco_html =~ "Waiting"
      assert luca_html =~ "Waiting"
    end
  end

  # -- Card Data Completeness --

  describe "card data" do
    test "each Will of the Council card shows correct options" do
      cards_and_options = [
        {"Coercive Portal", ["Carnage", "Homage"]},
        {"Galadriel, Elven-Queen", ["Dominion", "Guidance"]},
        {"Plea for Power", ["Time", "Knowledge"]},
        {"Sail into the West", ["Return", "Embark"]},
        {"Split Decision", ["Denial", "Duplication"]}
      ]

      for {card, [opt_a, opt_b]} <- cards_and_options do
        card_data = ElvenCouncil.Cards.get(card)
        assert card_data.mechanic == :will_of_the_council
        assert card_data.options == [opt_a, opt_b]
      end
    end

    test "each Council's Dilemma card shows correct options" do
      cards_and_options = [
        {"Expropriate", ["Time", "Money"]},
        {"Messenger Jays", ["Feather", "Quill"]},
        {"Selvala's Stampede", ["Wild", "Free"]},
        {"Travel Through Caradhras", ["Redhorn Pass", "Mines of Moria"]},
        {"Emissary Green", ["Profit", "Security"]}
      ]

      for {card, [opt_a, opt_b]} <- cards_and_options do
        card_data = ElvenCouncil.Cards.get(card)
        assert card_data.mechanic in [:councils_dilemma, :unnamed_voting]
        assert card_data.options == [opt_a, opt_b]
      end
    end

    test "each Secret Council card has correct vote type" do
      elrond = ElvenCouncil.Cards.get("Elrond of the White Council")
      assert elrond.mechanic == :secret_council
      assert elrond.options == ["Fellowship", "Aid"]

      cirdan = ElvenCouncil.Cards.get("Cirdan the Shipwright")
      assert cirdan.mechanic == :secret_council
      assert cirdan.vote_type == :player

      trap = ElvenCouncil.Cards.get("Trap the Trespassers")
      assert trap.mechanic == :secret_council
      assert trap.vote_type == :free_text
    end
  end

  # -- New Vote After Resolution --

  describe "starting a new vote after resolution" do
    test "after a vote resolves, can start a new vote", %{conn: conn} do
      {host, players, _room} = create_game(conn, ["Emilio", "Marco"])

      host |> element("button", "Plea for Power") |> render_click()
      host |> element("button", "Time") |> render_click()
      players["Marco"] |> element("button", "Knowledge") |> render_click()

      html = host |> element("button", "New Vote") |> render_click()

      assert html =~ "Coercive Portal"
      assert html =~ "Expropriate"
    end
  end
end
