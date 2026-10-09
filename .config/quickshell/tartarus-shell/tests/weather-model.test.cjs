const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createContext, runInContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');
const model = createContext({});
runInContext(readFileSync(join(__dirname, '../services/WeatherModel.js'), 'utf8'), model);

test('unknown values stay unknown, zero humidity/rain/UV remain valid', () => {
    for (const value of [null, undefined, '', 'not-a-number']) assert.equal(model.number(value), null);
    assert.equal(model.number(0), 0);
    assert.equal(model.uvLabel(null), 'Sin datos');
    assert.equal(model.uvLabel(0), 'Bajo');
    assert.equal(model.icon(null, false), 'cloud');
    assert.equal(model.description(null), 'Sin datos');
});

test('weather conditions distinguish sun, drizzle, snow and storms', () => {
    assert.equal(model.icon(0, false), 'clear_night');
    assert.equal(model.icon(51, true), 'rainy');
    assert.equal(model.icon(71, true), 'weather_snowy');
    assert.equal(model.icon(95, true), 'thunderstorm');
    assert.equal(model.description(3), 'Nublado');
});

test('today/tomorrow filtering follows the location timezone at midnight', () => {
    const timestamp = Date.parse('2026-10-07T22:30:00Z');
    assert.equal(model.localTime(timestamp, 7200), '2026-10-08T00:30');
    assert.equal(model.localTime(timestamp, -18000), '2026-10-07T17:30');
    const hours = ['2026-10-08T00:00', '2026-10-08T01:00', '2026-10-09T00:00'].map(time => ({ time }));
    assert.equal(model.hoursForDay(hours, '2026-10-08', '2026-10-08T00:30').length, 2);
    assert.equal(model.hoursForDay(hours, '2026-10-09', '2026-10-08T00:30').length, 1);
});

test('civil dusk comes after sunset in Madrid and is absent during polar day', () => {
    const dusk = model.minutes(model.dusk('2026-10-08', 40.4168, '19:45'));
    assert.ok(dusk >= 20 * 60 + 10 && dusk <= 20 * 60 + 20);
    assert.equal(model.dusk('2026-06-21', 89, '23:00'), '');
    assert.equal(model.dusk('2026-10-08', null, '19:45'), '');
});

test('condition windows merge adjacent hours without implying sun at night', () => {
    const make = (hour, cloud, rain, isDay = true) => ({ time: `2026-10-08T${hour}:00`, cloud, rain, isDay });
    const runs = model.windows([make('09', 10, 0), make('10', 15, 0), make('11', 80, 0),
        make('12', 80, 55), make('13', 70, 70), make('20', 0, 0, false)]);
    assert.equal(runs.length, 3);
    assert.equal(runs[0].start, '09:00');
    assert.equal(runs[0].end, '11:00');
    assert.equal(runs[2].label, 'Posible lluvia');
    assert.equal(runs[2].end, '14:00');
    assert.equal(model.windows([{ ...make('09', 80, 10), code: 61 }])[0].label, 'Lluvia prevista');
});

test('normalization preserves nulls and includes hourly UV and solar times', () => {
    const data = { current: { time: '2026-10-08T10:15', temperature_2m: 16.3, is_day: 1 },
        hourly: { time: ['2026-10-08T10:00'], temperature_2m: [16.3], uv_index: [3.2], precipitation_probability: [0] },
        daily: { time: ['2026-10-08'], sunrise: ['2026-10-08T08:18'], sunset: ['2026-10-08T19:45'] },
        timezone: 'Europe/Madrid', utc_offset_seconds: 7200 };
    const result = model.normalize(data, 40.4168);
    assert.equal(result.current.temp, 16);
    assert.equal(result.current.feelsLike, null);
    assert.equal(result.current.uv, 3.2);
    assert.equal(result.current.rain, 0);
    assert.equal(result.hourly[0].cloud, null);
    assert.equal(result.daily[0].sunrise, '08:18');
    assert.ok(result.daily[0].dusk);
    assert.throws(() => model.normalize({ current: { temperature_2m: null }, hourly: {}, daily: {} }, 0));
});

const today = { date: '2026-10-08', uv: 9 };
const now = '2026-10-08T12:30';
const hour = (time, values = {}) => ({ time: `2026-10-08T${time}:00`, code: 0,
    rain: 0, uv: 0, isDay: true, ...values });
const advice = (hours, date = today, time = now, current = null) =>
    model.planningAdvice(hours, date, time, current);

test('day labels preserve the forecast calendar date at month/year boundaries', () => {
    for (const [date, label] of [['2026-10-08', '08/10'], ['2026-10-09', '09/10'],
        ['2026-10-31', '31/10'], ['2026-11-01', '01/11'],
        ['2026-12-31', '31/12'], ['2027-01-01', '01/01']])
        assert.equal(model.dateLabel(date), label);
    assert.equal(model.dateLabel(model.localTime(Date.parse('2026-12-31T23:30:00Z'), 7200).slice(0, 10)), '01/01');
    for (const value of [null, undefined, '', '2026-10-08T12:00'])
        assert.equal(model.dateLabel(value), '');
});

