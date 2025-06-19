const sum = require('../');
const assert = require('assert');

describe('sum', () => {
  it('should handle positive number', () => {
    assert.equal(sum(3, 5), 8);
  });
  it('should handle negative number', () => {
    assert.equal(sum(-3, -5), -2);
  });
  it('should handle decimal', () => {
    assert.equal(sum(3.5, 7.1), 10.6);
  });
  it('should handle zero', () => {
    assert.equal(sum(0, 0), 0);
  });
});