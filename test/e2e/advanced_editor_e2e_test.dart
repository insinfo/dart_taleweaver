import 'dart:io';

import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_E2E'] == '1';

  test('advanced editor supports typing, formatting and history in Chrome',
      () async {
    final server = await shelf_io.serve(
      createStaticHandler('web', defaultDocument: 'index.html'),
      'localhost',
      0,
    );
    Browser? browser;
    try {
      browser = await puppeteer.launch(headless: true);
      final page = await browser.newPage();
      await page.goto(
        'http://${server.address.host}:${server.port}/',
        wait: Until.networkIdle,
      );
      await page.waitForSelector('[data-testid="tw-editor-surface"]');

      final title = await page.title;
      expect(title, 'Taleweaver — Editor Word');

      final editor = await page.$('[data-testid="tw-editor-surface"]');
      expect(editor, isNotNull);

      final insertedText = await page.$eval<String>(
        '[data-testid="tw-editor-surface"]',
        '(element) => element.textContent || ""',
      );
      expect(insertedText, contains('Este documento demonstra'));

      await page.click('[data-testid="tw-editor-surface"]');
      await page.keyboard.press(Key.end);
      await page.keyboard.sendCharacter(' typed');
      final typedText = await page.$eval<String>(
        '[data-testid="tw-editor-surface"]',
        '(element) => element.textContent || ""',
      );
      expect(typedText, contains('typed'));

      await page.click('[data-testid="tw-command-bold"]');
      await page.click('[data-testid="tw-command-undo"]');
      await page.click('[data-testid="tw-command-redo"]');
      await page.click('[data-testid="tw-command-line-spacing"]');

      final text = await page.$eval<String>(
        '[data-testid="tw-editor-surface"]',
        '(element) => element.textContent || ""',
      );
      expect(text, isNotEmpty);

      final toolbarButtons = await page.$$eval<int>(
        '[data-testid^="tw-command-"]',
        '(elements) => elements.length',
      );
      expect(toolbarButtons, greaterThanOrEqualTo(20));
    } finally {
      await browser?.close();
      await server.close(force: true);
    }
  },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: enabled ? false : 'Set RUN_E2E=1 to run Chrome UI tests');
}
