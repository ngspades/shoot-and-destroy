#import "../template.typ": *

= B. The community's 0.75 extensions <index:b-ext>

Servers and clients agree on optional packets through `Ext Info`, as the #link("https://github.com/zerospades/aosprotocol")[aosprotocol specification] describes. The #lext("registry")[registry] and what our server sends is on the protocol site; the byte layouts of the larger extensions (Damage Markers, Teamplay pings, Pie Menu) are in the specification, which is the source of truth for them.

== B.1 Negotiation <index:b-negotiation>

#req("B-EXT-1", "Answer Ext Info with the intersection, never more",
  why: [Naming an extension you do not implement makes the server send packets you cannot parse; naming one it did not offer is ignored at best.],
  test: [Offer an extension your client lacks (for instance `0x31`) and check it is not in the reply.])[
  The server sends `Ext Info` (packet id 60, `0x3C`) after the join. The client MUST store the offered list, and MUST reply with an `Ext Info` containing only extensions that are both offered and implemented. An extension's packets are sent only to clients that agreed. See #lext("ext-info")[Ext Info] and #lext("protocol-flow")[Protocol Flow].]

#req("B-EXT-2", "Layout: count, then (id, version) pairs",
  why: [The specification words the count differently from what real servers write, and a reader that is off by one drops the last extension or reads a byte of the next packet.],
  test: [Parse a packet with 3 entries from our server and from a ZeroSpades-based one.])[
  `Ext Info` is `[60, count, (id, version) x count]`, size `2 + 2n`. Our server writes, and our client reads, `count` as the *number of entries*. The aosprotocol page words it as "length, then `length + 1` entries". A client reading an unknown server SHOULD treat the field as a count and, only when the first entry is not a known id while `count - 1` entries parse cleanly to the end of the packet, fall back to the other wording. Use version 1 for every extension unless a server says otherwise.]

#req("B-EXT-3", "Extension packets: id 64 + extension id, then a sub-packet byte",
  why: [Packets 64 to 127 share one id space; forgetting the sub id desynchronises every extension.],
  test: [Send each extension's sub-packets and check no other packet changes meaning.])[
  An extension with packets (extension ids `0` to `191`) uses legacy packet id `64 + extension id` and one extra byte after the id, the sub packet id, even when it has only one packet. Extensions `192` to `255` are packetless: they change how existing packets are written and are known by the agreement alone. Packet 64 is Player Properties once agreed; without the agreement it is not an extension packet (some servers used it for their own status).]

#req("B-EXT-4", "Know the registry",
  why: [Ignoring an id is safe; mistaking one for another is not.],
  test: [Print the ids you answered with.])[
  The extensions our client answers (when offered):

  #table(columns: (auto, auto, auto, 1fr),
    table.header([Id], [Name], [Packet], [Requirements]),
    [`0x00`], [Player Properties], [64], [B-PROP-1],
    [`0x20`], [Damage Markers], [96], [B-DMG-1],
    [`0x30`], [Teamplay], [112], [B-TEAM-1, B-TEAM-2],
    [`0x31`], [Pie Menu], [113], [B-PIE-1],
    [`0x32`], [Flashlight], [114], [B-LIGHT-1, B-LIGHT-2],
    [`0x33`], [Daytime and Weather], [115], [B-SKY-1],
    [`0x35`], [Player Outfit (a draft)], [117], [B-OUTFIT-1],
    [`0xC0`], [Player Limit], [none], [B-LIMIT-1],
    [`0xC1`], [Message Types], [none], [B-MSG-1],
    [`0xC2`], [Kick Reason], [none], [B-KICK-1],
  )]

== B.2 Extensions with packets <index:b-packets>

#req("B-PROP-1", "Player Properties (0x00)",
  why: [The ammo of other players decides whether you draw their shots.],
  test: [Fire from a second client; the first must keep drawing the shots after its count would reach 0.])[
  Packet 64, sub 0, 12 bytes: player id, health, blocks, grenades (each 0 for an enemy), magazine, reserve, score (`Uint32`, kills plus score). Sent on change, at most every 100 ms per player. Keep ammo and score of everyone; keep health, blocks and grenades of your own player only. See #lext("player-properties")[Player Properties].]

#req("B-DMG-1", "Damage Markers (0x20)",
  why: [Without it a client shows no hit confirmation on servers that rely on it.],
  test: [Hit a bot and watch for the marker and the number.])[
  Packet 96. The attacker is told the victim and the amount; the client draws a hit marker and a number rising over the victim. Draw it only for markers the server sent: it is the only hit feedback a 0.75 server gives. Layout: aosprotocol.]

