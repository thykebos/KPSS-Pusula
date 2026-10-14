-- =====================================================================
-- TEST SINAVI: geri sayım kartını denemek için (tüm seviyeler, ~20 gün sonra)
-- Neden gerekli: sample_exams.sql'deki Lisans (6 Eylül) ve Önlisans (4 Ekim) 2026
-- tarihleri geçtiği için bu seviyelerde "yaklaşan sınav yok" görünür. Bu bir hata değil;
-- ÖSYM yeni takvimi açıklayana kadar veri yoktur. Gerçek tarihleri osym.gov.tr'den doğrula.
-- Tekrar çalıştırmak güvenlidir. İşin bitince silmek için dosyanın en altındaki delete'i çalıştır.
-- =====================================================================

insert into public.exams (name, education_levels, exam_date, application_end, url)
select 'TEST SINAVI (silinebilir)', '{lisans,onlisans,lise}'::education_level[],
       now() + interval '20 days 3 hours', now() + interval '10 days',
       'https://www.osym.gov.tr'
where not exists (select 1 from public.exams where name = 'TEST SINAVI (silinebilir)');

select name, education_levels, exam_date from public.exams order by exam_date;

-- Temizlik (test bitince):
-- delete from public.exams where name = 'TEST SINAVI (silinebilir)';
