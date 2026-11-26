#import "../template.typ": *

= C. Protocol 1.0 <index:c-10>

The protocol of ngspades-server: ENet or WebRTC, a binary codec with varints and masks, the map as ngmap or VXL, entities with delta updates and string commands for the rare things. It is specified in the #l10("packets")[protocol 1.0 page], and the dependency-free #link("https://github.com/ngspades/protocol/tree/main/examples")[C and Godot examples] implement the codec this part requires.

== C.1 Transport <index:c-transport>

#req("C-NET-1", "Connect with the 1.0 magic and two channels",
  why: [A different connect value is taken for another protocol; one channel loses the unreliable body updates.],
  test: [Connect to a 1.0 server; the first packet must be `Greeting` (id 1).])[
  Use ENet 1.3 (or an ENet-compatible host) with the range coder, *two* channels and connect data `135272729` (`0x08101919`). The default port is `32887`, the same as 0.75. The server accepts IPv4 and IPv6 peers on one socket, so an IPv6-only client works. ENet encryption MUST NOT be enabled: it changes the wire. See #l10("connection")[Connection].]

#req("C-NET-2", "Channel 0 reliable, channel 1 unreliable for your body",
  why: [The server's entity deltas are reliable; yours are positions, and an old one is useless.],
  test: [Capture a minute of play and check where the movement packets go.])[
  Your own body (`Client Side Entity Update`, and an `Entity Update` carrying only a trajectory) goes unreliable on channel 1. Everything else goes reliable on channel 0. An update that must be seen before an action goes reliable on channel 0 (C-OWN-2).]

#req("C-NET-3", "Treat connect refusal as not 1.0 and fall back",
  why: [Public 0.75 servers refuse the 1.0 magic with reason 3 and no `Kick`; some accept any connect data and then speak 0.75.],
  test: [Join a public 0.75 server; you must end up on 0.75 without a hung screen.])[
  A client that also speaks 0.75 SHOULD try 1.0 first and on disconnect reason `3` with no `Kick` reconnect with connect data `3`. A 1.0 connection only counts once `Greeting` has arrived; if any other packet id arrives first (a 0.75 server that accepted the magic), the client MUST drop it and retry as 0.75. Wait a few seconds for the `Greeting`; a far server's refusal can come late.]

#req("C-NET-4", "Strict decoder: reject, ignore, never guess",
  why: [Masks are not self-describing: one unknown bit makes the rest of the packet unmeasurable.],
  test: [Run the codec's golden vectors and the truncation, unknown-bit and oversize cases from the example test suite.])[
  Reject a truncated packet, a varint over 10 bytes, a string over 1 MiB or with a NUL in it, a mask bit the client does not know, and an out-of-range enum. *Ignore* (do not disconnect on) an unknown packet id, an unknown `Generic Command`, an unknown world parameter or map key. Primitives: little-endian fixed-width values, `Varint` (unsigned LEB128, at most 10 bytes), `Svarint` (zigzag then varint), `Bytes` (varint length, at most 1 MiB), `String` (UTF-8 bytes, no NUL), `Map` (key and value strings, ended by an empty key). See #l10("data-types")[Data Types].]

#req("C-NET-5", "Disconnect reasons of 1.0 are another table",
  why: [The same field means something else on each protocol, and `3` is both "kicked" (1.0) and "wrong protocol" (vanilla).],
  test: [Kick yourself and check you show the `Kick` text; connect to a full server.])[
  The reason is a `Uint32` in the ENet disconnect (or the WebRTC text `disconnect <reason>`). A `Kick` packet (5) with the text precedes reason 3: show the text.

  #table(columns: (auto, 1fr, 1fr),
    table.header([Value], [1.0 meaning], [Note]),
    [0], [unknown], [also an ENet timeout],
    [1], [internal server error], [],
    [2], [server full], [],
    [3], [kicked], [a `Kick` with the text came first. Without one, on a 0.75 connection attempt it means wrong protocol],
    [4], [server stopped], [],
    [5], [timeout], [a handshake step took too long],
    [6], [malformed packet], [],
    [7], [protocol mismatch], [the protocol name was not ours],
  )]

#req("C-NET-6", "Be ready for a handshake and map timeout",
  why: [A client that stalls between steps is dropped; the server does not wait for slow starts.],
  test: [Delay each handshake step on a test client and note when the server disconnects.])[
  The server drops a connection that does not advance through the handshake and the map transfer, with reason 5. A client MUST NOT stall between `Greeting` and the `Client Certificate`, and MUST send its `Map Data Acknowledge` as soon as the map is decoded. The exact budgets are in the server's documentation and have been tightened over time: do not depend on a figure, answer promptly. There is no game-time timeout; ENet's peer timeout applies.]

