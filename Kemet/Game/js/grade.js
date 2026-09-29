// 画面の色づくり（最後に1回かける）：S字のコントラスト、影は青緑・光は金色に寄せる、彩度、画面の端を暗く（ビネット）
export const GradeShader = {
  uniforms: {
    tDiffuse: { value: null },
    contrast: { value: 1.18 },    // コントラスト（S字カーブの強さ）
    saturation: { value: 1.12 },
    warm: { value: 0.06 },        // 明るい所を金色へ
    cool: { value: 0.05 },        // 暗い所を青緑へ
    lift: { value: 0.0 },         // 黒の持ち上げ（マイナスで締まる）
    vignette: { value: 0.32 },    // 画面の端の暗さ
  },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float contrast, saturation, warm, cool, lift, vignette; varying vec2 vUv;
    void main() {
      vec4 t = texture2D(tDiffuse, vUv); vec3 c = t.rgb;
      // S字：真ん中を中心にメリハリ
      c = clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);
      c = c * c * (3.0 - 2.0 * c) * 0.35 + c * 0.65;
      float l = dot(c, vec3(0.299, 0.587, 0.114));
      c = mix(vec3(l), c, saturation);
      // 光と影の色（スプリットトーン）
      c += vec3(1.0, 0.72, 0.35) * warm * smoothstep(0.45, 1.0, l);
      c += vec3(-0.35, 0.15, 0.4) * cool * (1.0 - smoothstep(0.0, 0.45, l));
      c = c + lift * (1.0 - c);
      // ビネット
      vec2 d = vUv - 0.5; d.x *= 1.25;
      c *= 1.0 - vignette * smoothstep(0.25, 0.85, length(d));
      gl_FragColor = vec4(clamp(c, 0.0, 1.0), t.a);
    }`,
};
