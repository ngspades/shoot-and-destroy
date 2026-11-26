#import "../template.typ": *

= A. Protocol 0.75 and 0.76 <index:a-075>

The classic wire, spoken by every public Ace of Spades server. 0.76 changes three things, marked *[0.76]* below. The packets themselves are specified in the #l075("packets")[protocol 0.75 page], and this part says what a client has to do with them.

== A.1 Transport <index:a-transport>

#req("A-NET-1", "Connect with ENet 1.3, one channel, range coder",
  why: [Servers compress every packet with ENet's range coder; a host without it cannot read a single one.],
  test: [Connect to a 0.75 server and log the first `Map Start` (id 18).])[
  A client MUST create an ENet 1.3 host with exactly one channel and enable the range coder (`enet_host_compress_with_range_coder`) before connecting. The default port is `32887`. See #l075("connection")[Connection].]

#req("A-NET-2", "Pick the protocol with the connect data",
  why: [A wrong value is answered with disconnect reason 3 and nothing else.],
  test: [Against a 0.76 server, connect data 3 must be refused with reason 3 or 11 and your client must retry with 4.])[
  The ENet connect data MUST be `3` for 0.75 and `4` for 0.76. A client that speaks both SHOULD try one, and on reason 3 (or 11) try the other.]

#req("A-NET-3", "One game packet per ENet packet, one id byte first",
  why: [There is no length field; the ENet packet length is the framing.],
  test: [Feed a truncated packet of every id to the decoder; none may read past the end.])[
  Every received ENet packet MUST be handled as exactly one game packet: byte 0 is the id, the rest is the payload. Before reading a field the client MUST check that the packet is long enough, and MUST ignore an id it does not know.]

#req("A-NET-4", "Everything reliable except World Update",
  why: [A lost reliable packet is resent; `World Update` is superseded by the next one, so resending it only adds delay.],
  test: [Capture your own traffic and confirm only id 2 is unreliable on the server's side.])[
  A client MUST send every packet reliably on channel 0. It MUST accept `World Update` (id 2) as unreliable and every other id as reliable.]

#req("A-NET-5", "Handle Map Start at any time",
  why: [Servers change map mid-match; a client that only expects a map once stays on the old one.],
  test: [Run a server with a two-map rotation and end a round while connected.])[
  A client MUST be ready to receive `Map Start` (18) at any moment after the join, drop the current world and start the download again.]

#req("A-ADDR-1", "Parse aos:// addresses as a little-endian integer",
  why: [`aos://16777343` is `127.0.0.1`; reading the number big-endian gives `1.0.0.127`.],
  test: [Parse `aos://16777343:32887` and `aos://16777343` (default port).])[
  `aos://ADDRESS[:PORT][SUFFIX]`: ADDRESS is the IPv4 address as one decimal number whose low byte is the first octet. PORT defaults to `32887`. A suffix such as `:0.75` or `/0.76` names a version; an unknown suffix means 0.75. A client SHOULD also accept a dotted address and a bare `host:port`. See #l075("about-addresses")[About Addresses].]

#req("A-DISC-1", "Know the 0.75 disconnect reasons and show unknown ones as unknown",
  why: [Reason 0 is also what ENet reports for a timeout, and some servers send values outside the table; indexing a message table with the raw value crashes.],
  test: [Make your server disconnect with 77 and with 0xFFFFFFFF.])[
  The table below is the union of the public protocol page and the community's usage. A client MUST show a value it does not know as "unknown" and MUST NOT use it as an array index. A system `Chat Message` from player 255 sent just before the disconnect is the kick text and SHOULD be shown instead of the generic reason.

  #table(columns: (auto, auto, 1fr),
    table.header([Value], [Meaning], [Note]),
    [0], [timeout / unspecified], [ENet uses 0 for a timeout too],
    [1], [banned], [],
    [2], [kicked], [some servers use it for "too many connections from your address"],
    [3], [wrong protocol version], [connect data was not 3 or 4],
    [4], [server full], [],
    [5], [server shutting down], [],
    [8, 9, 10, 11], [banned, full, kicked, wrong version], [the same, sent after the map download; Voxlap only knows 0..4 before it],
    [20], [invalid name], [],
    [61], [server shutting down], [alternative value],
  )]

