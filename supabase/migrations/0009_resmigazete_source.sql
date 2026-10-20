-- =====================================================================
-- 0009: Resmî Gazete "İlan Bölümü" kaynağı
--   resmigazete : resmigazete.gov.tr ilan bölümündeki kamu personel alım ilanları
-- Bot bu değeri yazmadan ÖNCE bu dosya çalıştırılmalı; yoksa "invalid input value
-- for enum appointment_source" hatası verir.
-- =====================================================================
alter type appointment_source add value if not exists 'resmigazete';
