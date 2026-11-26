#import "../template.typ": *

= E. Optional improvements of ngspades-client <index:e-optional>

Things ngspades-client does beyond the minimum, limited to what is visible on the wire or in a server's behaviour. None is needed to join a game.

#req("E-IPV6-1", "Dual-stack sockets",
  why: [A host or player with IPv6 only must still play.],
  test: [Join a server by an IPv6 literal on a machine with no IPv4 route.])[
  Use one IPv6 socket with `IPV6_V6ONLY` off, fall back to IPv4 where IPv6 is missing, and accept IPv4 peers as IPv4-mapped addresses (`::ffff:a.b.c.d`) that you unmap before showing or comparing. Choose `identifier` over `identifier6` while IPv4 is reachable (D-LIST-3). The LAN broadcast stays IPv4.]

#req("E-UTF8-1", "UTF-8 names and chat, both ways",
  why: [Names with accents or Cyrillic must survive the trip.],
  test: [Chat `ação` and `Привет` on 1.0 and on a 0.75 server that reads UTF-8.])[
  On 1.0 all text is UTF-8. On 0.75/0.76 follow A-TEXT-2 and B-UTF8-1. Characters that CP437 lacks become `?` when the server does not read UTF-8.]

#req("E-RELOAD-1", "On 0.75/0.76, ammo is the server's",
  why: [A timer-based reload disagrees with the server after a tool switch or a shot and leaves the player with ammo that does not shoot.],
  test: [Reload, switch tool mid-reload and shoot during a shotgun reload; compare the ammo with the server's.])[
  Play the reload animation but add ammo only when `Weapon Reload` (28) answers. A shotgun animates shell by shell while unconfirmed shells never overfill the magazine; a shot aborts the reload; no answer in 5 s gives up. A server that answers with nothing loaded ends the reload. (On 1.0, the `Reload Weapon` event is the confirmation.)]

#req("E-AIM-1", "Aim assist only when the server allows it",
  why: [An assist the server did not agree to is an advantage the other players cannot get.],
  test: [Join with and without the `aim-assist` world parameter.])[
  Gamepad aim assist (slower turning over a visible enemy, a short pull when aiming starts) is active only when the world parameter `aim-assist` is `1` on a 1.0 server.]

#req("E-DEMO-1", "Record and play back packets",
  why: [A demo must replay what the server sent, not what a cache invented.],
  test: [Record a join with a cached map, then play it back.])[
  Recording stores every received packet with its time. While recording, never answer `map-cached 1`. Playback sends nothing and joins as a spectator.]

#req("E-DEV-1", "Announce your input device",
  why: [The score board can show who plays with a pad, and servers can tell touch from mouse.],
  test: [Plug in a pad and watch the server's log.])[
  On 1.0 send `Generic Command "device <platform> <input>"` (platform `desktop android iphone console browser`, input `kbm pad touch`) when either changes.]

#req("E-CACHE-1", "Housekeeping for the map cache",
  why: [An unbounded cache fills a phone.],
  test: [Fill the cache past its limit and restart.])[
  Keep the cache by stream (`<CRC32>-<bytes>`), trim least recently used entries over a size limit at start-up, and treat a cache file whose CRC32 no longer matches as missing.]