== A.2 Data conventions <index:a-data>

#req("A-TYPE-1", "Little-endian, packed, no padding",
  why: [Reading a struct straight from memory works until a compiler pads it or a big-endian host reads it.],
  test: [Round-trip every packet of the protocol page through your codec and compare bytes.])[
  Every integer and float on the wire is little-endian, signed integers are two's complement, floats are IEEE-754 binary32, and structures have no padding. Write a codec that reads and writes field by field. See #l075("data-types")[Data Types].]

#req("A-TYPE-2", "Colours are B, G, R",
  why: [Swapped channels turn a red team blue and every block purple; the error is invisible in code review.],
  test: [Place a pure red block (`255,0,0`) and read it back from the server.])[
  A colour on the 0.75 wire is three bytes in the order blue, green, red. (Protocol 1.0's `Terrain Update` is the one place that uses R, G, B: see C-MAP-6.)]

#req("A-COORD-1", "Axes: x east, y south, z down",
  why: [Every coordinate bug in this game is a mirrored z.],
  test: [Spawn, look straight up and check that `oz` is negative.])[
  The map is `512 x 512 x 64`. `z` grows downwards: 0 is the top of the world, 63 is the bottom (water) layer. An engine with `y` up SHOULD convert only at the protocol boundary: `engine = (x, 63 - z, y)` and back `(x, z, 63 - y)` for positions. A look vector's `oz` is negative when looking up. See #l075("about-coordinates")[About Coordinates].]

#req("A-COORD-2", "Voxel from float: floor each axis; positions are the eye",
  why: [Rounding instead of flooring shifts every hit and every block by one half cell; and the player's position is the camera, not the feet.],
  test: [Stand on the centre of a block and compare the voxel you compute with the server's.])[
  A float position `(0,0,0)` is the corner of voxel `(0,0,0)` and `(0.5,0.5,0.5)` its centre. To get the voxel, floor each axis. A player's position is its eye. Models (players, tents, intels) are not wrapped; tents and intels sit on top of their `z`.]

#req("A-COORD-3", "Wrap the terrain for drawing, not for rules",
  why: [Players, block edits and block physics do not wrap; grenades do. Treating them alike lets a block be built on the far side of the map.],
  test: [Throw a grenade across x = 0 and place a block at x = -1 (the latter must be ignored).])[
  Terrain outside `0..511` on `x` and `y` is drawn as a copy of the map (toroidal). Block placement, block destruction, block gravity and player movement MUST NOT wrap. Grenade physics MUST wrap. Cells with `z >= 62` cannot be dug.]

#req("A-TEXT-1", "Decode text as UTF-8 only after 0xFF, otherwise CP437",
  why: [Classic servers send CP437 bytes; newer ones send `0xFF` followed by UTF-8. Treating CP437 as UTF-8 or the reverse corrupts every accent.],
  test: [Send `0xFF` + `é` in UTF-8 and the single byte `0x82`: both must show `é`.])[
  A string that begins with byte `0xFF` and is valid UTF-8 afterwards is UTF-8 (drop the `0xFF`). Anything else is CP437 (table in section F.2). *Do not write your own UTF-8 decoder*: use the platform's, or a well-tested state machine, because a hand-rolled one tends to accept invalid sequences. NUL ends a string. See #l075("about-text")[About Text].]

#req("A-TEXT-2", "Send CP437 when everything fits, 0xFF + UTF-8 only to a server that reads it",
  why: [A server that has never heard of UTF-8 shows the bytes as garbage.],
  test: [Send `ação` to a classic server (CP437) and to one that asked for feature flags (UTF-8).])[
  When sending, a client MUST use CP437 if every character has an exact CP437 representation. Otherwise it MAY send `0xFF` + UTF-8, but only to a server known to read it: the server asked for the feature flags in an extended `Version Get`, or it sent a `0xFF` line itself (B-UTF8-1).]

#req("A-TEXT-3", "Colour control bytes in chat",
  why: [Real servers put these bytes in names and lines; a client that prints them verbatim shows boxes, one that mishandles them can recolour the whole screen.],
  test: [Feed lines with each of `0x01`..`0x08` and with `\r` and `\n`.])[
  Inside chat text and names these bytes change the colour of what follows: `0x01` team 1, `0x02` team 2, `0x03` spectators, `0x04` red, `0x05` green, `0x06` normal (white), `0x07` grey, `0x08` yellow. `\n` and `\r` break the line. Other bytes below `0x20` SHOULD be drawn as a replacement character. A colour byte MUST NOT change what you store as the player's name.]

== A.3 Joining <index:a-join>

#req("A-JOIN-1", "Follow the join order",
  why: [`State Data` ends the download. Loading the map earlier, or opening the team menu before it, makes the player join a map that is not there yet.],
  test: [Log the packet ids of a join against a reference server and compare the order.])[
  ```
  client                                   server
    ENet connect (3 or 4) ---------------->
              <----------------------- Map Start (18)  [0.76: size + CRC32 + name]
              <----------------------- Map Chunk (19) x N
              <----------------------- Version Get (33), Handshake Init (31)   (optional)
    Version Send (34), Handshake Return (32) ->
              <----------------------- Existing Player (9) x players already in
              <----------------------- State Data (15)       (download done)
    Existing Player (9): team, weapon, name ->               (team/weapon menu)
              <----------------------- Create Player (12)   (you spawn)
              <----------------------- World Update (2) ...  (the match)
  ```
  The client MUST append `Map Chunk` payloads until the byte count in `Map Start` is reached, inflate the zlib stream, load the VXL map only on `State Data`, then show the team menu. Chunks may be any size.]

#req("A-JOIN-2", "Join with Existing Player; accept Short Player Data on the server's side only",
  why: [Joining with the wrong id or an invalid team is silently ignored, so the screen just stays on the menu.],
  test: [Join as spectator (team 255) and as each team and weapon.])[
  To join, send `Existing Player` (9) with your player id from `State Data`, team (`0`, `1`, or `255` spectator), weapon (`0` rifle, `1` SMG, `2` shotgun), tool = gun, zero kills, block colour and name. The server answers with `Create Player` (12). `Short Player Data` (10) is the older form; servers accept both. Changing team or weapon later uses `Change Team` (29) and `Change Weapon` (30); a team change is a death (kill kind 5).]

