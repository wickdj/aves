import 'dart:ui';

import 'package:aves/model/view_state.dart';
import 'package:test/test.dart';

void main() {
  test('scene -> viewport, original scaleFit', () {
    const viewport = Rect.fromLTWH(0, 0, 100, 200);
    const content = Rect.fromLTWH(0, 0, 200, 400);
    final state = ViewState(position: Offset.zero, scale: 1, viewportSize: viewport.size, contentSize: content.size);

    expect(state.toViewportPoint(content.topLeft), const Offset(-50, -100));
    expect(state.toViewportPoint(content.bottomRight), const Offset(150, 300));
  });

  test('scene -> viewport, scaled to fit .5', () {
    const viewport = Rect.fromLTWH(0, 0, 100, 200);
    const content = Rect.fromLTWH(0, 0, 200, 400);
    final state = ViewState(position: Offset.zero, scale: .5, viewportSize: viewport.size, contentSize: content.size);

    expect(state.toViewportPoint(content.topLeft), viewport.topLeft);
    expect(state.toViewportPoint(content.center), viewport.center);
    expect(state.toViewportPoint(content.bottomRight), viewport.bottomRight);
  });

  test('scene -> viewport, scaled to fit .25', () {
    const viewport = Rect.fromLTWH(0, 0, 50, 100);
    const content = Rect.fromLTWH(0, 0, 200, 400);
    final state = ViewState(position: Offset.zero, scale: .25, viewportSize: viewport.size, contentSize: content.size);

    expect(state.toViewportPoint(content.topLeft), viewport.topLeft);
    expect(state.toViewportPoint(content.center), viewport.center);
    expect(state.toViewportPoint(content.bottomRight), viewport.bottomRight);
  });

  test('viewport -> scene, original scaleFit', () {
    const viewport = Rect.fromLTWH(0, 0, 100, 200);
    const content = Rect.fromLTWH(0, 0, 200, 400);
    final state = ViewState(position: Offset.zero, scale: 1, viewportSize: viewport.size, contentSize: content.size);

    expect(state.toContentPoint(viewport.topLeft), const Offset(50, 100));
    expect(state.toContentPoint(viewport.bottomRight), const Offset(150, 300));
  });

  test('viewport -> scene, scaled to fit', () {
    const viewport = Rect.fromLTWH(0, 0, 100, 200);
    const content = Rect.fromLTWH(0, 0, 200, 400);
    final state = ViewState(position: Offset.zero, scale: .5, viewportSize: viewport.size, contentSize: content.size);

    expect(state.toContentPoint(viewport.topLeft), content.topLeft);
    expect(state.toContentPoint(viewport.center), content.center);
    expect(state.toContentPoint(viewport.bottomRight), content.bottomRight);
  });

  test('viewport -> scene, translated', () {
    const viewport = Rect.fromLTWH(0, 0, 100, 200);
    const content = Rect.fromLTWH(0, 0, 200, 400);
    final state = ViewState(position: const Offset(50, 50), scale: 1, viewportSize: viewport.size, contentSize: content.size);

    state.toContentPoint(viewport.topLeft);
    expect(state.toContentPoint(viewport.topLeft), const Offset(0, 50));
    expect(state.toContentPoint(viewport.bottomRight), const Offset(100, 250));
  });

  test('scene -> viewport, scaled to fit, different ratios', () {
    const viewport = Rect.fromLTWH(0, 0, 360, 521);
    const content = Rect.fromLTWH(0, 0, 2268, 4032);
    final scaleFit = viewport.height / content.height;
    final state = ViewState(position: Offset.zero, scale: scaleFit, viewportSize: viewport.size, contentSize: content.size);

    final scaledContentLeft = (viewport.width - content.width * scaleFit) / 2;
    final scaledContentRight = viewport.width - scaledContentLeft;

    expect(state.toViewportPoint(content.topLeft), Offset(scaledContentLeft, 0));
    expect(state.toViewportPoint(content.center), viewport.center);
    expect(state.toViewportPoint(content.bottomRight), Offset(scaledContentRight, viewport.bottom));
  });
}
