-- =====================================================================
-- ÖRNEK SORULAR (yalnızca Matik modülünü denemek için, 6 soru)
-- Çalıştırma: 0001 ve 0002 migration'dan SONRA, Supabase SQL Editor'de.
-- Tekrar çalıştırmak güvenlidir: aynı soru metni varsa eklenmez.
-- Gerçek içeriği kendi soru bankanla değiştir; bu sorular örnek amaçlıdır.
-- =====================================================================

create or replace function pg_temp.add_q(
  p_subject  subject_type,
  p_topic    text,
  p_body     text,
  p_hint     text,
  p_mnemonic text,
  p_general  text,
  p_options  jsonb
) returns void language plpgsql as $$
declare
  v_id uuid;
  o    jsonb;
begin
  if exists (select 1 from public.questions where body = p_body) then
    return;
  end if;

  insert into public.questions (subject, topic, body, hint, mnemonic, general_explanation)
  values (p_subject, p_topic, p_body, p_hint, p_mnemonic, p_general)
  returning id into v_id;

  for o in select * from jsonb_array_elements(p_options) loop
    insert into public.question_options (question_id, label, body, is_correct, explanation)
    values (v_id, o ->> 'label', o ->> 'body', (o ->> 'is_correct')::boolean, o ->> 'explanation');
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 1) TARİH
-- ---------------------------------------------------------------------
select pg_temp.add_q(
  'tarih',
  $q$Kurtuluş Savaşı$q$,
  $q$Türkiye Büyük Millet Meclisi hangi tarihte Ankara'da açılmıştır?$q$,
  $q$Bu tarih bugün ulusal bir bayram olarak kutlanıyor.$q$,
  $q$23 Nisan: Meclis doğdu, bayramı çocuklara armağan edildi. "Meclis'in doğum günü = Çocuk Bayramı."$q$,
  $q$TBMM, 23 Nisan 1920'de Ankara'da açılmış ve Mustafa Kemal Meclis Başkanı seçilmiştir. Millî egemenlik ilkesinin fiilen başladığı tarih olarak kabul edilir.$q$,
  $j$[
    {"label":"A","body":"19 Mayıs 1919","is_correct":false,
     "explanation":"Mustafa Kemal'in Samsun'a çıkışı ve Millî Mücadele'nin başlangıcıdır. Meclis bu tarihte açılmamıştır."},
    {"label":"B","body":"23 Nisan 1920","is_correct":true,
     "explanation":"Doğru. TBMM bu tarihte Ankara'da açılmıştır."},
    {"label":"C","body":"29 Ekim 1923","is_correct":false,
     "explanation":"Cumhuriyet'in ilan edildiği tarihtir. Meclis bundan yaklaşık üç buçuk yıl önce açılmıştır."},
    {"label":"D","body":"30 Ağustos 1922","is_correct":false,
     "explanation":"Büyük Taarruz'un son aşaması olan Başkomutanlık Meydan Muharebesi'nin kazanıldığı gündür (Zafer Bayramı)."},
    {"label":"E","body":"4 Eylül 1919","is_correct":false,
     "explanation":"Sivas Kongresi'nin toplandığı tarihtir. Kongre, Meclis'in açılışından önce yapılmıştır."}
  ]$j$::jsonb
);