#req("A-JOIN-3", "Existing Player has no position",
  why: [Placing the player at the packet's (absent) position puts everyone at the origin until the next update.],
  test: [Join a server with bots and check nobody is drawn at the map corner.])[
  `Existing Player` from the server carries no position. A client MUST keep that player hidden until a `World Update` or `Create Player` places them.]

#req("A-JOIN-4", "Create Player: reset and restock",
  why: [Stale ammo or colour from the last life carries over otherwise.],
  test: [Die, respawn, and compare health, blocks, grenades and ammo with the server's values.])[
  On `Create Player` (12) the player is alive unless the team is spectator, faces east for team 1 and west for team 2, has its block colour reset to `(111,111,111)` and is restocked: full health, 50 blocks, 3 grenades, full magazine and reserve. The packet is `15 + name` bytes, or 16 with an empty name; an empty one MUST keep the name already known. Use the position as given (the original Voxlap client subtracts 2 from `z`; modern clients do not).]

#req("A-JOIN-5", "Answer Version Get, Handshake Init and Ext Info; never require them",
  why: [Some servers fingerprint clients and kick those that stay silent; a client that blocks on them hangs on servers that never ask.],
  test: [Join a server that sends `Handshake Init` (31) and one that does not.])[
  A client SHOULD answer `Handshake Init` with `Handshake Return` (32, the same four bytes) and `Version Get` (33) with `Version Send` (34: client letter, three version bytes, 64-byte OS string). The extended forms are in section B. Nothing in the join may wait for them.]

== A.4 Packets the server sends <index:a-inbound>

