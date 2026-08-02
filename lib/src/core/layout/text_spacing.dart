library;

double resolveSpacingPx(dynamic value) {
  if (value == 'normal' || value == null) return 0;
  if (value is num) return value.toDouble();
  return 0;
}

bool isWordSeparatorCluster(String text) => text == ' ' || text == '\u00a0';

double clusterSpacing(String text, double letterPx, double wordPx) =>
    letterPx + (isWordSeparatorCluster(text) ? wordPx : 0);