== C.2 Handshake <index:c-handshake>

#req("C-HS-1", "Follow the handshake order",
  why: [Skipping a step times the connection out.],
  test: [Print the ids sent and received on a join.])[
  ```
  client                                     server
    connect (0x08101919) or WebRTC "connect" ->
              <---------------------------- Greeting (1)
    Initiate Connection (2) --------------->
              <---------------------------- Server Certificate (3)
    Client Certificate (4) ---------------->
              <---------------------------- Game State Header (6)
              <---------------------------- Map Data (7) x N, Map Data Final (11)
    Map Data Acknowledge (10) ------------->   (after decoding)
              <---------------------------- Game State Final (8)
    Generic Command "join <team> <weapon>" ->
              <---------------------------- Generic Command "local-player <id>"
              <---------------------------- Entity Update / Player Update / Terrain Update
  ```
  See #l10("handshake")[Handshake].]

#req("C-HS-2", "Initiate Connection fields",
  why: [A different protocol name is refused with reason 7.],
  test: [Send each field at its limit (256-byte package, 1024-byte environment, 63-byte name).])[
  Packet 2: protocol name `"WorldOfSpades 1.0"`, `Uint16` major `1`, minor `3` (the protocol revision, informational), `Uint16` revision (your build), package (at most 256 bytes), environment (at most 1024), locale such as `pt_BR` (at most 256), player name (UTF-8, at most 63 bytes), a nonce of 256 random bytes and a `Uint8` map quality (`0` = send VXL, `1..100` = ngmap is fine, clamped by the server). The `Greeting`'s nonce of 128 random bytes is what a connect token signs (C-HS-3).]

#req("C-HS-3", "Certificates: isValid 0, or a connect token",
  why: [A UDP join from a non-local address is only admitted with a token from the master; without it the server sends `Kick`.],
  test: [Join a public server from a non-local address with and without the token request.])[
  `Server Certificate` (3) and `Client Certificate` (4) are `Uint8 isValid` (`0`: nothing follows) or `isValid != 0` with certificate and signature as `Bytes`. A client that only needs local play sends `isValid = 0`. To join a public server over UDP, after the `Greeting` the client asks the master for a connect token (`POST /v1/token` with the server address and the base64 `Greeting` nonce) and sends the answer as the client certificate with `isValid = 1`. A token is one connection: never cache it. WebRTC joins and local addresses need none. See #lmaster("our-master-post-v1token")[Connect tokens].]

#req("C-HS-4", "The world may restart at any time",
  why: [A new round restarts the transfer at `Game State Header`; a client that keeps its old state mixes two worlds.],
  test: [End a round on a test server while connected.])[
  A `Game State Header` after the game has started means a world change: drop every entity, the map and the mode state, take the new map, and `join` again. Packets in flight are dropped, not an error.]

== C.3 The map <index:c-map>

#req("C-MAP-1", "Read the Game State Header",
  why: [The header decides which decoder runs and whether the map can be skipped.],
  test: [Log every key of a header.])[
  Packet 6: a `Map` of strings: `map-name`, `map-format` (`ngmap` or `vxl`), `map-size` (`512,512,64` or `1024,1024,64`), `map-bytes` (stream size, for a progress bar), `map-crc32` (CRC32, zlib's, of the exact stream, 8 hex digits). `map-format` decides the decoder, not the quality you asked for. Accept only the map sizes the client supports and refuse the rest before decoding.]

#req("C-MAP-2", "Skip a map you already have: map-cached",
  why: [A cached map is instant; the CRC32 must be of the stream, not of the map, or an edited map loads stale.],
  test: [Join twice; the second join must receive 0 map bytes. Change the map quality and check you download again.])[
  After the header, answer `Generic Command "map-cached 1"` if you hold a stream with that CRC32 and byte count, else `map-cached 0`. The server waits about 3 seconds. On `1` no `Map Data` is sent: go straight to `Map Data Final`, then the rest. The key is the *stream* (its CRC32 and size): two qualities of one map, or the same map after an edit, are different entries. Store a received stream only when its CRC32 matches the header's, and never answer from the cache while recording a demo or on your own local server's map. This is the 1.0 counterpart of 0.76's `Map Cached` (A-076-3).]

#req("C-MAP-3", "Assemble the stream; keep Terrain Updates until the map is ready",
  why: [Edits made during the transfer arrive as `Terrain Update`; discarding them leaves a hole where someone built.],
  test: [Dig continuously with a second client while a third one joins.])[
  Append every `Map Data` (7) fragment in order; `Map Data Final` (11, empty) ends the stream. Decode the map, apply the `Terrain Update`s that arrived meanwhile in order, then acknowledge. The server keeps broadcasting edits to loading connections.]

#req("C-MAP-4", "Always acknowledge",
  why: [`Game State Final` is only sent after it.],
  test: [Delay the decode by 5 s and check the server waits.])[
  After decoding, send `Map Data Acknowledge` (10, one byte, no payload). It is mandatory, also after a cache hit.]