#req("A-IN-1", "Dispatch every inbound id and validate before use",
  why: [A packet that is shorter than its layout, or names a player or team that does not exist, is how a hostile server crashes a client.],
  test: [Fuzz each id with lengths 0..size+8 and random bytes; run under a sanitizer.])[
  For each id the client MUST: check the length, check any `player_id` is `0..255` and in use where that matters, and map out-of-range enums to the safe default (team: spectator; weapon: rifle; tool: spade; territory team: neutral). The inbound ids are 0 Position, 1 Orientation, 2 World Update, 3 Input, 4 Weapon Input, 5 Set HP, 6 Grenade, 7 Set Tool, 8 Set Color, 9 Existing Player, 11 Move Object, 12 Create Player, 13 Block Action, 14 Block Line, 15 State Data, 16 Kill Action, 17 Chat, 18 Map Start, 19 Map Chunk, 20 Player Left, 21 Territory Capture, 22 Progress Bar, 23 Intel Capture, 24 Intel Pickup, 25 Intel Drop, 26 Restock, 27 Fog Color, 28 Weapon Reload, 31 Handshake Init, 33 Version Get, 60 Ext Info, 64 to 127 extension packets.]

#req("A-IN-2", "Position Data and Orientation Data are corrections to you",
  why: [They carry no player id. Applying a position to the wrong slot, or interpolating a teleport, shows up as rubber-banding.],
  test: [Teleport yourself with an admin command; the view must jump, not slide.])[
  `Position Data` (0, 13 bytes) sets the receiver's eye position, zeroes its velocity and keeps its look. `Orientation Data` (1, 13 bytes) sets the receiver's look vector. Neither may be interpolated, and neither writes into a different field than its own.]

#req("A-IN-3", "World Update: skip yourself, keep the last position on zeros",
  why: [Servers send zeros for dead players, players beyond the fog and free slots. Teleporting them to the corner looks like a bug.],
  test: [Stand with a bot just past the fog distance; it must not flash at (0,0,0).])[
  0.75 sends one `{position, orientation}` (24 bytes) per slot, indexed by player id; *[0.76]* sends `{id, position, orientation}` (25 bytes) for each present player. The packet is `1 + 24n` or `1 + 25n` bytes. A client MUST skip its own entry, MUST treat a zero position as "not visible, keep the last position", and SHOULD interpolate between updates (about 60 per second).]

#req("A-IN-4", "Input Data and Weapon Input describe other players",
  why: [They drive legs, tracers and swings of other players; applying them to yourself fights your own prediction.],
  test: [Watch a bot walk, sprint and fire from a second client.])[
  `Input Data` (3): `player_id` and key bits `1 forward, 2 back, 4 left, 8 right, 16 jump, 32 crouch, 64 sneak, 128 sprint`; for yourself only the jump bit matters. `Weapon Input` (4): bit 0 primary, bit 1 secondary; a server sends 0 while a player sprints, switches or reloads. Use it for tracers, swings and flashes of that player and ignore it for yourself.]

#req("A-IN-5", "Set HP, Kill Action, Restock",
  why: [The HP and the kill feed are the player's only feedback; a client that trusts its own damage prediction disagrees with the server at once.],
  test: [Shoot yourself with a second client and compare HP, kill feed and respawn counter.])[
  `Set HP` (5, 15 bytes): new health 0..100, type (0 fall, 1 other), source position; flash the screen on a drop. `Kill Action` (16, 5 bytes): victim, killer, kind (0 weapon, 1 headshot, 2 melee, 3 grenade, 4 fall, 5 team change, 6 weapon change), respawn seconds; the killer scores unless it is the victim. `Restock` (26): that player gets full health, 50 blocks, 3 grenades and full reserve; ignore it for yourself while dead.]

#req("A-IN-6", "Grenade: velocity is in blocks per 1/32 s",
  why: [Treating it as blocks per second makes grenades 32 times too slow.],
  test: [Throw one and compare your landing point with the server's explosion.])[
  `Grenade` (6, 30 bytes): thrower, fuse in seconds, position, velocity in blocks per 1/32 second (`blocks_per_second / 32`). Gravity is 32 blocks/s squared. The server does not send a grenade back to its thrower.]

