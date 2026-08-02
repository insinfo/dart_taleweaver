library;

import 'dart:math' as math;

import '../styles/length.dart';

class Mat2D {
  final double a, b, c, d, e, f;
  const Mat2D(this.a, this.b, this.c, this.d, this.e, this.f);
}

const identityMatrix = Mat2D(1, 0, 0, 1, 0, 0);
Mat2D translate(double x, double y) => Mat2D(1, 0, 0, 1, x, y);
Mat2D scale(double x, double y) => Mat2D(x, 0, 0, y, 0, 0);
Mat2D rotate(double angle) {
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  return Mat2D(cos, sin, -sin, cos, 0, 0);
}

Mat2D compose(Mat2D outer, Mat2D inner) => Mat2D(
      outer.a * inner.a + outer.c * inner.b,
      outer.b * inner.a + outer.d * inner.b,
      outer.a * inner.c + outer.c * inner.d,
      outer.b * inner.c + outer.d * inner.d,
      outer.a * inner.e + outer.c * inner.f + outer.e,
      outer.b * inner.e + outer.d * inner.f + outer.f,
    );

({double x, double y}) applyMatrix(Mat2D matrix, double x, double y) => (
      x: matrix.a * x + matrix.c * y + matrix.e,
      y: matrix.b * x + matrix.d * y + matrix.f,
    );

Mat2D? invert(Mat2D matrix) {
  final determinant = matrix.a * matrix.d - matrix.b * matrix.c;
  if (determinant == 0) return null;
  final a = matrix.d / determinant;
  final b = -matrix.b / determinant;
  final c = -matrix.c / determinant;
  final d = matrix.a / determinant;
  return Mat2D(a, b, c, d, -(a * matrix.e + c * matrix.f),
      -(b * matrix.e + d * matrix.f));
}

double resolveLength(Length length, double basis) => switch (length) {
      PxLength(:final value) => value,
      EmLength(:final value) => value,
      PercentLength(:final value) => value / 100 * basis,
    };
