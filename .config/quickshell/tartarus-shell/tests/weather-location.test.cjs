const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');
const places = createContext({});
runInContext(readFileSync(join(__dirname, '../services/WeatherLocation.js'), 'utf8'), places);
const madrid = { id: 3117735, name: 'Madrid', latitude: 40.4165, longitude: -3.70256,
    country: 'España', country_code: 'ES', admin1: 'Comunidad Autónoma de Madrid' };

test('city labels distinguish countries and show region in suggestions', () => {
    const city = places.normalize(madrid);
    assert.equal(city.label, 'Madrid / España');
    assert.equal(city.detail, 'Comunidad Autónoma de Madrid');
    assert.equal(places.label(' Madrid ', '', 'ES'), 'Madrid / ES');
    assert.equal(places.normalize({ ...madrid, country: 'Colombia', admin1: 'Cundinamarca' }).label, 'Madrid / Colombia');
});

test('selected place survives JSON persistence without losing identity', () => {
    const selected = places.normalize({ ...madrid, id: 3675707, latitude: 4.73245, longitude: -74.26419,
        country: 'Colombia', country_code: 'CO', admin1: 'Cundinamarca' });
    const restored = places.normalize(JSON.parse(JSON.stringify(selected)));
    assert.equal(restored.id, 3675707);
    assert.equal(restored.lat, 4.73245);
    assert.equal(restored.lon, -74.26419);
    assert.equal(restored.countryCode, 'CO');
    assert.equal(restored.detail, 'Cundinamarca');
});

test('invalid coordinates are rejected but equator/prime meridian are valid', () => {
    for (const latitude of [null, undefined, '', ' ', false, [], 91, 'NaN']) {
        assert.equal(places.normalize({ ...madrid, latitude }), null);
    }
    assert.equal(places.normalize({ ...madrid, longitude: -181 }), null);
    assert.equal(places.normalize({ ...madrid, name: '  ' }), null);
    assert.equal(places.normalize({ ...madrid, latitude: 0, longitude: 0 }).lat, 0);
});

test('search results preserve same-name cities in different countries', () => {
    const colombia = { ...madrid, id: 3675707, country: 'Colombia', latitude: 4.73245 };
    const cities = places.results({ results: [madrid, madrid, colombia, { name: 'broken' }] });
    assert.equal(cities.length, 2);
    assert.equal(cities[0].label, 'Madrid / España');
    assert.equal(cities[1].label, 'Madrid / Colombia');
    assert.equal(places.results(null).length, 0);
    assert.equal(places.results({ error: true }).length, 0);
});

test('search accepts slash labels and safely encodes country/accent qualifiers', () => {
    const url = new URL(places.searchUrl(' Madrid / España ', 8));
    assert.equal(url.searchParams.get('name'), 'Madrid, España');
    assert.equal(url.searchParams.get('language'), 'es');
    assert.equal(url.searchParams.get('count'), '8');
    assert.equal(new URL(places.searchUrl('A&B')).searchParams.get('name'), 'A&B');
});

test('missing administrative fields remain optional and search is capped', () => {
    const city = places.normalize({ name: 'Paris', lat: 48.85, lon: 2.35, countryCode: 'fr', region: 'Paris' });
    assert.equal(city.label, 'Paris / FR');
    assert.equal(city.detail, '');
    assert.equal(places.results({ results: Array.from({ length: 20 }, (_, id) => ({ ...madrid, id })) }).length, 8);
});
