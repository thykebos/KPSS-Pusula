-- =====================================================================
-- 0007: Yeni ilan kaynakları
--   ilan_gov : ilan.gov.tr (Basın İlan Kurumu) "Personel Alımı ve İş İlanları"
--   sayistay    : sayistay.gov.tr duyuruları
--   iskur_esube : esube.iskur.gov.tr açık iş ilanları (yalnızca kamu alımları)
-- Bot bu değerleri yazmadan ÖNCE bu dosya çalıştırılmalı; yoksa ilgili kaynak "invalid input value
-- for enum appointment_source" hatası verir.
-- =====================================================================
alter type appointment_source add value if not exists 'ilan_gov';
alter type appointment_source add value if not exists 'sayistay';
alter type appointment_source add value if not exists 'iskur_esube';
