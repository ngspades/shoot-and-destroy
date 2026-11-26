#import "../template.typ": *

= F. Reference tables <index:f-ref>

== F.1 Team, weapon and tool numbers <index:f-enums>

#table(columns: (auto, 1fr, 1fr),
  table.header([Value], [0.75 / 0.76 wire], [1.0 wire]),
  [Team], [`0` team 1, `1` team 2, `-1` (255) spectator; in territory and object packets any other value is neutral], [`0`, `1`, `255` spectator],
  [Weapon], [`0` rifle, `1` SMG, `2` shotgun (anything else: rifle)], [the same in `join`; the guns and their parameters come from `Create` and weapon parameters],
  [Tool], [`0` spade, `1` block, `2` gun, `3` grenade (anything else: spade)], [slots: `0` melee, `1` block, `2` weapon 1, `3` weapon 2, `4` weapon 3],
)

== F.2 The CP437 table <index:f-cp437>

Bytes `0x20` to `0x7E` are ASCII, `0x7F` is a house (U+2302) and `0xFF` is a no-break space. Bytes `0x01` to `0x08` in chat are colour codes (A-TEXT-3), not glyphs. Bytes `0x80` to `0xFF` map to Unicode as below (row = high nibble, column = low nibble).

#let cp437 = (
  "ÇüéâäàåçêëèïîìÄÅ",
  "ÉæÆôöòûùÿÖÜ¢£¥₧ƒ",
  "áíóúñÑªº¿⌐¬½¼¡«»",
  "░▒▓│┤╡╢╖╕╣║╗╝╜╛┐",
  "└┴┬├─┼╞╟╚╔╩╦╠═╬╧",
  "╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀",
  "αßΓπΣσµτΦΘΩδ∞φε∩",
  "≡±≥≤⌠⌡÷≈°∙·√ⁿ²■\u{a0}",
)

#table(columns: 17, align: center,
  table.header([], ..range(16).map(i => raw(upper(str(i, base: 16))))),
  ..cp437.enumerate().map(((r, row)) => (raw(upper(str(r + 8, base: 16)) + "x"), ..row.clusters().map(c => c))).flatten(),
)

== F.3 The block palette <index:f-palette>

Eight rows of eight, in the classic order (grey ramp, then red, orange, yellow, green, cyan, blue and magenta, dark to light). Colours are R, G, B here; the wire sends B, G, R.

#let palette = (
  ("0f0f0f", "2f2f2f", "4f4f4f", "6f6f6f", "8f8f8f", "afafaf", "cfcfcf", "efefef"),
  ("1f0000", "5f0000", "9f0000", "df0000", "ff1f1f", "ff5f5f", "ff9f9f", "ffdfdf"),
  ("1f0f00", "5f2f00", "9f4f00", "df6f00", "ff8f1f", "ffaf5f", "ffcf9f", "ffefdf"),
  ("1f1f00", "5f5f00", "9f9f00", "dfdf00", "ffff1f", "ffff5f", "ffff9f", "ffffdf"),
  ("001f00", "005f00", "009f00", "00df00", "1fff1f", "5fff5f", "9fff9f", "dfffdf"),
  ("001f1f", "005f5f", "009f9f", "00dfdf", "1fffff", "5fffff", "9fffff", "dfffff"),
  ("00001f", "00005f", "00009f", "0000df", "1f1fff", "5f5fff", "9f9fff", "dfdfff"),
  ("1f001f", "5f005f", "9f009f", "df00df", "ff1fff", "ff5fff", "ff9fff", "ffdfff"),
)

#table(columns: 8,
  ..palette.flatten().map(h => [#swatch(h) #raw(h)]),
)

== F.4 Disconnect codes at a glance <index:f-disc>

The 0.75 table is in A-DISC-1 and the 1.0 table in C-NET-5. The same field means different things on each, so decide by the protocol the connection was opened with. The one ambiguous case: connecting to a vanilla server with the 1.0 magic gives `3` and no `Kick`. ngspades-client names the reasons it knows (banned, connection limit, wrong protocol, server full, shutting down, kicked, invalid name) and shows every other number as unknown.

= G. Testing your client <index:g-testing>

*Against ngspades-server.* The server is public (#link("https://github.com/ngspades/server")[ngspades/server]). Build it with `make server` and start it from the `server` folder: `build/ngspades-server` speaks protocol 1.0, `build/ngspades-server --profile 075` speaks 0.75/0.76 with the extensions of section B. Both can run at once on one machine. Set `SP_MASTER=0` so a test server never announces itself on the public list. `make probe-proto10` runs the server's own 1.0 handshake probe (VXL and ngmap, and the error paths: wrong protocol, idle, garbage, early packet).

*Against the protocol repository's examples.* #link("https://github.com/ngspades/protocol/tree/main/examples")[`examples/c`] has a dependency-free 1.0 codec with golden vectors (`make test`), a real ENet client for both protocols and a master list reader; `examples/godot` has the same in GDScript plus a WebRTC client. Use them as a second opinion: when your client and the example disagree on a packet, one of them has a bug.

*A conformance session.* (1) Join a 0.75 server, a 0.76 server and a 1.0 server and walk the order of A-JOIN-1, C-HS-1. (2) Join the same server twice and check no map bytes on the second join (A-076-3, C-MAP-2). (3) Fuzz every inbound id (A-IN-1, C-NET-4). (4) Kick yourself and read the reason (A-DISC-1, C-NET-5). (5) Dig under a bridge and repaint a block under a pillar (A-RULE-2, A-RULE-3). (6) Chat with accents on a CP437 server and on a UTF-8 one (A-TEXT-1, A-TEXT-2). (7) Run the master requests of section D with a bad network and with a non-JSON answer.

= H. Conformance matrix of ngspades-client <index:h-matrix>

Status of ngspades-client against every requirement above, as of the date of the build. *Supported* means the behaviour is implemented and has been played; *partial* means a common case works and a documented corner does not; *in progress* means a known gap that is being worked on; *not* means not implemented. Rows describe behaviour that a server or a player can observe.

#matrix-table()

= I. Credits and sources <index:i-credits>

Written from the public protocol pages (#link(proto-url)[protocol documentation]), the public #link("https://github.com/ngspades/server")[server repository] and its implementer guides, and the #link("https://github.com/zerospades/aosprotocol")[aosprotocol specification]. The idea of a numbered checklist of client requirements, and several of its good rules (a forewarning about references, "do not write your own UTF-8 decoder", DDA ray casting, batching block edits), come from #link("https://notaburner.mooo.com/assets/clidoc_draft.html")[the AoS 0.75.015 Canon Client Doc] by "not a burner"; the text here is our own. Text: CC BY 4.0.