#req("B-TEAM-1", "Teamplay Config (0x30, sub 0)",
  why: [Config is the server's permission slip; drawing a compass or teammates through walls the server did not allow is a wallhack.],
  test: [Join with Config flags 0 and with all three bits.])[
  Packet 112, sub 0: flags (bit 0 teammate ESP, bit 1 pings, bit 2 compass), north X and Y floats (zero or NaN means the map's top). A client MUST NOT turn on a compass, ESP names or pings the Config did not allow. See #lext("teamplay")[Teamplay].]

#req("B-TEAM-2", "Teamplay pings and ESP marks",
  why: [They are the quick-chat of the team.],
  test: [Send a ping with a label and a life from a probe, and an ESP mark of a dead player.])[
  Sub 1 Ping (both directions): position, life in seconds (`0` removes, infinite until removed), colour, label and the surfaces to draw on (world, map, compass). Sub 2 ESP Mark (server to client): a target, life, whether to show the name, colour and label; it survives a death and may end at the respawn. The server's own pings come from player id 255. A client sends a ping only when Config allows it. Drop pings that arrive while the map loads.]

#req("B-PIE-1", "Pie Menu (0x31)",
  why: [Parsing a half-valid menu leaves rings the player cannot use.],
  test: [Send a menu with a short string and a trailing byte; both must be refused whole.])[
  Packet 113: the server defines quick-chat rings (menu id, the contexts it applies to: block, teammate, enemy, sky, spectator, dead; six slices each with text). Parse a menu whole or refuse it whole. It replaces the client's own rings from the next opening, and a menu without pies leaves no ring. A slice sends its text as chat, to the team or to everyone, with the specification's placeholders expanded from the aim taken when the ring opened.]

#req("B-LIGHT-1", "Flashlight (0x32): ask, and draw only what the server switched on",
  why: [A light the server never accepted is a light nobody else sees; a client that lights itself on its own cheats nobody but disagrees with everyone.],
  test: [Toggle your light with and without the extension agreed.])[
  Packet 114. Sub 0 Light (both ways: sub, player id, on), sub 1 Light State (server to client: one bit per player id, low bit first), sub 2 Light Config (server to client: player id (255 = everyone without one), reach, cone in degrees, red, green, blue, flicker). Send a request only after agreeing. The server relays the accepted request to every agreed client, the owner included; draw the beam only when it did. See #lext("flashlight")[Flashlight].]

#req("B-LIGHT-2", "A light goes off silently",
  why: [No packet announces it; a client that keeps lights on after a respawn shows ghost beams.],
  test: [Die with the light on and respawn.])[
  Clear a player's light on `Create Player`, `Kill Action`, `Player Left` and on a new map, with no packet from the server.]

#req("B-SKY-1", "Daytime and Weather (0x33)",
  why: [A client that agreed and ignores the packet draws a day the server meant as night.],
  test: [Send Time 0 and Time 720; check fog, sky and light.])[
  Packet 115, sub 0: `Uint16` time (0 night, 720 noon, other values are the day) and four reserved bytes (the draft's weather; version 1 has a day and a night). Sent after the agreement and after every map. A client that agreed and has received no sky yet SHOULD draw the night (black fog and sky) with flashlights as the only light. A new server starts by day. See #lext("daytime-and-weather")[Daytime and Weather].]

#req("B-OUTFIT-1", "Player Outfit (0x35, a draft)",
  why: [It decides whether a team looks like soldiers or zombies.],
  test: [Send Set Outfit 64 for a player, then leave and rejoin.])[
  Packet 117. Sub 0 Set Outfit (player, outfit, colour: 0 team 1, 1 team 2, 255 its own); sub 1 Team Outfits (team, outfit pairs). Outfits: 0 soldier, 7 miner, 64 zombie, 255 the team's. Draw any other value as a soldier. Cosmetic only: it never changes rules. Reset a player's outfit when it leaves and at every map.]

== B.3 Packetless extensions <index:b-packetless>

#req("B-LIMIT-1", "Player Limit (0xC0)",
  why: [It sizes the World Update.],
  test: [Join a server that offers it with 64 slots.])[
  Announced through `Ext Info` only: the number of players the server accepts. Size per-slot state for 256 anyway.]

#req("B-MSG-1", "Message Types (0xC1): chat types 3 to 6",
  why: [Without the agreement the server sends type 2 instead.],
  test: [Send types 3, 4, 5 and 6 from a probe.])[
  After agreeing, `Chat Message` may have type 3 (big), 4 (info), 5 (warning) or 6 (error). Show them as popups of increasing urgency.]

#req("B-KICK-1", "Kick Reason (0xC2)",
  why: [The only reason a player ever sees for a kick is this line.],
  test: [Kick yourself from the server console.])[
  A system `Chat Message` from player 255 sent just before a disconnect is the kick text; keep it and show it as the reason. (A server lets it leave the queue before disconnecting.)]

== B.4 Extra packets and UTF-8 chat <index:b-extra>

#req("B-VER-1", "Extended Version Get and Version Send",
  why: [This is how a server learns your language and whether you read UTF-8.],
  test: [Send `Version Get` with property ids 0, 1, 2 and 9 and read the answers.])[
  A `Version Get` (33) with bytes after the id asks for the extended answer: reply with `Existing Player` (9) whose *first byte after the id is `'x'` (0x78)*, which no player id can be, then for each requested property, in ascending order, `id, length, payload`, one packet per property, each repeating the ones before. Properties: `0` application (for example `BetterSpades 0.1.5`), `1` language (`en_us`, `pt_br`), `2` feature flags (bit 0: reads UTF-8 chat). An unknown id gets an empty payload. See #lext("extended-version-get")[Extended Version Get].]

#req("B-UTF8-1", "UTF-8 chat announcement",
  why: [A server only sends `0xFF` lines to clients that said they read them.],
  test: [Receive a `0xFF` line and send one back.])[
  Announce feature bit 0 in the extended version answer and read `0xFF` + UTF-8 lines (A-TEXT-1). A client MAY consider a server as reading UTF-8 once it has sent a `0xFF` line itself.]
