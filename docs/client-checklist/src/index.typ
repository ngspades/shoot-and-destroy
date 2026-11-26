#import "template.typ": *
#show: site-page

This is a checklist for people writing a client of Ace of Spades: the classic 0.75 and 0.76 protocol, the community's 0.75 extensions, and the 1.0 protocol of ngspades-server. It is written in the spirit of #link("https://notaburner.mooo.com/assets/clidoc_draft.html")[the AoS 0.75.015 Canon Client Doc]: a numbered list of requirements, each testable, each with a line on what breaks if you skip it. It says *what* a client must do and links to #link(proto-url)[the protocol documentation] for *where* each packet is specified, so it does not repeat the packet tables.

#note[*How to read it.* "MUST" is a requirement for interoperating with real servers; "SHOULD" is what a good client does; "MAY" is optional. Every requirement has an id (`A-NET-1`), a *Why* line, a *Check* line and the status of ngspades-client in the conformance matrix (section H). The document describes behaviour you can observe on the wire; where it names a number, it came from the public protocol pages or the public server.]

#warning[*Forewarning about references.* Several programs implement these protocols and none is perfect. Our protocol pages describe what ngspades-server sends and accepts; the classic clients and servers have quirks that were never written down. When you meet a disagreement, trust a captured packet from a real server over any document, ours included, and tell us so the page can be fixed.]

*Parts.* A: protocol 0.75 and 0.76. B: the 0.75 extensions. C: protocol 1.0. D: server lists and queries. E: optional improvements of ngspades-client. F: reference tables (CP437, palette). G: how to test. H: the conformance matrix.

#include "parts/a.typ"
#include "parts/b.typ"
#include "parts/c.typ"
#include "parts/m.typ"
#include "parts/o.typ"
#include "parts/f.typ"
