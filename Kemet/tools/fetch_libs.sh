#!/bin/bash
# three.js をゲームに同梱する（ネット接続なしで動くように）
set -e
cd "$(dirname "$0")/../Game/lib"
V=0.169.0; CDN=https://cdn.jsdelivr.net/npm/three@$V
mkdir -p jsm/loaders jsm/utils jsm/environments jsm/exporters jsm/libs jsm/curves jsm/postprocessing jsm/shaders jsm/objects
curl -sS -o three.module.js $CDN/build/three.module.js
for f in loaders/GLTFLoader.js loaders/FBXLoader.js utils/BufferGeometryUtils.js utils/SkeletonUtils.js utils/TextureUtils.js \
         environments/RoomEnvironment.js exporters/GLTFExporter.js libs/fflate.module.js curves/NURBSCurve.js curves/NURBSUtils.js postprocessing/EffectComposer.js postprocessing/RenderPass.js postprocessing/ShaderPass.js postprocessing/UnrealBloomPass.js postprocessing/OutputPass.js postprocessing/Pass.js postprocessing/MaskPass.js shaders/CopyShader.js shaders/LuminosityHighPassShader.js shaders/OutputShader.js objects/Reflector.js; do
  curl -sS -o jsm/$f $CDN/examples/jsm/$f
done
echo ok
