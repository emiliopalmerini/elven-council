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
      assert html =~ "Selvala's Stampede"
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

      html =
        view
        |> element("button", "Expropriate")
        |> render_click()

      assert html =~ "vote already in progress"
    end
  end

  # -- Will of the Council (public, sequential, majority wins) --

  describe "Will of the Council voting" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      game_view
      |> element("button", "Plea for Power")
      |> render_click()

      %{game_view: game_view}
    end

    test "players vote sequentially in turn order", %{game_view: view} do
      html = render(view)
      assert html =~ "Emilio"

      view |> element("button", "Time") |> render_click()
      html = render(view)
      assert html =~ "pass to"

      view |> element("button", "Ready") |> render_click()
      html = render(view)
      assert html =~ "Marco"
    end

    test "majority wins the vote", %{game_view: view} do
      # Emilio votes Time
      view |> element("button", "Time") |> render_click()
      view |> element("button", "Ready") |> render_click()

      # Marco votes Time
      view |> element("button", "Time") |> render_click()
      view |> element("button", "Ready") |> render_click()

      # Luca votes Knowledge
      html = view |> element("button", "Knowledge") |> render_click()

      assert html =~ "Time"
      assert html =~ "wins"
    end

    test "tie resolves to the second option", %{game_view: view} do
      # Need an even number of players for a tie; re-setup with 4 players
      # This test uses Coercive Portal with 2 players for a 1-1 tie
    end
  end

  describe "Will of the Council tie resolution" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      game_view
      |> element("button", "Coercive Portal")
      |> render_click()

      %{game_view: game_view}
    end

    test "tie resolves to the second option (Homage)", %{game_view: view} do
      # Emilio votes Carnage
      view |> element("button", "Carnage") |> render_click()
      view |> element("button", "Ready") |> render_click()

      # Marco votes Homage
      html = view |> element("button", "Homage") |> render_click()

      assert html =~ "Homage"
      assert html =~ "wins"
    end
  end

  # -- Council's Dilemma (public, sequential, each vote scales) --

  describe "Council's Dilemma voting" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      game_view
      |> element("button", "Expropriate")
      |> render_click()

      %{game_view: game_view}
    end

    test "resolution shows individual vote counts", %{game_view: view} do
      # Emilio votes Time
      view |> element("button", "Time") |> render_click()
      view |> element("button", "Ready") |> render_click()

      # Marco votes Money
      view |> element("button", "Money") |> render_click()
      view |> element("button", "Ready") |> render_click()

      # Luca votes Time
      html = view |> element("button", "Time") |> render_click()

      assert html =~ "Time"
      assert html =~ "2"
      assert html =~ "Money"
      assert html =~ "1"
    end

    test "resolution describes per-vote effects", %{game_view: view} do
      view |> element("button", "Time") |> render_click()
      view |> element("button", "Ready") |> render_click()

      view |> element("button", "Money") |> render_click()
      view |> element("button", "Ready") |> render_click()

      html = view |> element("button", "Time") |> render_click()

      # Should describe what happens for each vote
      assert html =~ "extra turn"
      assert html =~ "control"
    end
  end

  # -- Secret Council (secret, simultaneous) --

  describe "Secret Council voting (single-device)" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      %{game_view: game_view}
    end

    test "Elrond: votes are hidden until all players have voted", %{game_view: view} do
      view
      |> element("button", "Elrond of the White Council")
      |> render_click()

      # Emilio votes Fellowship
      view |> element("button", "Fellowship") |> render_click()
      html = view |> element("button", "Ready") |> render_click()

      # After passing, previous vote should not be visible
      refute html =~ "Fellowship"
      assert html =~ "Marco"

      # Marco votes Aid
      view |> element("button", "Aid") |> render_click()
      html = view |> element("button", "Ready") |> render_click()

      refute html =~ "Aid"
      assert html =~ "Luca"

      # Luca votes Fellowship - all votes revealed
      html = view |> element("button", "Fellowship") |> render_click()

      assert html =~ "Fellowship"
      assert html =~ "Aid"
      assert html =~ "2"
      assert html =~ "1"
    end

    test "Cirdan: players vote for a player from the list", %{game_view: view} do
      view
      |> element("button", "Cirdan the Shipwright")
      |> render_click()

      html = render(view)

      # Should show player names as vote options
      assert has_element?(view, "button", "Emilio")
      assert has_element?(view, "button", "Marco")
      assert has_element?(view, "button", "Luca")

      # Emilio votes for Marco
      view |> element("button", "Marco") |> render_click()
      view |> element("button", "Ready") |> render_click()

      # Marco votes for Marco
      view |> element("button", "Marco") |> render_click()
      view |> element("button", "Ready") |> render_click()

      # Luca votes for Emilio - all revealed
      html = view |> element("button", "Emilio") |> render_click()

      # Marco got 2 votes (draws 2), Emilio got 1 vote (draws 1), Luca got 0 (cheats permanent)
      assert html =~ "Marco"
      assert html =~ "draws"
      assert html =~ "Luca"
      assert html =~ "permanent"
    end

    test "Trap the Trespassers: free-text creature input", %{game_view: view} do
      view
      |> element("button", "Trap the Trespassers")
      |> render_click()

      assert has_element?(view, "input[name='creature']")

      # Emilio votes for a creature
      view
      |> form("form", %{"creature" => "Sol Ring"})
      |> render_submit()

      view |> element("button", "Ready") |> render_click()

      # Marco votes for same creature
      view
      |> form("form", %{"creature" => "Sol Ring"})
      |> render_submit()

      view |> element("button", "Ready") |> render_click()

      # Luca votes for different creature
      html =
        view
        |> form("form", %{"creature" => "Beast Whisperer"})
        |> render_submit()

      # Resolution shows stun counters per creature
      assert html =~ "Sol Ring"
      assert html =~ "2"
      assert html =~ "Beast Whisperer"
      assert html =~ "1"
      assert html =~ "stun"
    end
  end

  # -- Vote Modifiers --

  describe "Erestor payoff" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      %{game_view: game_view}
    end

    test "resolution shows Erestor trigger summary", %{game_view: view} do
      view
      |> element("button", "Plea for Power")
      |> render_click()

      # Emilio (caster, first in turn order) votes Time
      view |> element("button", "Time") |> render_click()
      view |> element("button", "Ready") |> render_click()

      # Marco votes Time (matches caster)
      view |> element("button", "Time") |> render_click()
      view |> element("button", "Ready") |> render_click()

      # Luca votes Knowledge (doesn't match caster)
      html = view |> element("button", "Knowledge") |> render_click()

      # Erestor: opponents who matched get a Treasure; scry X where X = opponents who didn't match
      assert html =~ "Erestor"
      assert html =~ "Treasure"
      assert html =~ "scry"
    end
  end

  describe "Model of Unity payoff" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      %{game_view: game_view}
    end

    test "resolution shows Model of Unity scry info", %{game_view: view} do
      view
      |> element("button", "Plea for Power")
      |> render_click()

      view |> element("button", "Time") |> render_click()
      view |> element("button", "Ready") |> render_click()

      view |> element("button", "Time") |> render_click()
      view |> element("button", "Ready") |> render_click()

      html = view |> element("button", "Knowledge") |> render_click()

      assert html =~ "Model of Unity"
      assert html =~ "scry 2"
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

      %{game_view: game_view}
    end

    test "toggling Illusion of Choice lets caster set all votes", %{game_view: view} do
      # Enable Illusion of Choice
      view |> element("button", "Illusion of Choice") |> render_click()

      html = render(view)
      assert html =~ "Illusion of Choice"
      assert html =~ "active"

      # Start a vote
      view
      |> element("button", "Expropriate")
      |> render_click()

      # Caster chooses all votes at once
      html = render(view)
      assert html =~ "choose"

      # All players' votes are set by the caster
      html =
        view
        |> element("button", "Time")
        |> render_click()

      # Resolution: all 3 votes are Time
      assert html =~ "Time"
      assert html =~ "3"
    end

    test "Illusion of Choice overrides Secret Council secrecy", %{game_view: view} do
      view |> element("button", "Illusion of Choice") |> render_click()

      view
      |> element("button", "Elrond of the White Council")
      |> render_click()

      # Caster sets all votes, no secret phase
      html =
        view
        |> element("button", "Fellowship")
        |> render_click()

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
      {:ok, game_view, html} = live(conn, path)

      assert html =~ "room"
    end

    test "player can join via room code", %{conn: conn} do
      # Host creates game
      {:ok, host_view, _html} = live(conn, ~p"/")

      host_view
      |> form("form", %{"players" => ["Emilio", "Marco", "Luca"]})
      |> render_submit()

      {game_path, _flash} = assert_redirect(host_view)

      # Extract room code from path
      "/game/" <> room_code = game_path

      # Player joins
      {:ok, join_view, html} = live(conn, ~p"/join/#{room_code}")
      assert html =~ "join"
    end

    test "joining a nonexistent room shows an error", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/join/nonexistent")

      assert html =~ "not found"
    end
  end

  # -- Card Data Completeness --

  describe "card data" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      %{game_view: game_view}
    end

    test "each Will of the Council card shows correct options", %{game_view: view} do
      cards_and_options = [
        {"Coercive Portal", ["Carnage", "Homage"]},
        {"Galadriel, Elven-Queen", ["Dominion", "Guidance"]},
        {"Plea for Power", ["Time", "Knowledge"]},
        {"Sail into the West", ["Return", "Embark"]},
        {"Split Decision", ["Denial", "Duplication"]}
      ]

      for {card, [opt_a, opt_b]} <- cards_and_options do
        {:ok, fresh_view, _html} = live(view.module, view)

        # We verify the card data module directly instead of clicking through UI
        # (clicking would start a vote and block the next card)
        card_data = ElvenCouncil.Cards.get(card)
        assert card_data.mechanic == :will_of_the_council
        assert card_data.options == [opt_a, opt_b]
      end
    end

    test "each Council's Dilemma card shows correct options", %{game_view: _view} do
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

    test "each Secret Council card has correct vote type", %{game_view: _view} do
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
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{"players" => ["Emilio", "Marco"]})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      {:ok, game_view, _html} = live(conn, path)

      %{game_view: game_view}
    end

    test "after a vote resolves, can start a new vote", %{game_view: view} do
      # Complete a vote
      view |> element("button", "Plea for Power") |> render_click()
      view |> element("button", "Time") |> render_click()
      view |> element("button", "Ready") |> render_click()
      view |> element("button", "Knowledge") |> render_click()

      # Should be able to dismiss results and start a new vote
      html = view |> element("button", "New Vote") |> render_click()

      assert html =~ "Coercive Portal"
      assert html =~ "Expropriate"
    end
  end
end
