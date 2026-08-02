library;

enum BidiClass {
  l,
  r,
  al,
  en,
  an,
  es,
  et,
  cs,
  nsm,
  b,
  s,
  ws,
  on,
  lri,
  rli,
  fsi,
  pdi,
  bn
}

BidiClass bidiClass(int codePoint) {
  if (codePoint < 0 || codePoint > 0x10ffff) return BidiClass.l;
  if (codePoint == 0x0a ||
      codePoint == 0x0d ||
      codePoint == 0x2028 ||
      codePoint == 0x2029) return BidiClass.b;
  if (codePoint == 0x09) return BidiClass.s;
  if (codePoint == 0x20 || codePoint == 0xa0) return BidiClass.ws;
  if (codePoint >= 0x30 && codePoint <= 0x39) return BidiClass.en;
  if (codePoint >= 0x660 && codePoint <= 0x669) return BidiClass.an;
  if (codePoint >= 0x590 && codePoint <= 0x5ff) return BidiClass.r;
  if ((codePoint >= 0x600 && codePoint <= 0x6ff) ||
      (codePoint >= 0x750 && codePoint <= 0x77f)) return BidiClass.al;
  if (codePoint == 0x2066) return BidiClass.lri;
  if (codePoint == 0x2067) return BidiClass.rli;
  if (codePoint == 0x2068) return BidiClass.fsi;
  if (codePoint == 0x2069) return BidiClass.pdi;
  if (codePoint >= 0x300 && codePoint <= 0x36f) return BidiClass.nsm;
  if (codePoint == 0x2b || codePoint == 0x2d) return BidiClass.es;
  if (codePoint == 0x2c || codePoint == 0x2e || codePoint == 0x3a)
    return BidiClass.cs;
  if (codePoint == 0x21 ||
      codePoint == 0x22 ||
      codePoint == 0x27 ||
      codePoint == 0x28 ||
      codePoint == 0x29) return BidiClass.on;
  return BidiClass.l;
}