#req("C-MAP-5", "Decode vxl with the 0.75 loader; ngmap with a port, not a rewrite",
  why: [ngmap is about 1,900 lines of codec with JPEG tiles; a summary is not enough to re-implement it.],
  test: [Decode a map from the maps repository and compare it voxel by voxel with its VXL.])[
  `vxl` is the zlib-compressed VXL exactly as 0.75 sends in `Map Chunk`, so one loader serves both. `ngmap` is a zlib stream (signature `0x1145148A`, width, height, depth at most 64, quality, column geometry, JPEG colour tiles, colour blocks). A client that cannot decode it MUST send map quality `0` and use VXL. Otherwise port the reference codec; do not re-implement it from the summary. See #l10("map-formats")[Map Formats].]

#req("C-MAP-6", "Terrain Update: cursor deltas, R G B, one gravity pass",
  why: [Its colour order is the only R, G, B on the 1.0 wire, and its cursor does not follow the edits.],
  test: [Run the two worked examples of the protocol page and a batch that moves the cursor.])[
  Packet 40 is a list of edits to the end of the packet. Each is `Int8 dx, dy, dz` relative to a cursor starting at `(0,0,0)`; `dx = -128` moves the cursor: read `cx, cy, cz` (unsigned varints) then `dx` again. The cursor does *not* follow the edits: deltas are relative to the last explicit cursor. Then `Uint8 health` (0 = destroyed, else created), and for a creation `R, G, B` and a create type (0 unspecified, 1 player), for a destruction a destroy type (0 unspecified, 1 damage, 2 collapse). Health below 100 is a cracked block: draw the crack. Cells marked collapse are falling structures: remove them and build the falling piece from their colours and connections without running a gravity search. Apply a whole packet, then run block physics once. See #l10("terrain-update")[Terrain Update].]

== C.4 Game state and entities <index:c-entities>

#req("C-STATE-1", "Game State Final and world parameters",
  why: [Jump height, fall damage and the fog come from the server; defaults only apply when it says nothing.],
  test: [Start a server with a different jump velocity and check the prediction matches.])[
  Packet 8: a `Map` of world parameters, then every entity and every player already in the match, each as an item with Create. After it the connection is in the game. Parameters are strings parsed as numbers: `player-jump-vel` (default `0.36`), `fall-damage-vel` (`0.58`), `fall-damage-fatal-vel` (`1`), `fog-distance` (`96`, 32 to 256), `fog-color`, `gamemode`, team names and colours, `capture-limit`, `aim-assist`, the jetpack figures and `sentry-lifetime`. Unknown keys are ignored. Predict your own movement with these numbers.]

#req("C-ENT-1", "Entity Update: a delta against the last value",
  why: [Treating an item as a full state resets everything it did not mention.],
  test: [Replay a recorded stream and compare the final entity table with the server's.])[
  Packet 30: `Uint8 forced`, then items to the end of the packet. An item is `Varint entity id`, `Uint8 mask`, and the parts the mask names. Keep the last value of every part and change only what the mask announces. An item for an unknown id without Create is ignored. A body has the same id as its player (`0..255`); every other entity uses `256` and up.]

#req("C-ENT-2", "Field order is not bit order",
  why: [Reading parts in bit order desynchronises the whole packet at the first item that has both Tool and Trajectory.],
  test: [Decode the golden vector with Create, Trajectory and Tool all set.])[
  The parts follow in the order Create, Flags, Trajectory, Player Input, Tool, Block Color, Health (bits `0`, `1`, `2`, `3`, `4`, `5`, `6`). For Player Update items the order is Create (name), Score, Flags, Team, Stats, Ping, Perks. Take both orders from the protocol page, not from the bit numbers.]

#req("C-ENT-3", "Ignore parts for your own entity, unless forced or Create",
  why: [Applying the server's old copy of your body fights your prediction and jitters the view.],
  test: [Walk straight while another client shoots near you; the view must not shudder.])[
  Parts for an entity you own MUST be ignored unless `forced` is set or the item has Create; that is how the server corrects you.]

