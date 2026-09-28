#!/bin/bash
# 無料3D素材（Quaternius / CC0）と three.js をダウンロードする。assets/ は git に入れない。
set -e
cd "$(dirname "$0")"
mkdir -p assets lib/jsm/loaders lib/jsm/utils lib/jsm/environments
V=0.169.0; CDN=https://cdn.jsdelivr.net/npm/three@$V
curl -sS -o lib/three.module.js $CDN/build/three.module.js
curl -sS -o lib/jsm/loaders/GLTFLoader.js $CDN/examples/jsm/loaders/GLTFLoader.js
curl -sS -o lib/jsm/utils/BufferGeometryUtils.js $CDN/examples/jsm/utils/BufferGeometryUtils.js
curl -sS -o lib/jsm/environments/RoomEnvironment.js $CDN/examples/jsm/environments/RoomEnvironment.js
get() { # $1=itch slug $2=upload id $3=folder
  [ -d "assets/$3" ] && return
  python3 itch.py "https://quaternius.itch.io/$1" "$2" "assets/$3.zip"
  mkdir -p "assets/$3" && (cd "assets/$3" && unzip -q "../$3.zip") && rm "assets/$3.zip"
}
get universal-base-characters 15861669 base
get modular-character-outfits-fantasy 16289385 outfits
get universal-animation-library 17958403 anim
echo done
