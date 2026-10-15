-- =====================================================================
-- BİR KERELİK TEMİZLİK: botun şimdiye kadar yazdığı TÜM ilanları siler.
-- Ne zaman: eski/yanlış ilanlar (ör. "Sınav Metinleri ve Değerlendirme Kriterleri", menü başlıkları)
-- uygulamada görünüyorsa. Sonra GitHub > Actions > İlan Botu > Run workflow (mode: run) ile
-- botu bir kez çalıştır; güncel ilanlar yeni kurallarla yeniden eklenir.
-- Dikkat: bu ilanları takip eden kullanıcıların takipleri de silinir.
-- =====================================================================
select source, count(*) from public.appointments group by source order by 2 desc;  -- silmeden önceki durum

delete from public.appointments
where source in ('kariyerkapisi', 'yerelyonetimler', 'pgm_adalet', 'kamuilan', 'iskur', 'diger');

select count(*) as kalan from public.appointments;  -- 0 olmalı
