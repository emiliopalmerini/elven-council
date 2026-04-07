defmodule ElvenCouncil.Cards do
  @cards %{
    "Coercive Portal" => %{
      mechanic: :will_of_the_council,
      options: ["Carnage", "Homage"],
      resolution: %{
        "Carnage" => "Sacrifice Coercive Portal and destroy all nonland permanents",
        "Homage" => "Draw a card"
      },
      image: "https://cards.scryfall.io/art_crop/front/1/8/18e8c013-1a56-4894-a4f5-6ec564bcbe9b.jpg"
    },
    "Galadriel, Elven-Queen" => %{
      mechanic: :will_of_the_council,
      options: ["Dominion", "Guidance"],
      resolution: %{
        "Dominion" => "The Ring tempts you, then put a +1/+1 counter on your Ring-bearer",
        "Guidance" => "Draw a card"
      },
      image: "https://cards.scryfall.io/art_crop/front/8/f/8fa46d54-563d-4b5c-9c69-5ab37dd529b3.jpg"
    },
    "Plea for Power" => %{
      mechanic: :will_of_the_council,
      options: ["Time", "Knowledge"],
      resolution: %{
        "Time" => "Take an extra turn after this one",
        "Knowledge" => "Draw three cards"
      },
      image: "https://cards.scryfall.io/art_crop/front/9/f/9f810725-4da0-460f-b50e-a7ff05aa4c00.jpg"
    },
    "Sail into the West" => %{
      mechanic: :will_of_the_council,
      options: ["Return", "Embark"],
      resolution: %{
        "Return" => "Each player returns up to two cards from their graveyard to their hand",
        "Embark" => "Each player may discard their hand and draw seven cards"
      },
      image: "https://cards.scryfall.io/art_crop/front/b/2/b293d4cb-0920-46ef-bf4e-fc6a796df290.jpg"
    },
    "Split Decision" => %{
      mechanic: :will_of_the_council,
      options: ["Denial", "Duplication"],
      resolution: %{
        "Denial" => "Counter the spell",
        "Duplication" => "Copy the spell; you may choose new targets for the copy"
      },
      image: "https://cards.scryfall.io/art_crop/front/8/3/83ed7ebe-48be-4e6e-a293-b81484f85142.jpg"
    },
    "Expropriate" => %{
      mechanic: :councils_dilemma,
      options: ["Time", "Money"],
      resolution: %{
        "Time" => "Take an extra turn after this one for each Time vote",
        "Money" => "Choose a permanent owned by the voter and gain control of it"
      },
      image: "https://cards.scryfall.io/art_crop/front/9/c/9c8a2a5a-cb9b-4582-a453-085da78584f9.jpg"
    },
    "Messenger Jays" => %{
      mechanic: :councils_dilemma,
      options: ["Feather", "Quill"],
      resolution: %{
        "Feather" => "Put a +1/+1 counter on Messenger Jays for each Feather vote",
        "Quill" => "Draw a card for each Quill vote, then discard that many cards"
      },
      image: "https://cards.scryfall.io/art_crop/front/1/f/1fe7a4f0-d677-4ae2-883c-eb46d0999584.jpg"
    },
    "Selvala's Stampede" => %{
      mechanic: :councils_dilemma,
      options: ["Wild", "Free"],
      resolution: %{
        "Wild" => "Reveal cards from the top of your library until you reveal a creature card for each Wild vote; put those creatures onto the battlefield",
        "Free" => "Put a permanent card from your hand onto the battlefield for each Free vote"
      },
      image: "https://cards.scryfall.io/art_crop/front/b/8/b84e46c2-f3ea-49ff-8f8b-58aa6a1175a4.jpg"
    },
    "Travel Through Caradhras" => %{
      mechanic: :councils_dilemma,
      options: ["Redhorn Pass", "Mines of Moria"],
      resolution: %{
        "Redhorn Pass" => "Search your library for a basic land card and put it onto the battlefield tapped for each Redhorn Pass vote",
        "Mines of Moria" => "Return a card from your graveyard to your hand for each Mines of Moria vote"
      },
      image: "https://cards.scryfall.io/art_crop/front/9/5/955058b2-9758-4797-8ffc-c5fbee619309.jpg"
    },
    "Emissary Green" => %{
      mechanic: :councils_dilemma,
      options: ["Profit", "Security"],
      resolution: %{
        "Profit" => "Create two Treasure tokens for each Profit vote",
        "Security" => "Put a +1/+1 counter on each creature you control for each Security vote"
      },
      image: "https://cards.scryfall.io/art_crop/front/3/2/323e9430-b87c-4b02-9ade-c4c65343147b.jpg"
    },
    "Cirdan the Shipwright" => %{
      mechanic: :secret_council,
      vote_type: :player,
      options: :players,
      resolution: %{
        "voted" => "Each player draws a card for each vote they received",
        "unvoted" => "Each player who received no votes may put a permanent card from their hand onto the battlefield"
      },
      image: "https://cards.scryfall.io/art_crop/front/c/4/c4f23d68-d0de-4b57-b0f9-9c0ca770c3c1.jpg"
    },
    "Elrond of the White Council" => %{
      mechanic: :secret_council,
      vote_type: :fixed,
      options: ["Fellowship", "Aid"],
      resolution: %{
        "Fellowship" => "The voter chooses a creature they control; you gain control of it",
        "Aid" => "Put a +1/+1 counter on each creature you control"
      },
      image: "https://cards.scryfall.io/art_crop/front/4/c/4cdfb792-fe55-4aa0-88df-4296db794bc5.jpg"
    },
    "Trap the Trespassers" => %{
      mechanic: :secret_council,
      vote_type: :free_text,
      options: :free_text,
      resolution: %{
        "voted" => "Put that many stun counters on the creature, then tap it"
      },
      image: "https://cards.scryfall.io/art_crop/front/a/0/a077a046-300b-41d2-b891-c57ebe983ba2.jpg"
    }
  }

  def all, do: @cards

  def get(name), do: Map.fetch!(@cards, name)

  def voteable_names, do: Map.keys(@cards)

  def mechanic_label(:will_of_the_council), do: "Will of the Council"
  def mechanic_label(:councils_dilemma), do: "Council's Dilemma"
  def mechanic_label(:secret_council), do: "Secret Council"

  def mechanic_rule(:will_of_the_council), do: "Majority wins. Ties resolve to the second option."
  def mechanic_rule(:councils_dilemma), do: "Each vote counts individually; effects scale with vote count."
  def mechanic_rule(:secret_council), do: "Votes are secret and simultaneous. Revealed when all players have voted."
end
