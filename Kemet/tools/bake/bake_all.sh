#!/bin/sh
# 地図の光をまとめて計算して、ゲーム用に軽くする。使い方（Kemet/ で）: tools/bake/bake_all.sh [samples] [地図の名前...]
# BLENDER に blender の場所を入れておく（例: BLENDER=/Applications/Blender.app/Contents/MacOS/Blender）
BLENDER=${BLENDER:-blender}
SAMPLES=${1:-160}; shift
LEVELS=${*:-"necropolis giza pyramid"}
for lv in $LEVELS; do
  echo "== $lv"
  "$BLENDER" -b --python "tools/bake/$lv.py" -- "$SAMPLES" || exit 1
  python3 tools/bake/compress.py "Game/assets/levels/$lv" || exit 1
done
