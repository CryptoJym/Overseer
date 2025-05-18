const { buildSummary } = require('../dist/index');

describe('buildSummary', () => {
  test('creates summary string', () => {
    const pr = { number: 5, title: 'Test', body: 'Body' };
    const changedFiles = '- a.txt (added)\n- b.js (modified)';
    const summary = buildSummary(pr, changedFiles);
    expect(summary).toContain('PR #5: Test');
    expect(summary).toContain('Body');
    expect(summary).toContain(changedFiles);
  });
});
