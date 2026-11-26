#!/usr/bin/env python3
"""Link check over the built site.

  * every internal href/src resolves to a file; every #fragment exists as an id,
  * the PDF, 404.html, style.css and .nojekyll exist,
  * links into the protocol documentation: the page is fetched once and every
    #fragment must exist there (skipped with --offline; a fetch failure is a
    warning, a missing fragment is an error).
"""
import html.parser
import sys
import urllib.parse
import subprocess
from pathlib import Path

PREFIX = "/shoot-and-destroy/"


class Page(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.links = set(), []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        for key in ("href", "src"):
            if key in a and tag != "meta":
                self.links.append(a[key])


def parse(text):
    p = Page()
    p.feed(text)
    return p


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    offline = "--offline" in sys.argv
    site = Path(args[0] if args else "site").resolve()
    bad, warn = [], []
    for need in ("index.html", "404.html", "style.css", ".nojekyll", "pdf/client-checklist.pdf"):
        if not (site / need).exists():
            bad.append("missing " + need)
    parsed = {f: parse(f.read_text()) for f in sorted(site.rglob("*.html"))}
    remote, count = {}, 0
    for f, p in parsed.items():
        rel = f.relative_to(site)
        for link in p.links:
            count += 1
            u = urllib.parse.urlsplit(link)
            if u.scheme in ("http", "https"):
                if offline or not link.startswith("https://ngspades.github.io/protocol/") or not u.fragment:
                    continue
                page = u.scheme + "://" + u.netloc + u.path
                if page not in remote:
                    try:
                        out = subprocess.run(["curl", "-fsSL", "--max-time", "30", page],
                                             capture_output=True, check=True).stdout
                        remote[page] = parse(out.decode("utf-8", "replace"))
                    except Exception as e:  # noqa
                        remote[page] = None
                        warn.append("could not fetch %s: %s" % (page, e))
                rp = remote[page]
                if rp is not None and u.fragment not in rp.ids:
                    bad.append("%s: %s -> no #%s on that page" % (rel, link, u.fragment))
                continue
            if u.scheme:
                continue
            path = u.path
            if path.startswith(PREFIX):
                target = site / path[len(PREFIX):]
            elif path.startswith("/"):
                bad.append("%s: root-relative link %s is outside %s" % (rel, link, PREFIX))
                continue
            elif path == "":
                target = f
            else:
                target = f.parent / path
            if target.is_dir():
                target = target / "index.html"
            if not target.exists():
                bad.append("%s: %s does not exist" % (rel, link))
                continue
            if u.fragment and target.suffix == ".html":
                tp = parsed.get(target)
                if tp is None or u.fragment not in tp.ids:
                    bad.append("%s: %s -> no #%s in %s" % (rel, link, u.fragment, target.relative_to(site)))
    print("linkcheck: %d pages, %d links" % (len(parsed), count))
    for w in warn:
        print("  warning: " + w)
    for b in bad:
        print("  " + b)
    if bad:
        sys.exit(1)
    print("linkcheck: ok")


if __name__ == "__main__":
    main()