select pg_temp.add_q(
  'tarih',
  $q$İlk Türk-İslam Devletleri$q$,
  $q$Aşağıdaki savaşlardan hangisi Anadolu'nun kapılarını Türklere açmıştır?$q$,
  $q$Savaşın tarihi 1071'dir; Alparslan ile Bizans İmparatoru karşı karşıya gelmiştir.$q$,
  $q$Malazgirt = 1071: Alparslan Anadolu'nun kapısını açtı. "On-yetmişbir, kapı açıldı."$q$,
  $q$Malazgirt Meydan Muharebesi (26 Ağustos 1071), Büyük Selçuklu Sultanı Alparslan ile Bizans İmparatoru Romen Diyojen arasında yapılmış; Türklerin Anadolu'ya yerleşmesinin önü açılmıştır.$q$,
  $j$[
    {"label":"A","body":"Dandanakan Savaşı","is_correct":false,
     "explanation":"1040'ta Selçuklular ile Gazneliler arasında yapılmıştır. Büyük Selçuklu Devleti'nin kuruluşunu sağlayan savaştır, Anadolu'yla ilgisi yoktur."},
    {"label":"B","body":"Malazgirt Savaşı","is_correct":true,
     "explanation":"Doğru. 1071'de Alparslan'ın Bizans'ı yenmesiyle Anadolu Türklere açılmıştır."},
    {"label":"C","body":"Miryokefalon Savaşı","is_correct":false,
     "explanation":"1176'da Anadolu Selçuklu Devleti'nin Bizans'ı yendiği savaştır. Anadolu'nun Türk yurdu olmasını pekiştirmiştir; kapıları açan savaş değildir, Malazgirt'ten sonradır."},
    {"label":"D","body":"Kösedağ Savaşı","is_correct":false,
     "explanation":"1243'te Moğollar Anadolu Selçuklularını yenmiştir. Selçuklu'nun zayıflamasına yol açmıştır, kapıları açan değil sonuç doğuran bir yenilgidir."},
    {"label":"E","body":"Pasinler Savaşı","is_correct":false,
     "explanation":"1048'de Selçuklu ve Bizans kuvvetleri arasında yapılmıştır. Anadolu'ya erken dönem akınlarından biridir; Anadolu'nun kapılarını açan savaş Malazgirt'tir."}
  ]$j$::jsonb
);

-- ---------------------------------------------------------------------
-- 2) COĞRAFYA
-- ---------------------------------------------------------------------
select pg_temp.add_q(
  'cografya',
  $q$Türkiye'nin Akarsuları$q$,
  $q$Türkiye'de doğup yine Türkiye sınırları içinde denize dökülen en uzun akarsu aşağıdakilerden hangisidir?$q$,
  $q$Karadeniz'e dökülür ve ağzında Bafra Deltası'nı oluşturur.$q$,
  $q$Kızılırmak: Sivas'tan doğar, Bafra Deltası'nda biter. "Kızıl toprağın nehri en uzun yolu yürür."$q$,
  $q$Kızılırmak yaklaşık 1355 km uzunluğuyla Türkiye sınırları içinde doğup denize dökülen en uzun akarsudur. Sivas'ta doğar, Bafra Deltası'nda (Samsun) Karadeniz'e ulaşır.$q$,
  $j$[
    {"label":"A","body":"Sakarya","is_correct":false,
     "explanation":"Karadeniz'e dökülür fakat Kızılırmak'tan kısadır."},
    {"label":"B","body":"Kızılırmak","is_correct":true,
     "explanation":"Doğru. Sınırlar içinde doğup denize dökülen en uzun akarsudur."},
    {"label":"C","body":"Yeşilırmak","is_correct":false,
     "explanation":"Karadeniz'e Çarşamba Deltası'ndan dökülür; Kızılırmak'tan çok daha kısadır."},
    {"label":"D","body":"Gediz","is_correct":false,
     "explanation":"Ege Denizi'ne dökülen bir akarsudur ve Kızılırmak'a göre oldukça kısadır."},
    {"label":"E","body":"Büyük Menderes","is_correct":false,
     "explanation":"Ege'ye dökülür ve Kızılırmak'tan kısadır. Menderesleriyle (kıvrımlarıyla) ünlüdür, uzunluğuyla değil."}
  ]$j$::jsonb
);

-- ---------------------------------------------------------------------
-- 3) VATANDAŞLIK
-- ---------------------------------------------------------------------
select pg_temp.add_q(
  'vatandaslik',
  $q$Anayasa - Seçimler$q$,
  $q$Anayasa'ya göre milletvekili seçilebilmek için en az kaç yaşını doldurmuş olmak gerekir?$q$,
  $q$Seçme yaşı ile seçilme yaşı bugün aynıdır.$q$,
  $q$Oy verme yaşı ile milletvekili olma yaşı eşit: 18 = 18. "Reşit olunca ikisi de açık."$q$,
  $q$2017 Anayasa değişikliğiyle milletvekili seçilme yaşı 25'ten 18'e indirilmiştir. Cumhurbaşkanı seçilebilmek için ise 40 yaşını doldurmuş olmak ve yükseköğrenim görmüş olmak gerekir.$q$,
  $j$[
    {"label":"A","body":"18","is_correct":true,
     "explanation":"Doğru. 2017 değişikliğinden bu yana milletvekili seçilme yaşı 18'dir."},
    {"label":"B","body":"21","is_correct":false,
     "explanation":"Milletvekilliği için Anayasa'da böyle bir yaş sınırı bulunmaz."},
    {"label":"C","body":"25","is_correct":false,
     "explanation":"2017 değişikliğinden önceki sınırdır. Güncel düzenlemede geçerli değildir."},
    {"label":"D","body":"30","is_correct":false,
     "explanation":"1982 Anayasası'nın ilk halindeki sınırdır. Sonradan düşürülmüştür."},
    {"label":"E","body":"40","is_correct":false,
     "explanation":"Cumhurbaşkanı seçilebilmek için aranan yaştır, milletvekili için değil."}
  ]$j$::jsonb
);