test('solar protection starts at UV 3 even under cloud cover', () => {
    assert.equal(advice([hour('12', { uv: 2.9 })])[0].kind, 'summary');
    const result = advice([hour('12', { uv: 3, cloud: 99, code: 3 })])[0];
    assert.equal(result.kind, 'sun');
    assert.equal(result.when, 'Ahora');
    assert.match(result.detail, /12:30–13:00.*UV máx. 3.0/);
    assert.match(result.text, /sombra.*ropa protectora/);
    assert.equal(advice([hour('12', { uv: 8 })])[0].severity, 'danger');
});

test('umbrella threshold is 40%, while a rainy code also qualifies', () => {
    assert.equal(advice([hour('12', { rain: 39 })])[0].kind, 'summary');
    assert.equal(advice([hour('12', { rain: 40 })])[0].kind, 'rain');
    const result = advice([hour('13', { code: 61, rain: null })])[0];
    assert.equal(result.kind, 'rain');
    assert.equal(result.when, 'Más tarde');
    assert.match(result.detail, /13:00–14:00.*Lluvia prevista/);
});

test('past hours and the daily UV maximum do not create evening warnings', () => {
    const result = advice([hour('12', { uv: 9, rain: 80 }),
        hour('20', { isDay: false, uv: 0 })], today, '2026-10-08T20:30');
    assert.equal(result.length, 1);
    assert.equal(result[0].kind, 'summary');
    assert.equal(result[0].title, 'Sin avisos por ahora');
    const rainyNight = advice([hour('20', { isDay: false, uv: 8, rain: 60 })], today, '2026-10-08T20:30');
    assert.equal(rainyNight.length, 1);
    assert.equal(rainyNight[0].kind, 'rain');
});

test('tomorrow includes morning forecast and ignores today current conditions', () => {
    const result = advice([{ ...hour('08', { uv: 4 }), time: '2026-10-09T08:00' }],
        { date: '2026-10-09' }, now, { ...hour('12', { code: 95 }), time: now });
    assert.equal(result.length, 1);
    assert.equal(result[0].kind, 'sun');
    assert.equal(result[0].when, 'Mañana');
    assert.match(result[0].detail, /Mañana · 08:00–09:00/);
});

test('fresh current conditions supersede forecast without mutating it', () => {
    const hours = [hour('12')], snapshot = JSON.stringify(hours);
    const result = advice(hours, today, now, { time: now, code: 61, uv: 4, rain: 55, isDay: true });
    assert.equal(result[0].kind, 'rain');
    assert.equal(result[1].kind, 'sun');
    assert.equal(JSON.stringify(hours), snapshot);
    const stale = advice(hours, today, now, { time: '2026-10-08T11:45', code: 95, uv: 8 });
    assert.equal(stale[0].kind, 'summary');
    assert.equal(advice([], today, now, { time: now, code: 61, uv: 0, rain: 70, isDay: true })[0].kind, 'rain');
});

test('adjacent hours merge, gaps remain distinct, ranges are bounded', () => {
    const hours = ['12', '13', '15', '17', '19'].map(time => hour(time, { uv: 4 }));
    const result = advice(hours)[0];
    assert.match(result.detail, /12:30–14:00 · 15:00–16:00 · 17:00–18:00 · …/);
    const night = advice([hour('23', { code: 61, isDay: false })], today, '2026-10-08T23:30')[0];
    assert.match(night.detail, /23:30–00:00/);
});

test('storms receive a shelter notice before umbrella and solar notices', () => {
    const result = advice([hour('12', { code: 95, rain: 90, uv: 4 })]);
    assert.equal(result.length, 3);
    assert.equal(result[0].kind, 'storm');
    assert.equal(result[0].severity, 'danger');
    assert.match(result[0].text, /paraguas no protege/);
    assert.equal(result[1].kind, 'rain');
    assert.equal(result[2].kind, 'sun');
});

test('unknown forecast is not described as no warnings, zero is valid', () => {
    assert.equal(advice([])[0].title, 'Faltan datos para recomendar');
    assert.equal(advice([hour('12', { uv: null })])[0].title, 'Faltan datos para recomendar');
    assert.equal(advice([hour('12', { rain: null })])[0].title, 'Faltan datos para recomendar');
    assert.equal(advice([hour('12')])[0].title, 'Sin avisos por ahora');
    assert.equal(advice([hour('20', { uv: null, isDay: false })])[0].title, 'Sin avisos por ahora');
    assert.equal(advice([], null).length, 0);
});
