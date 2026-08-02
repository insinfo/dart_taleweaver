library;

enum LineBreakClass {
  bk,
  cr,
  lf,
  nl,
  sp,
  zw,
  wj,
  gl,
  cm,
  zwj,
  hy,
  ba,
  bb,
  op,
  cl,
  cp,
  qu,
  al,
  nu,
  id,
  ri,
  eb,
  em,
  xx;
}

LineBreakClass lineBreakClass(int codePoint) {
  if (codePoint < 0 || codePoint > 0x10ffff) return LineBreakClass.xx;
  if (codePoint >= 0x30 && codePoint <= 0x39) return LineBreakClass.nu;
  if (codePoint >= 0x1f1e6 && codePoint <= 0x1f1ff) return LineBreakClass.ri;
  if (codePoint >= 0x1f3fb && codePoint <= 0x1f3ff) return LineBreakClass.em;
  if (codePoint >= 0x1f300 && codePoint <= 0x1faff) return LineBreakClass.eb;
  if (codePoint >= 0x3000 && codePoint <= 0x9fff) return LineBreakClass.id;
  return switch (codePoint) {
    0x0a => LineBreakClass.lf,
    0x0d => LineBreakClass.cr,
    0x0b || 0x0c || 0x85 || 0x2028 || 0x2029 => LineBreakClass.bk,
    0x20 || 0x09 => LineBreakClass.sp,
    0x200b => LineBreakClass.zw,
    0x2060 => LineBreakClass.wj,
    0x200d => LineBreakClass.zwj,
    0x00ad || 0x2010 || 0x2d => LineBreakClass.hy,
    0x28 || 0x5b || 0x7b => LineBreakClass.op,
    0x29 || 0x5d || 0x7d => LineBreakClass.cl,
    0x22 || 0x27 || 0x2018 || 0x201c || 0x00ab => LineBreakClass.qu,
    _ when _isCombining(codePoint) => LineBreakClass.cm,
    _ => LineBreakClass.al,
  };
}

bool _isCombining(int codePoint) =>
    (codePoint >= 0x300 && codePoint <= 0x36f) ||
    (codePoint >= 0x1ab0 && codePoint <= 0x1aff) ||
    (codePoint >= 0x20d0 && codePoint <= 0x20ff) ||
    (codePoint >= 0xfe00 && codePoint <= 0xfe0f);
