defmodule ElvenCouncil.Cards do
  @cards %{
    "Coercive Portal" => %{
      mechanic: :will_of_the_council,
      options: ["Carnage", "Homage"],
      resolution: %{
        "Carnage" => "Sacrifice Coercive Portal and destroy all nonland permanents",
        "Homage" => "Draw a card"
      }
    },
    "Galadriel, Elven-Queen" => %{
      mechanic: :will_of_the_council,
      options: ["Dominion", "Guidance"],
      resolution: %{
        "Dominion" => "The Ring tempts you, then put a +1/+1 counter on your Ring-bearer",
        "Guidance" => "Draw a card"
      }
    },
    "Plea for Power" => %{
      mechanic: :will_of_the_council,
      options: ["Time", "Knowledge"],
      resolution: %{
        "Time" => "Take an extra turn after this one",
        "Knowledge" => "Draw three cards"
      }
    },
    "Sail into the West" => %{
      mechanic: :will_of_the_council,
      options: ["Return", "Embark"],
      resolution: %{
        "Return" => "Each player returns up to two cards from their graveyard to their hand",
        "Embark" => "Each player may discard their hand and draw seven cards"
      }
    },
    "Split Decision" => %{
      mechanic: :will_of_the_council,
      options: ["Denial", "Duplication"],
      resolution: %{
        "Denial" => "Counter the spell",
        "Duplication" => "Copy the spell; you may choose new targets for the copy"
      }
    },
    "Expropriate" => %{
      mechanic: :councils_dilemma,
      options: ["Time", "Money"],
      resolution: %{
        "Time" => "Take an extra turn after this one for each Time vote",
        "Money" => "Choose a permanent owned by the voter and gain control of it"
      }
    },
    "Messenger Jays" => %{
      mechanic: :councils_dilemma,
      options: ["Feather", "Quill"],
      resolution: %{
        "Feather" => "Put a +1/+1 counter on Messenger Jays for each Feather vote",
        "Quill" => "Draw a card for each Quill vote, then discard that many cards"
      }
    },
    "Selvala's Stampede" => %{
      mechanic: :councils_dilemma,
      options: ["Wild", "Free"],
      resolution: %{
        "Wild" => "Reveal cards from the top of your library until you reveal a creature card for each Wild vote; put those creatures onto the battlefield",
        "Free" => "Put a permanent card from your hand onto the battlefield for each Free vote"
      }
    },
    "Travel Through Caradhras" => %{
      mechanic: :councils_dilemma,
      options: ["Redhorn Pass", "Mines of Moria"],
      resolution: %{
        "Redhorn Pass" => "Search your library for a basic land card and put it onto the battlefield tapped for each Redhorn Pass vote",
        "Mines of Moria" => "Return a card from your graveyard to your hand for each Mines of Moria vote"
      }
    },
    "Emissary Green" => %{
      mechanic: :councils_dilemma,
      options: ["Profit", "Security"],
      resolution: %{
        "Profit" => "Create two Treasure tokens for each Profit vote",
        "Security" => "Put a +1/+1 counter on each creature you control for each Security vote"
      }
    },
    "Cirdan the Shipwright" => %{
      mechanic: :secret_council,
      vote_type: :player,
      options: :players,
      resolution: %{
        "voted" => "Each player draws a card for each vote they received",
        "unvoted" => "Each player who received no votes may put a permanent card from their hand onto the battlefield"
      }
    },
    "Elrond of the White Council" => %{
      mechanic: :secret_council,
      vote_type: :fixed,
      options: ["Fellowship", "Aid"],
      resolution: %{
        "Fellowship" => "The voter chooses a creature they control; you gain control of it",
        "Aid" => "Put a +1/+1 counter on each creature you control"
      }
    },
    "Trap the Trespassers" => %{
      mechanic: :secret_council,
      vote_type: :free_text,
      options: :free_text,
      resolution: %{
        "voted" => "Put that many stun counters on the creature, then tap it"
      }
    }
  }

  def all, do: @cards

  def get(name), do: Map.fetch!(@cards, name)

  def voteable_names, do: Map.keys(@cards)
end