-- ---------------------------------------------------------------------
-- 4) MATEMATİK
-- ---------------------------------------------------------------------
select pg_temp.add_q(
  'matematik',
  $q$Ardışık Sayılar$q$,
  $q$Ardışık üç çift sayının toplamı 78 olduğuna göre bu sayıların en büyüğü kaçtır?$q$,
  $q$Ardışık sayılarda ortadaki sayı, toplamın sayı adedine bölümüdür.$q$,
  $q$Ortanca = toplam ÷ adet (78 ÷ 3 = 26). En büyük = ortanca + fark = 26 + 2 = 28.$q$,
  $q$Ardışık çift sayılar x-2, x, x+2 olarak yazılır. Toplamları 3x = 78 olduğundan x = 26, sayılar 24, 26, 28 olur.$q$,
  $j$[
    {"label":"A","body":"24","is_correct":false,
     "explanation":"En küçük sayıdır. Sayılar 24, 26, 28 olduğundan 24 en büyük değildir."},
    {"label":"B","body":"26","is_correct":false,
     "explanation":"Ortadaki sayıdır. Toplamın 3'e bölümü ortanca terimi verir, en büyüğü değil."},
    {"label":"C","body":"28","is_correct":true,
     "explanation":"Doğru. 24 + 26 + 28 = 78 ve en büyüğü 28'dir."},
    {"label":"D","body":"30","is_correct":false,
     "explanation":"En büyük 30 olsaydı sayılar 26, 28, 30 olurdu ve toplam 84 çıkardı."},
    {"label":"E","body":"32","is_correct":false,
     "explanation":"En büyük 32 olsaydı sayılar 28, 30, 32 olurdu ve toplam 90 çıkardı."}
  ]$j$::jsonb
);

-- ---------------------------------------------------------------------
-- 5) TÜRKÇE
-- ---------------------------------------------------------------------
select pg_temp.add_q(
  'turkce',
  $q$Yazım Kuralları$q$,
  $q$Aşağıdaki sözcüklerden hangisinin yazımı yanlıştır?$q$,
  $q$Yanlış yazılan sözcükte harflerin sırası "yanlış" sözcüğüyle karışmıştır.$q$,
  $q$Yalnız: önce L, sonra N. Yanlış: önce N, sonra L. "YaLNız ≠ YaNLış."$q$,
  $q$Doğru yazım "yalnız"dır; "yanlız" biçimi yanlıştır. "Yanlış" sözcüğüyle karıştırıldığı için sık yapılan bir hatadır.$q$,
  $j$[
    {"label":"A","body":"Herkes","is_correct":false,
     "explanation":"Doğru yazılmıştır. Yanlış biçimi \"herkez\"dir."},
    {"label":"B","body":"Yanlız","is_correct":true,
     "explanation":"Yazımı yanlıştır. Doğrusu \"yalnız\"dır."},
    {"label":"C","body":"Şoför","is_correct":false,
     "explanation":"Doğru yazılmıştır. Türk Dil Kurumu yazımı \"şoför\"dür."},
    {"label":"D","body":"Pazartesi","is_correct":false,
     "explanation":"Doğru yazılmıştır. Tek sözcük olarak ve bitişik yazılır."},
    {"label":"E","body":"Kırgın","is_correct":false,
     "explanation":"Doğru yazılmıştır; yazım yanlışı içermez."}
  ]$j$::jsonb
);

-- Kontrol: 6 soru ve her birinde tam 5 şık, 1 doğru olmalı.
select q.subject, left(q.body, 50) as soru, count(o.*) as sik_sayisi,
       count(*) filter (where o.is_correct) as dogru_sayisi
from public.questions q
join public.question_options o on o.question_id = q.id
group by q.id, q.subject, q.body
order by q.subject;
