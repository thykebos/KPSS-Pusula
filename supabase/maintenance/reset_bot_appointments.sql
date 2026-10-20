-- =====================================================================
-- BİR KERELİK SIFIRLAMA: appointments tablosundaki TÜM ilanları siler (hangi kaynaktan olursa olsun;
-- yeni eklenecek kaynaklar da dahildir, kaynak listesi tutmaya gerek yok).
--
-- Ne zaman: eski/yanlış/tekrar ilanlar uygulamada görünüyorsa ya da temiz başlamak istiyorsan.
-- Sonra botu bir kez çalıştır:   python3 scraper/run.py
-- Güncel ilanlar yeni kurallarla (tekrar önleme + güncellik süzgeci) yeniden eklenir.
--
-- Dikkat: ilanlar silinince kullanıcıların o ilanlara ait TAKİPLERİ de silinir (appointment_follows).
-- Supabase "WHERE koşulu yok" diye onay isteyebilir: bu beklenen davranıştır, çünkü tüm tablo temizleniyor.
-- =====================================================================
select source, count(*) as ilan_sayisi
from public.appointments
group by source
order by ilan_sayisi desc;                       -- silmeden önceki durum

delete from public.appointments;

select count(*) as kalan from public.appointments;  -- 0 olmalı
