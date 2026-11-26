#import "../template.typ": *

= D. Server lists and server queries <index:d-lists>

How a client finds servers: our master over HTTPS and the classic list (section A.8), and the raw UDP queries a server answers. Specified in #lmaster("our-master-http")[Master Server] and #lping("connection")[Ping].

#req("D-LIST-1", "Read our list: GET /v1/servers",
  why: [Rows of our master carry the classic keys plus the fields a 1.0 join needs; a parser that only knows the classic ones cannot join a 1.0 server.],
  test: [Fetch `https://master.shootanddestroy.obex.pw/v1/servers` and join a 1.0 row and a 0.75 row.])[
  The base URL is `https://master.shootanddestroy.obex.pw`; everything is HTTPS and JSON, with `Access-Control-Allow-Origin: *`. `GET /v1/servers` returns an array, most players first. Each row has `name`, `identifier` (IPv4 when present, else IPv6), `identifier6`, `map`, `game_mode`, `players_current`, `players_max` (bots count), `game_version` (`"1.0"` or `"0.75"`), `id`, `key`, `webrtc` (true when the server takes browsers), `dtls_fingerprint`, `info` (the `HELLOINFO` answer, may be absent), `ice_servers`, `country` and `last_seen`. `GET /v1/servers/{id}` is one row. Use a timeout (5 s) and one retry; a body that is not JSON means "unreachable". Fetch when the player opens the list and on Refresh; never poll faster than every 10 s; rows vanish within 90 s of a server stopping.]

#req("D-LIST-2", "Merge with the classic list, ours winning",
  why: [A server announced to both lists would otherwise appear twice, and the classic row cannot be joined over 1.0.],
  test: [Run a server that announces to both lists and count its rows.])[
  Merge both lists by address; a server found in both is listed once, as ours. If our master is unreachable, keep showing the classic servers and say so; a browser has only our list.]

#req("D-LIST-3", "The row decides the protocol",
  why: [Joining a 0.75 server with the 1.0 magic works only when the server refuses it.],
  test: [Join one row of each version.])[
  `game_version` `"1.0"` is `aos10://host:port` with connect data `0x08101919` (IPv6 hosts in brackets); `"0.75"` is `aos://` with connect data 3. A client on an IPv6-only machine uses `identifier6`, on a dual-stack machine `identifier`.]

#req("D-CODE-1", "Join codes",
  why: [A friend hosting at home has no open port; the code is how they are reached.],
  test: [Type `abc-def`, `ABC DEF` and `ABCDEF`; all must resolve the same.])[
  A listen server may announce a six-character code (`ABC-DEF`, never containing `I`, `L`, `O`, `Q`, `0` or `1`). `GET /v1/join/{code}` returns the server's row (404 `{"error": ...}` when nobody holds it) and `POST /v1/join/{code}/offer` is the WebRTC offer by code (C-WRT-2). Accept the code as pasted. Players see plain words ("Nobody is playing under that code"), never protocol terms.]

#req("D-PING-1", "Ping with HELLO, ask details with a padded HELLOINFO",
  why: [UDP proves no address: an unpadded query gets 0.5 answers a second and a forged source could use us as an amplifier.],
  test: [Send the bare 9-byte `HELLOINFO` ten times and the padded form ten times and compare the answers.])[
  Raw UDP to the game port, no ENet, no packet id. `HELLO` (5 bytes) is answered by `HI` (2 bytes). `HELLOINFO` MUST be padded to 1200 bytes (any bytes after the word): padded gets 5 answers a second (burst 10), bare 0.5 (burst 3). The answer is JSON with `kind: "info"`, `name`, `map`, `map_shape`, `map_preview`, `protocol`, counts, `teams`, `features`, `rotation` and up to 32 `players`. Only ask servers of ours: a third-party 0.75 server does not answer. Try three times, 1.5 s apart.]

#req("D-PING-2", "LAN discovery",
  why: [Local games need no master.],
  test: [Start a server on the LAN and list it with no internet.])[
  Send `HELLOLAN` (8 bytes) as a broadcast and to `127.0.0.1` on ports `32882` to `32897`. A server answers only local addresses with a JSON row (`name`, `players_current`, `players_max`, `map`, `map_shape`, `game_mode`, `game_version`).]

#req("D-PREV-1", "Map preview by chunks",
  why: [A small picture is worth a page of text, but a naive reader hangs on a slow link.],
  test: [Ask for a preview over a link with 150 ms of latency.])[
  When `info.map_preview` is not 0, ask `HELLOPREVIEW` + `Uint32` offset padded to 1200 bytes. Answers are `"SDPC"`, total, offset, the 64 hex digits of the shape and data, never larger than the query. Keep up to 8 chunks in flight, ask again every 0.5 s, give up after 3 s *without a chunk*. The stream is `"SDP1"`, width, height and zlib RGB rows (256 x 256). Verify the magic, the size and the inflate, and cache by `map_shape`. A browser cannot send UDP and has no preview.]
