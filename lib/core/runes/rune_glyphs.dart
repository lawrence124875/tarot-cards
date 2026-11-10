import 'dart:ui';

/// 24 個古弗薩克符文的線條（程式繪製，不用字型或圖檔）。
/// 座標在 0–1 的方框內（x 向右、y 向下）；每個符文是幾條折線。逆位＝繞中心旋轉 180°。
const Map<String, List<List<Offset>>> runeStrokes = {
  'fehu': [
    [Offset(0.25, 0), Offset(0.25, 1)],
    [Offset(0.25, 0.32), Offset(0.78, 0.04)],
    [Offset(0.25, 0.58), Offset(0.78, 0.3)],
  ],
  'uruz': [
    [Offset(0.22, 1), Offset(0.22, 0), Offset(0.78, 0.32), Offset(0.78, 1)],
  ],
  'thurisaz': [
    [Offset(0.28, 0), Offset(0.28, 1)],
    [Offset(0.28, 0.25), Offset(0.74, 0.5), Offset(0.28, 0.75)],
  ],
  'ansuz': [
    [Offset(0.25, 0), Offset(0.25, 1)],
    [Offset(0.25, 0.02), Offset(0.78, 0.3)],
    [Offset(0.25, 0.3), Offset(0.78, 0.58)],
  ],
  'raidho': [
    [Offset(0.24, 1), Offset(0.24, 0), Offset(0.72, 0.24), Offset(0.24, 0.48), Offset(0.78, 1)],
  ],
  'kenaz': [
    [Offset(0.72, 0.22), Offset(0.3, 0.5), Offset(0.72, 0.78)],
  ],
  'gebo': [
    [Offset(0.15, 0.1), Offset(0.85, 0.9)],
    [Offset(0.85, 0.1), Offset(0.15, 0.9)],
  ],
  'wunjo': [
    [Offset(0.28, 1), Offset(0.28, 0), Offset(0.74, 0.22), Offset(0.28, 0.44)],
  ],
  'hagalaz': [
    [Offset(0.22, 0), Offset(0.22, 1)],
    [Offset(0.78, 0), Offset(0.78, 1)],
    [Offset(0.22, 0.36), Offset(0.78, 0.64)],
  ],
  'naudhiz': [
    [Offset(0.5, 0), Offset(0.5, 1)],
    [Offset(0.22, 0.36), Offset(0.78, 0.64)],
  ],
  'isa': [
    [Offset(0.5, 0), Offset(0.5, 1)],
  ],
  'jera': [
    [Offset(0.46, 0.18), Offset(0.16, 0.42), Offset(0.46, 0.66)],
    [Offset(0.54, 0.34), Offset(0.84, 0.58), Offset(0.54, 0.82)],
  ],
  'eihwaz': [
    [Offset(0.5, 0), Offset(0.5, 1)],
    [Offset(0.5, 0), Offset(0.8, 0.2)],
    [Offset(0.5, 1), Offset(0.2, 0.8)],
  ],
  'perthro': [
    [Offset(0.24, 0), Offset(0.24, 1)],
    [Offset(0.24, 0), Offset(0.52, 0.24), Offset(0.8, 0)],
    [Offset(0.24, 1), Offset(0.52, 0.76), Offset(0.8, 1)],
  ],
  'algiz': [
    [Offset(0.5, 0), Offset(0.5, 1)],
    [Offset(0.16, 0.02), Offset(0.5, 0.36), Offset(0.84, 0.02)],
  ],
  'sowilo': [
    [Offset(0.7, 0), Offset(0.3, 0.36), Offset(0.7, 0.64), Offset(0.3, 1)],
  ],
  'tiwaz': [
    [Offset(0.5, 0), Offset(0.5, 1)],
    [Offset(0.16, 0.32), Offset(0.5, 0), Offset(0.84, 0.32)],
  ],
  'berkano': [
    [Offset(0.26, 0), Offset(0.26, 1)],
    [Offset(0.26, 0), Offset(0.74, 0.25), Offset(0.26, 0.5), Offset(0.74, 0.75), Offset(0.26, 1)],
  ],
  'ehwaz': [
    [Offset(0.16, 1), Offset(0.16, 0), Offset(0.5, 0.34), Offset(0.84, 0), Offset(0.84, 1)],
  ],
  'mannaz': [
    [Offset(0.16, 0), Offset(0.16, 1)],
    [Offset(0.84, 0), Offset(0.84, 1)],
    [Offset(0.16, 0), Offset(0.84, 0.44)],
    [Offset(0.84, 0), Offset(0.16, 0.44)],
  ],
  'laguz': [
    [Offset(0.3, 1), Offset(0.3, 0), Offset(0.74, 0.3)],
  ],
  'ingwaz': [
    [Offset(0.5, 0.2), Offset(0.8, 0.5), Offset(0.5, 0.8), Offset(0.2, 0.5), Offset(0.5, 0.2)],
  ],
  'dagaz': [
    [Offset(0.12, 0.12), Offset(0.12, 0.88), Offset(0.88, 0.12), Offset(0.88, 0.88), Offset(0.12, 0.12)],
  ],
  'othala': [
    [Offset(0.86, 1), Offset(0.2, 0.32), Offset(0.5, 0.02), Offset(0.8, 0.32), Offset(0.14, 1)],
  ],
};
