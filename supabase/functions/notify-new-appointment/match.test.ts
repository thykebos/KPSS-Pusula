// Çalıştırma: node --test supabase/functions/notify-new-appointment/match.test.ts
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { foldTr, shouldNotify, type NotifyAppointment } from './match.ts';

const base: NotifyAppointment = {
  title: 'HEMŞİRE alımı', institution: 'Ankara Şehir Hastanesi', education_levels: ['lisans'], departments: ['Hemşirelik'],
};

test('foldTr Türkçe harfleri sadeleştirir', () => {
  assert.equal(foldTr('HEMŞİRE ŞOFÖR Iğdır'), 'hemsire sofor igdir');
});
test('meslek etiketi yoksa seviyeye uyan herkese gider', () => {
  assert.equal(shouldNotify({ education_level: 'lisans', followed_professions: [] }, base), true);
  assert.equal(shouldNotify({ education_level: 'lisans', followed_professions: null }, base), true);
});
test('seviye uyuşmuyorsa gitmez', () => {
  assert.equal(shouldNotify({ education_level: 'lise', followed_professions: [] }, base), false);
});
test('seviye boş liste: herkese açık', () => {
  assert.equal(shouldNotify({ education_level: 'lise', followed_professions: [] }, { ...base, education_levels: [] }), true);
});
test('meslek etiketi eşleşirse gider, eşleşmezse gitmez', () => {
  assert.equal(shouldNotify({ education_level: 'lisans', followed_professions: ['hemşire'] }, base), true);
  assert.equal(shouldNotify({ education_level: 'lisans', followed_professions: ['Zabıt Katibi'] }, base), false);
});
test('çok kısa etiket yok sayılır', () => {
  assert.equal(shouldNotify({ education_level: 'lisans', followed_professions: ['a'] }, base), true);
});
