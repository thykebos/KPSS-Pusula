-- =====================================================================
-- 0008: Kariyer Kapısı "İş e-Alım" HTML kaynağı
--   kariyerkapisi_isealim : kariyerkapisi.gov.tr/isealim
-- Bot bu değeri yazmadan ÖNCE bu dosya çalıştırılmalı; yoksa "invalid input value
-- for enum appointment_source" hatası verir.
-- =====================================================================
alter type appointment_source add value if not exists 'kariyerkapisi_isealim';