#req("A-IN-7", "Set Tool and Set Color are kept for every player",
  why: [Later block packets use the colour of the player who sent them, even one that is not alive yet.],
  test: [Join a match where someone has picked a colour before you arrived.])[
  `Set Tool` (7): tool `0 spade, 1 block, 2 gun, 3 grenade`; ignore a value above 3. `Set Color` (8): B, G, R; keep it for players that are not alive or not joined yet.]

#req("A-IN-8", "State Data: 83 bytes for CTF, 32 + 13n for TC",
  why: [This is where the player id, fog, team names and mode come from; a wrong offset misnames both teams.],
  test: [Join one CTF and one TC server and print every decoded field.])[
  Fields: your player id, fog colour, both team colours, both team names (10 bytes each, NUL padded and possibly without a NUL), mode (`0` CTF, `1` TC; treat an unknown mode as TC). CTF adds scores, capture limit, an intel-state byte and, for each intel, 12 bytes (`{carrier, 11 padding}` when held, else a position), then both bases. TC adds the territory count and `{position, team}` per territory.]

#req("A-IN-9", "CTF and TC objects",
  why: [Intel and tents live on the map, not in the player list; a client that only reads `State Data` never sees them move.],
  test: [Capture an intel and check the tent, the intel and the scores.])[
  `Move Object` (11): CTF object `0/1` intels, `2/3` tents (moving an intel also drops it from its carrier, silently); TC territory index with its owner. `Intel Pickup` (24), `Intel Drop` (25, with the position), `Intel Capture` (23: `winning` 1 ends the round; 10 points to the player and 1 to the team). `Territory Capture` (21), `Progress Bar` (22: rate is per 50 s; advance `0.05 * rate` a second). A team value other than `0`, `1` in a territory or object packet MUST be treated as neutral.]

#req("A-IN-10", "Chat Message types",
  why: [Types 3 to 6 only arrive when the extension was agreed; showing them as normal chat or dropping them hides server notices.],
  test: [Send each type 0..6 from a probe.])[
  `Chat Message` (17, `3 + text` bytes): player id (255 = the server), type (0 all, 1 team, 2 system; 3 big, 4 info, 5 warning, 6 error with B-MSG-1), text. A client sends types 0 and 1 only.]

#req("A-IN-11", "Fog Color, Weapon Reload, Player Left",
  why: [Small packets, but each one is a place a stale value stays on screen.],
  test: [Reload with a second client and check the first one hears it.])[
  `Fog Color` (27): alpha (unused) and B, G, R. `Weapon Reload` (28, 4 bytes): for yourself it settles the ammo, for another player it plays the sound and refills your view of their clip (otherwise you stop drawing their shots when your count reaches 0). `Player Left` (20): clear the slot.]

== A.5 Packets the client sends <index:a-outbound>

#req("A-OUT-1", "Report position and orientation",
  why: [The server compares your position with its own simulation; a client that never reports is corrected into the ground.],
  test: [Walk for a minute and count corrections from the server.])[
  Send `Position Data` (0) about once a second while alive and right after a teleport. Send `Orientation Data` (1) when the look changed by more than about 0.5 degrees (up to about 120 times a second) and *immediately before each shot*, so the server validates the hit against the right direction.]

#req("A-OUT-2", "Report input and buttons when they change",
  why: [The server simulates you from these bits.],
  test: [Hold forward and sprint, release; the server's view of your keys must follow.])[
  Send `Input Data` (3) whenever the movement keys change and `Weapon Input` (4) whenever a button changes, except while sprinting. Send `Set Tool` (7) when the held tool changes and `Set Color` (8) when the colour does.]

#req("A-OUT-3", "Report only hits you saw",
  why: [The server decides damage, but checks distance, line of sight and fire rate; sending guesses gets the player flagged.],
  test: [Shoot at a wall and at a body; only the latter may produce a `Hit`.])[
  `Hit` (5, 3 bytes): victim and part (`0` torso, `1` head, `2` arms, `3` legs, `4` melee) for every hit your shot or spade made.]

