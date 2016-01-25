#!/bin/bash

echo "Usage:"
echo "./get_repo_info.sh <repoName>"


repo=$1
filename=$(echo "$repo.json" | tr / -)
echo "Dumping $1 to $filename..."
echo

read -s -p "Password for repo: " pass

curl -u "eacharya:$pass" \
  "https://api.github.com/repos/zigvu/$1/issues?per_page=1000&state=all" \
  > $filename

git clone "https://eacharya:$pass@github.com/zigvu/$repo.wiki.git"

rm -rf "$repo.wiki/.git*"
