const path = require('node:path');

/**
 * Reproducible Office-style icon font generation.
 *
 * Run from the repository root:
 *   npx --yes fantasticon@1.2.3 --config lib/assets/icons/taleweaver/fantasticon.config.js
 */
module.exports = {
  // `glob` receives this path on Windows; force slash separators so that it
  // treats the trailing `**/*.svg` as a glob rather than escaped text.
  inputDir: __dirname.replace(/\\/g, '/'),
  outputDir: path.resolve(__dirname, '../../fonts'),
  name: 'TaleweaverOfficeIcons',
  fontTypes: ['ttf', 'woff', 'woff2'],
  assetTypes: ['json'],
  fontHeight: 1000,
  descent: 200,
  normalize: true,
  prefix: 'tw-office-icon',
  fontsUrl: './',
  formatOptions: {
    json: { indent: 2 },
  },
  codepoints: {
    bold: 0xe900,
    italic: 0xe901,
    underline: 0xe902,
    undo: 0xe903,
    redo: 0xe904,
    cut: 0xe905,
    copy: 0xe906,
    paste: 0xe907,
    'align-left': 0xe908,
    'align-center': 0xe909,
    'align-right': 0xe90a,
    'align-justify': 0xe90b,
    'list-bullets': 0xe90c,
    'list-numbered': 0xe90d,
    table: 0xe90e,
    image: 0xe90f,
    'text-box': 0xe910,
    rectangle: 0xe911,
    ellipse: 0xe912,
    line: 0xe913,
    save: 0xe914,
    print: 0xe915,
    find: 0xe916,
  },
};