#req("A-OUT-4", "Throw grenades with the fuse that is left",
  why: [Resetting the fuse to 3 s on every throw makes a held grenade explode late for everyone else.],
  test: [Hold a grenade for 2 s, throw it and check where it explodes.])[
  `Grenade` (6): fuse left (up to 3 s), the position it leaves the hand and velocity in blocks per 1/32 second.]

#req("A-OUT-5", "Reload and chat",
  why: [The server owns the ammo; your count is a prediction until it answers.],
  test: [Reload, switch tool mid-reload, and compare the ammo.])[
  Send `Weapon Reload` (28) when a reload starts and wait for the server's answer before adding ammo. Send chat (17) as `{player id, type 0 or 1, text}` in CP437 or `0xFF` + UTF-8 (A-TEXT-2).]

== A.6 Game rules the client must know <index:a-rules>

#req("A-RULE-1", "Block action semantics",
  why: [Actions 2 and 3 change more than one cell; counting only the named cell leaves holes.],
  test: [Spade a three-high column and grenade a wall; compare with the server's map.])[
  `Block Action` (13, 15 bytes: player, action, cell). Actions: `0` build one block in the player's colour (a repaint when the cell is already solid), `1` destroy one, `2` spade (the block and those above and below: 1 x 1 x 3), `3` grenade (3 x 3 x 3, silently), `4` destroy one (gun), `5` destroy one (spade). Actions 2 and 3 leave `z >= 62` alone, and cells outside the map are ignored. `Block Line` (14, 26 bytes: player, start, end) builds a 3D DDA line, skipping solid cells, and costs `|dx| + |dy| + |dz| + 1` blocks. A player carries at most 50 blocks; a build costs one, a spade destroy gives one back.]

#req("A-RULE-2", "Batch the edits that arrive together: creates first, then destroys",
  why: [Servers implement block painting as "destroy, then create the same cell"; applied one by one, the destroy briefly removes support and the block-gravity check drops a structure that never fell.],
  test: [Repaint the block under a pillar; the pillar must stay up.])[
  Edits that arrive in one batch (all events drained from one `enet_host_service` pass, or one datagram) MUST NOT touch the map one by one. Record each affected cell in a table keyed by position, last operation wins (`create` with its colour, or `destroy`). When the batch is complete, apply all creates, then all destroys, then run block gravity once. Sound and effects may play immediately.]

#req("A-RULE-3", "Block gravity",
  why: [This is what makes bridges fall; the server never sends the falling cells in 0.75.],
  test: [Cut the only support of a floating block; it must fall. Spade a column next to a free-standing block; it must not.])[
  When a voxel stops being solid, check its six face neighbours. Each solid neighbour starts a flood fill through solid voxels. If any fill reaches a voxel with `z >= 62`, nothing happens. Otherwise everything that fill reached is detached: it falls and is removed. A cell that was *already empty* inside a spade or grenade area MUST NOT start a check. Gravity does not wrap (A-COORD-3).]

#req("A-RULE-4", "Fog is a cylinder of radius 128",
  why: [Drawing players past the fog is a wallhack, and servers do send their positions.],
  test: [Check that a player 130 blocks away is not drawn although the server sent its position.])[
  Sight is a cylinder of radius 128 blocks around the camera (spectators too). Nothing beyond it is drawn, shots stop there, colours cannot be copied beyond it and the sky is the fog colour (`State Data`, `Fog Color`). 0.75 has no fog-distance field.]

#req("A-RULE-5", "Cast rays with a DDA",
  why: [Stepping along a ray in fixed increments skips thin walls and corners; every shot, colour pick and block target depends on it.],
  test: [Fire along an exact axis, along a diagonal and through a one-block corner; compare with a reference.])[
  Hit tests (shots, spade, colour copy, block selection) MUST walk the voxels a ray crosses one at a time, with the grid traversal usually called a DDA (Amanatides and Woo), up to the fog radius. Test it thoroughly: it is easy to get subtly wrong at exact integer coordinates and in negative directions. The wire rule is the one the server uses, so a client that disagrees reports hits that are refused.]

