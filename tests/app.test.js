const request = require('supertest');
const app = require('../index');

describe('GET /health', () => {
  it('responds with 200 and body "OK"', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.text).toBe('OK');
  });
});

describe('GET /', () => {
  it('responds with 200 and a JSON message', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message');
    expect(typeof res.body.message).toBe('string');
    expect(res.body.message.length).toBeGreaterThan(0);
  });
});
