# ADR-001: Elven Council - MTG Voting App

**Status:** Proposed  
**Date:** 2026-04-07

## Context

Emilio's EDH deck "Elven Council Gang" (Erestor of the Council / Cirdan the Shipwright) heavily features MTG voting mechanics. 16 cards in the deck interact with voting across four distinct mechanic types. Physical play struggles with Secret Council cards (Cirdan, Elrond of the White Council, Trap the Trespassers) where votes must be simultaneous and hidden.

The app must support two usage modes: passing a single phone around the table, and each player voting on their own device via a shared link.

## Decision

Build a Phoenix LiveView application that manages MTG voting sessions, self-hosted on thinkpad-home-server.

### Voting Mechanics

The app supports four mechanic types, each with different voting and resolution rules:

#### 1. Will of the Council
Public, sequential voting. Two fixed options per card. Majority wins; ties resolve to the second option.

| Card                   | Option A    | Option B    |
|------------------------|-------------|-------------|
| Coercive Portal        | Carnage     | Homage      |
| Galadriel, Elven-Queen | Dominion    | Guidance    |
| Plea for Power         | Time        | Knowledge   |
| Sail into the West     | Return      | Embark      |
| Split Decision         | Denial      | Duplication |

#### 2. Council's Dilemma
Public, sequential voting. Two fixed options per card. Each vote counts individually (effects scale with vote count).

| Card                     | Option A      | Option B        |
|--------------------------|---------------|-----------------|
| Expropriate              | Time          | Money           |
| Messenger Jays           | Feather       | Quill           |
| Selvala's Stampede        | Wild          | Free            |
| Travel Through Caradhras | Redhorn Pass  | Mines of Moria  |

#### 3. Unnamed Voting (Council's Dilemma behavior)
Public, sequential. Each vote scales the effect individually.

| Card           | Option A | Option B  |
|----------------|----------|-----------|
| Emissary Green | Profit   | Security  |

#### 4. Secret Council
Secret, simultaneous voting. Votes are hidden until all players have voted, then revealed together.

| Card                        | Vote Target         | Notes                                          |
|-----------------------------|---------------------|-------------------------------------------------|
| Cirdan the Shipwright        | A player            | Voted players draw; unvoted players cheat in permanents |
| Elrond of the White Council  | Fellowship / Aid    | Two fixed options                              |
| Trap the Trespassers         | A creature (by name)| Free-text input; voter names a creature        |

#### Vote Modifiers (not voteable cards themselves)
- **Erestor of the Council**: triggers after any vote resolves. The app should display the Erestor payoff summary (who matched the caster's vote, who didn't) after each resolution.
- **Illusion of Choice**: the caster chooses all votes. The app should offer an "Illusion of Choice" toggle that lets one player set every vote.
- **Model of Unity**: triggers after any vote resolves. The app should flag which players matched the caster's vote (eligible for scry 2).

### Inputs

- **Game setup**: list of player names in turn order
- **Start a vote**: select a card from the 13 voteable cards
- **Cast vote**: each player selects their option (or types a name for Cirdan/Trap)
- **Illusion of Choice toggle**: when active, one player sets all votes

### Outputs

- **During voting**: current voter prompt (public) or waiting screen (secret)
- **After voting**: vote tally, resolution summary per mechanic type, Erestor/Model of Unity payoff info
- **Illusion of Choice**: visual indicator that votes are being overridden

### User Flows

#### Single-device mode (pass the phone)
1. Host creates a game, enters player names in turn order
2. Host selects a card to vote on
3. For public votes: phone is passed to each player in turn order; after voting, screen shows "pass to next player" with vote hidden
4. For secret votes: phone is passed to each player; vote is hidden after submission; after all players vote, results are revealed
5. Resolution screen shows tally and effect summary

#### Multi-device mode (shared link)
1. Host creates a game, gets a room code/link
2. Players join by opening the link and entering their name
3. Host selects a card to vote on
4. Each player votes on their own device
5. For public votes: votes appear in real-time as each player submits (in turn order; next player is prompted after previous submits)
6. For secret votes: all players vote simultaneously; "waiting for votes" until everyone submits; then all votes revealed at once
7. Resolution screen pushed to all devices via LiveView

### Edge Cases

- **Player disconnects in multi-device mode**: vote pauses; host can kick or wait for reconnect
- **Illusion of Choice + Secret Council**: Illusion overrides secrecy; all votes are chosen by the caster, revealed immediately
- **Trap the Trespassers free-text input**: no validation against actual board state (players are trusted); input is just a text field
- **Cirdan free-text input**: player name selection from the game's player list (dropdown, not free-text)
- **Tie in Will of the Council**: second option wins (per MTG rules)

### Error Conditions

- Game with fewer than 2 players: rejected at creation
- Duplicate player names: rejected at creation
- Voting on a card while another vote is in progress: blocked
- Joining a room that doesn't exist: error message, redirect to home

## Tech Stack

- **Elixir + Phoenix LiveView**: real-time UI, both modes use LiveView (single-device is one LiveView; multi-device uses PubSub for sync)
- **No database**: game state lives in-process (GenServer per room). Games are ephemeral; no persistence needed.
- **Deployment**: Docker container on thinkpad-home-server, exposed on local network

## Consequences

- All card data and voting rules are hardcoded; adding new voting cards requires a code change
- No authentication; anyone with the link can join (acceptable for private play)
- Game state is lost on server restart (acceptable for ephemeral game sessions)