#req("C-ENT-4", "Trajectories, including the compact player form",
  why: [A body arrives as one of six kinds; the compact one rounds `z` up so a resting body is not inside the floor.],
  test: [Decode type 5 and re-extrapolate; a standing body must not bob.])[
  Type byte: low 7 bits the kind (`0` Constant, `1` Linear, `2` Gravity with `g = (0,0,32)`, `3` Player, `4` Rigid Body, `5` Player Compact), bit 7 a parent follows. Player Compact is 17 bytes: origin x and y as `Uint16 * 64`, origin z as `Int16 * 64` rounded *up* (toward the sky), velocity as `Int16 * 1024`, pitch `* 32767 / (pi/2)`, yaw `* 32767 / pi`, then the parent. Decode it as an ordinary player trajectory. A client sends its own trajectory as floats. Entity flags: bit 0 `playerClip`, 1 `weaponClip`, 2 `fly`, 3 `jetpack`; bits 4 to 7 are invalid. Player input: bit 0 primary, 1 secondary, 2 chat, 3 sprint, 4 jetpack thrust, 6 to 7 stance (0 stand, 1 crouch, 2 prone); `xmove`, `ymove` in -127..127.]

#req("C-ENT-5", "Entity Event, Entity Die, Entity Remove, Damage",
  why: [Kill feed, respawn and explosions are driven by these four.],
  test: [Die, explode a grenade, and take damage from a source with and without a killer.])[
  `Entity Event` (31): id, type (`0` Jump, `1` Reload Weapon, `2` Suicide, `3` Explode, `4` Fire, `5` Use Perk), param. `Entity Die` (32): id, death type, param (for a player `reason | respawn << 8`), and an *optional* damage info: check for the end of the packet before reading it. `Entity Remove` (33): remove at once. `Damage` (92): the victim, a type byte (low 7 bits, bit 7 means a source id follows), source, target, fire and hit positions and the amount, for the hit indicator; the authoritative health is the body's Health part. Explosions happen on `Explode`, not on a fuse.]

#req("C-ENT-6", "Player Update and Player Remove",
  why: [A player and its body are different things: a spectator has a player and no body.],
  test: [Join as a spectator and check the score board.])[
  Packet 50 items carry name, score, flags (bit 0 admin), team (`0`, `1`, `255` spectator), kills and deaths, ping, and your own perks. Packet 51 is a list of varint ids to remove. The client's own slot arriving among the spectators means it has no body and should start its free camera.]

== C.5 Your own player <index:c-own>

#req("C-OWN-1", "Join, then report your body at a steady rate",
  why: [Until `join` there is no player; until the first report there is no movement.],
  test: [Join and move; the server must log your entity.])[
  Send `Generic Command "join <team> <weapon> [<class>]"` (team `0`/`1`, `255` spectator; weapon `0` rifle, `1` SMG, `2` shotgun). The server replies `local-player <id>`: that id is your player and entity. Then send `Client Side Entity Update` (35) at about 30 Hz, unreliable on channel 1: your trajectory (position, velocity, euler angles) and your input when it changed, tool and block colour. Never send Create. Movement is client-authoritative but checked: the new position must be within about 0.1 block of the server's extrapolation along the old velocity, and the velocity within 0.1, or you receive a forced correction. A change of trajectory type is refused.]

#req("C-OWN-2", "Send the input before the action",
  why: [A hit or a build that arrives before the update showing you fired or holding the block tool is refused.],
  test: [Fire a burst and check no shot is refused for "not firing".])[
  Right before `Hit Entity`, `Hit Terrain`, `Build Block` or `Build Line`, send an update carrying the input or tool change, reliably on channel 0.]

#req("C-OWN-3", "Report hits, builds and throws",
  why: [The server decides damage and edits; it refuses what it cannot see in your own report.],
  test: [Shoot, dig, build and throw; check what the server accepts and what it refuses, and why.])[
  `Hit Entity` (90): entity, hit type (`0` unspecified, `1` torso, `2` head, `3` limb), damage type (`7` Weapon1 or `8` Weapon2: the slot fired from; `4` melee), your eye as fire position and the point hit. `Hit Terrain` (91): the cell, damage type (`5` dig, `4` melee, `7`..`9` a gun), positions. A gun sends one for every pellet that meets a block; the server keeps the block's health and the break happens at 100. `Build Block` (93) and `Build Line` (94): cell(s) and a colour in B, G, R (the server answers with a `Terrain Update`). `Throw Grenade` (95, 29 bytes): origin, velocity in blocks per second, fuse 0 to 3. Show your own grenade from the throw until `Explode`. A refused build is answered with a `Terrain Update` that restores the cell.]

#req("C-OWN-4", "Actions on your body: Player Action",
  why: [Jump, reload, respawn and perk placement are requests; the server answers with an `Entity Event`.],
  test: [Press jump during a zombie leap and a reload.])[
  `Player Action` (60): event type (`0` Jump, `1` Reload Weapon, `2` Suicide, `5` Use Perk) and a varint param. Wait for the `Entity Event` before treating a reload as done.]

