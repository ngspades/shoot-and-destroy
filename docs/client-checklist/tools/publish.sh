#!/bin/sh
# tools/publish.sh <site dir> <branch>
# Pushes the built site as the only content of <branch> on origin, with a
# commit made in a throwaway repository, and force-pushes that one branch.
# Nothing else on the remote is touched.
set -eu
site=$1
branch=$2
remote=$(git remote get-url origin)
rev=$(git rev-parse --short HEAD)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$site"/. "$tmp"/
cd "$tmp"
git init -q -b "$branch"
git add -A
git -c user.name="docs build" -c user.email="docs@localhost" commit -q -m "Site built from $rev"
git push --force "$remote" "HEAD:refs/heads/$branch"
echo "pushed $site/ to $branch"
