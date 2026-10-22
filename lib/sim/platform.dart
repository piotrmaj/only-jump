/// An ice platform. [y] is the top surface (the side you land on).
class Platform {
  const Platform({
    required this.x,
    required this.y,
    required this.width,
    this.height = 12,
    this.safe = false,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  /// A milestone floor that spans the whole level, so it cannot be missed.
  final bool safe;

  double get left => x;
  double get right => x + width;
  double get centerX => x + width / 2;
  double get bottom => y + height;

  bool overlapsX(double l, double r) => r > x && l < right;
  bool containsX(double px) => px >= x && px <= right;

  @override
  String toString() =>
      'Platform(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, w: ${width.toStringAsFixed(1)}${safe ? ', safe' : ''})';
}