#req("C-OWN-5", "Chat",
  why: [Channel 2 is the server's: a client that could send it would forge notices.],
  test: [Send 255 bytes and 256 bytes of chat.])[
  `Chat Message` (70): `Uint8` channel (`0` all, `1` team), `String` UTF-8 up to 255 bytes. `Chat Broadcast` (71): `Varint` sender (`0xFFFFFFFF` = the server), channel (`0`, `1`, `2` system), text. There is no CP437 in 1.0.]

== C.6 Commands and game modes <index:c-modes>

#req("C-GEN-1", "Generic Commands: send the ones you use, ignore the rest",
  why: [New markers and notices are added without a new packet id.],
  test: [Send an unknown command from a test server; the client must keep running.])[
  Packet 9 is a list of strings; `parts[0]` is the command. A client sends `join`, `leave`, `map-cached`, `team <n>`, `weapon <n>`, `class <n>`, `ping <info|danger> x y z [n]`, `ping spot <target> x y z`, `squad <n>`, `squad-rally`, `light <0|1>`, `device <platform> <input>` and `host ...` (permission checked). The server's commands (`hit`, `kill`, `perk-*`, `sky`, `fog`, `outfit`, `squad`, `light`, `device`, `match-*`, `classes`, `wallet` and others, listed in the protocol page) are optional: ignore the ones you do not use. See #l10("generic-command")[Generic Command].]

#req("C-MODE-1", "Game Mode State: snapshot or delta",
  why: [A snapshot forgets everything; applying one as a delta keeps a dead mode's state.],
  test: [End a round and compare the scores before and after the snapshot.])[
  Packet 80: a `Map` of strings. A packet whose *first* entry is `mode` is a snapshot: forget all mode state, then apply. Any other packet is a delta: each key replaces its value and an empty value removes it. A snapshot follows `Game State Final` and starts every round. Numbers are decimal, lists comma-separated, positions block cells. A mode you do not know: show the scores and nothing else.]

#req("C-MODE-2", "Objectives are entities",
  why: [A client that waits for a key to move the intel never sees it move.],
  test: [Capture an intel and watch the carrier, the base and the scores.])[
  Intels are `Flag`, tents `Command Post`, a hill or a territory a `Checkpoint`, with fixed ids from `0x7FFF0000`: `+0` team 1's intel, `+1` team 2's, `+2` and `+3` the tents, `+4` the hill, `+5 + i` territory `i`. A carried intel has its trajectory's parent set to the carrier. The server sends the objective's `Entity Update` *before* the `Game Mode State` that goes with it. Extrapolate a territory as `permille + rate * elapsed`, clamped to 0..1000.]

== C.7 Browsers: WebRTC <index:c-webrtc>

#req("C-WRT-1", "Two DataChannels, created before the offer",
  why: [The server closes a channel with another label, and a channel opened later is not in the offer.],
  test: [Open a third channel; it must be closed by the server.])[
  Create `reliable` (defaults, channel 0) and `unreliable` (`ordered: false, maxRetransmits: 0`, channel 1) before `createOffer`. A *text* message is control; a *binary* message is exactly one 1.0 packet, at most 16 KB. See #l10("webrtc-browsers")[WebRTC].]

#req("C-WRT-2", "Signal through the master, without trickle ICE",
  why: [The master relays one offer and one answer; a candidate that arrives later is lost.],
  test: [Join a server whose UDP port is closed.])[
  Wait for `iceGatheringState == "complete"`, then `POST /v1/servers/{id}/offer` (or `/v1/join/{code}/offer`) with `{"sdp": ...}` and set the returned answer. Do not post more than 10 offers a minute. See #lmaster("our-master-post-v1serversidoffer")[the offer].]

#req("C-WRT-3", "Send connect before Initiate Connection",
  why: [The handshake times out otherwise.],
  test: [Delay the text message and watch the server's `not initiated` timeout.])[
  When both channels are open, send the text `connect 135272729` on `reliable`, and only then the `Initiate Connection`. The server ends a connection with the text `disconnect <reason>`. A binary message before `connect` is dropped.]