#req("A-RULE-6", "Sectors",
  why: [Territory captures and the minimap grid use these names.],
  test: [Convert the four map corners and the centre.])[
  A 512 x 512 map has 8 x 8 sectors of 64 x 64 columns. The sector name is a letter `A` to `H` from `floor(x / 64)` and a digit `1` to `8` from `floor(y / 64) + 1`. Servers may protect sectors from building and digging.]

#req("A-RULE-7", "The 64-colour block palette",
  why: [Players expect the classic palette and arrow-key navigation; copying a colour must select the matching square.],
  test: [Pick every square and send `Set Color`; copy a block's colour and check the cursor.])[
  The block tool shows an 8 x 8 palette (table in section F.3). Left and right wrap within the row and, in the classic client, also move to the previous or next row (x switches 0 to 7 and y decreases by one, modulo 8); up and down wrap within the column. When the held colour equals a palette colour, the cursor selects it. Picking sends `Set Color`.]

#req("A-RULE-8", "Colour copy",
  why: [The classic bind (E) is how players match terrain.],
  test: [Look at a block 100 blocks away, then at the sky.])[
  If the player faces a solid voxel within the fog radius, its colour becomes the held colour (and is sent with `Set Color`); if it faces none, use the fog colour. It SHOULD work even when a block is not in hand.]

#req("A-RULE-9", "Player physics is the server's; predict it, do not invent it",
  why: [The server compares your reported position with its own simulation. Different gravity, friction or step-up rules give a correction every few seconds.],
  test: [Run flat, jump, climb one-block steps, fall from 10 blocks and count position corrections.])[
  Movement is not on the wire. A client that predicts its own body MUST implement the reference game's player and grenade physics (the pyspades world code is the de facto source), including smooth one-block climbing, and MUST accept `Position Data` as a correction. Fall damage is the server's decision; the client plays the fall sound.]

== A.7 What 0.76 changes <index:a-076>

#req("A-076-1", "Connect data 4",
  why: [A 0.76 server refuses 3.],
  test: [Connect to a 0.76 server with each value.])[
  Use connect data `4` for a 0.76 server (A-NET-2).]

#req("A-076-2", "Map Start carries size, CRC32 and name",
  why: [Without the CRC32 a client cannot tell whether it already has the map.],
  test: [Join the same server twice; the second time no `Map Chunk` may arrive.])[
  *[0.76]* `Map Start` is 73 bytes: `Uint32` size, `Uint32` CRC32 of the compressed stream, then a 64-byte NUL-padded map name.]

#req("A-076-3", "Answer Map Cached; cache by CRC32",
  why: [A cached map saves megabytes; a wrong answer loads the wrong map.],
  test: [Corrupt a cache file and check that you still join.])[
  *[0.76]* Answer with `Map Cached` (31, client to server, 2 bytes: `1` = have it) when you hold a map with that CRC32 and `0` otherwise; on `1` the server sends no `Map Chunk`. The client SHOULD store a downloaded map only after the CRC32 of the received stream matches, and MUST NOT trust a cache file that fails its own check.]

#req("A-076-4", "World Update has player ids",
  why: [The 24-byte slot layout reads garbage from a 0.76 server.],
  test: [Join a 0.76 server with 8 players.])[
  *[0.76]* each `World Update` entry is `{Uint8 id, position, orientation}` (A-IN-3).]

== A.8 The classic server list <index:a-list>

#req("A-LIST-1", "Read serverlist.json defensively",
  why: [The classic lists are old, duplicate rows are common and fields are added over time.],
  test: [Feed a row with unknown keys, a duplicate and a non-JSON body.])[
  The list is a JSON array at `/serverlist.json`. Each row has at least `name`, `identifier` (`aos://...`), `map`, `game_mode`, `country` (ISO 3166-1 alpha-2), `latency` (ms, measured by the list), `players_current`, `players_max`, `last_updated` (Unix seconds) and `game_version` (`"0.75"`, `"0.76"` or another string). A client MUST ignore unknown keys, MUST NOT treat duplicates as an error, and MUST treat a body that is not a JSON array as "unreachable". Fetch over HTTPS when the host offers it.]
