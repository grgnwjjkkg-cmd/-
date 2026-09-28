#!/bin/bash
# 無料3D素材（Quaternius / CC0）をダウンロードする。src/ は git に入れない。
set -e
cd "$(dirname "$0")"
ITCH=../../Oshitabi/tools/sprites/itch.py
get() { # $1=itch slug $2=upload id $3=folder
  [ -d "src/$3" ] && return
  python3 $ITCH "https://quaternius.itch.io/$1" "$2" "src/$3.zip"
  mkdir -p "src/$3" && (cd "src/$3" && unzip -q "../$3.zip") && rm "src/$3.zip"
}
get universal-base-characters 15861669 base
get modular-character-outfits-fantasy 16289385 outfits
get universal-animation-library 17958403 anim
# 武器（Google Drive）
[ -d src/weapons ] || { pip install -q gdown; gdown -q --folder https://drive.google.com/drive/folders/1Z6vYiQxY8W73FXuMWzaTQAg9rzbumnOr -O src/weapons; }
echo done
