# ngspades-client Checklist

The source of https://ngspades.github.io/shoot-and-destroy/, written in Typst.

```sh
make site      # site/index.html, 404.html, style.css, pdf/client-checklist.pdf
make check     # unique requirement ids, every id in the matrix, link check
make clean
make publish   # force-pushes site/ to the gh-pages branch of origin
```

Needs Typst 0.15 or later and Python 3. Every requirement is `#req("ID", ...)` in `src/parts/`; its status for ngspades-client is one row of `src/matrix.typ`. `make check` fails when the two disagree, and fetches the protocol pages to verify every link into them (`make check OFFLINE=1` skips that).

Text: CC BY 4.0 (see LICENSE).
