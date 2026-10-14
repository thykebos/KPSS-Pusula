-- =====================================================================
-- SINAV TARİHLERİ (ana ekrandaki geri sayım için)
-- Kaynak: ÖSYM 2026 takvimi (Aralık 2025 / Nisan 2026 tarihli haber sayfaları):
--   KPSS Lisans GY-GK ........ 6 Eylül 2026   (başvuru 1-13 Temmuz)
--   KPSS Önlisans ............ 4 Ekim 2026    (başvuru 29 Temmuz-10 Ağustos)
--   KPSS Ortaöğretim ......... 25 Ekim 2026   (başvuru 27 Ağustos-8 Eylül)
-- ! Tarihleri osym.gov.tr duyurularından mutlaka doğrula. Sınav SAATİ kaynaklarda
--   verilmediği için 10:15 (Türkiye saati) varsayılmıştır; geri sayım dakikasını etkiler.
-- Tekrar çalıştırmak güvenlidir: aynı adlı sınav varsa eklenmez.
-- Sonraki yıl takvimi açıklanınca aynı biçimde satır ekle (ileride ÖSYM botu bunu otomatikleştirecek).
-- =====================================================================

insert into public.exams (name, education_levels, exam_date, application_end, url)
select v.name, v.levels::education_level[], v.exam_date, v.application_end, v.url
from (values
  ('KPSS Lisans (GY-GK) 2026',  '{lisans}',   timestamptz '2026-09-06 10:15:00+03', timestamptz '2026-07-13 23:59:00+03', 'https://www.osym.gov.tr'),
  ('KPSS Önlisans 2026',        '{onlisans}', timestamptz '2026-10-04 10:15:00+03', timestamptz '2026-08-10 23:59:00+03', 'https://www.osym.gov.tr'),
  ('KPSS Ortaöğretim 2026',     '{lise}',     timestamptz '2026-10-25 10:15:00+03', timestamptz '2026-09-08 23:59:00+03', 'https://www.osym.gov.tr')
) as v(name, levels, exam_date, application_end, url)
where not exists (select 1 from public.exams e where e.name = v.name);

-- Geri sayımı kendi seviyende denemek istersen (tarih gelecekte olmalı), örneğin:
-- insert into public.exams (name, education_levels, exam_date)
-- values ('TEST SINAVI', '{lisans,onlisans,lise}', now() + interval '20 days 3 hours');

select name, education_levels, exam_date from public.exams order by exam_date;
