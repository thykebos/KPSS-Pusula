# Ürün Bağlamı

## Neden Var
KPSS adayları, hem sınava çalışmak hem de dağınık sitelerde (Kariyer Kapısı, ilan.gov.tr, belediyeler, üniversiteler, Resmî Gazete) yayımlanan kamu alım ilanlarını elle takip etmek zorunda. Uygulama bunları tek yerde toplar ve kişinin eğitim seviyesine/mesleğine göre süzer.

## Nasıl Çalışmalı
- Kullanıcı kayıt olur, eğitim seviyesini seçer. Ana ekranda sınava kalan günü ve günlük çözdüğü soru sayısını görür.
- Matik'te ders seçip soru çözer; ücretsiz kullanıcının günlük kotası vardır, Premium kotasızdır.
- Atamalar ekranı yalnızca süresi dolmamış ilanları gösterir. Bot çalışmasa bile süresi biten ilan listeden hemen kaybolur (sunucu filtreler), ayrıca veritabanından da silinir.
- Premium kullanıcı ilanları filtreler, takip eder; yeni uygun ilan çıkınca push bildirim alır (sunucu tarafı yazıldı, istemci tarafı henüz yok).

## Kullanıcı Deneyimi Hedefleri
- Türkçe, sade, hızlı. Şehir seçimi 81 ilden aranabilir listeyle yapılır (serbest metin değil).
- İlan detayında iki net eylem: "Bağlantıya Git" (dış tarayıcı) ve "Bağlantıyı Kopyala".
- Yanlış/eski ilan göstermemek, ilan sayısını şişirmemekten önemlidir (ilan şüpheliyse sadeleştirme yerine güncellik süzgeci uygulanır).
