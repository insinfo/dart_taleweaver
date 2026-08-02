/// Tab-stop vocabulary.
///
/// Port of `styles/tab-stops.ts`.
library;

/// How content after a tab aligns to the stop.
enum TabAlignment {
  left,
  center,
  right,
  decimal,
  contentEdge;

  String get value {
    switch (this) {
      case TabAlignment.left:
        return 'left';
      case TabAlignment.center:
        return 'center';
      case TabAlignment.right:
        return 'right';
      case TabAlignment.decimal:
        return 'decimal';
      case TabAlignment.contentEdge:
        return 'content-edge';
    }
  }

  static TabAlignment fromString(String val) {
    switch (val) {
      case 'left':
        return TabAlignment.left;
      case 'center':
        return TabAlignment.center;
      case 'right':
        return TabAlignment.right;
      case 'decimal':
        return TabAlignment.decimal;
      case 'content-edge':
        return TabAlignment.contentEdge;
      default:
        throw ArgumentError('Unhandled TabAlignment: $val');
    }
  }
}

/// Leader glyphs drawn across the tab gap.
enum LeaderStyle {
  none,
  dot,
  dash,
  line;

  String get value {
    switch (this) {
      case LeaderStyle.none:
        return 'none';
      case LeaderStyle.dot:
        return 'dot';
      case LeaderStyle.dash:
        return 'dash';
      case LeaderStyle.line:
        return 'line';
    }
  }

  static LeaderStyle fromString(String val) {
    switch (val) {
      case 'none':
        return LeaderStyle.none;
      case 'dot':
        return LeaderStyle.dot;
      case 'dash':
        return LeaderStyle.dash;
      case 'line':
        return LeaderStyle.line;
      default:
        throw ArgumentError('Unhandled LeaderStyle: $val');
    }
  }
}

class TabStop {
  /// Position in px from the inline-start content edge.
  final double position;
  final TabAlignment alignment;
  final LeaderStyle leader;

  const TabStop({
    required this.position,
    required this.alignment,
    required this.leader,
  });

  Map<String, dynamic> toJson() => {
        'position': position,
        'alignment': alignment.value,
        'leader': leader.value,
      };

  factory TabStop.fromJson(Map<String, dynamic> json) => TabStop(
        position: (json['position'] as num).toDouble(),
        alignment: TabAlignment.fromString(json['alignment'] as String),
        leader: LeaderStyle.fromString(json['leader'] as String),
      );
}
