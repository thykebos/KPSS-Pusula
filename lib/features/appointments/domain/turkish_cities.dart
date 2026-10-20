/// 81 il, Türkçe alfabe sırasıyla.
///
/// Yazımlar botun şehir listesiyle (scraper/text_utils.py -> `_CITIES`) BİREBİR aynıdır; ilanın `city` alanına
/// bot bu adlardan birini yazar ve sunucu (`get_appointments`, 0010) şehri bu adla TAM eşleştirir.
/// Listeyi elle değiştirme: bota il eklenirse/değişirse burayı da aynı şekilde güncelle.
const List<String> turkishCities = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı',
  'Aksaray', 'Amasya', 'Ankara', 'Antalya',
  'Ardahan', 'Artvin', 'Aydın', 'Balıkesir',
  'Bartın', 'Batman', 'Bayburt', 'Bilecik',
  'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
  'Bursa', 'Çanakkale', 'Çankırı', 'Çorum',
  'Denizli', 'Diyarbakır', 'Düzce', 'Edirne',
  'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir',
  'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari',
  'Hatay', 'Iğdır', 'Isparta', 'İstanbul',
  'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman',
  'Kars', 'Kastamonu', 'Kayseri', 'Kırıkkale',
  'Kırklareli', 'Kırşehir', 'Kilis', 'Kocaeli',
  'Konya', 'Kütahya', 'Malatya', 'Manisa',
  'Mardin', 'Mersin', 'Muğla', 'Muş',
  'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye',
  'Rize', 'Sakarya', 'Samsun', 'Siirt',
  'Sinop', 'Sivas', 'Şanlıurfa', 'Şırnak',
  'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli',
  'Uşak', 'Van', 'Yalova', 'Yozgat',
  'Zonguldak',
];

/// Türkçe harfleri sadeleştirip küçültür ("İstanbul" -> "istanbul", "Muş" -> "mus").
/// Aramada "izmir" yazınca "İzmir"in, "mus" yazınca "Muş"un bulunması için. (Dart'ın toLowerCase()'i "İ" harfini
/// "i" + birleştirici nokta yaptığından kendi eşlememizi kullanıyoruz.) Sunucudaki `tr_fold` ile aynı mantık.
String foldTr(String input) {
  const map = <String, String>{
    'İ': 'i', 'I': 'i', 'ı': 'i',
    'Ş': 's', 'ş': 's',
    'Ğ': 'g', 'ğ': 'g',
    'Ü': 'u', 'ü': 'u',
    'Ö': 'o', 'ö': 'o',
    'Ç': 'c', 'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final ch in input.split('')) {
    buffer.write(map[ch] ?? ch.toLowerCase());
  }
  return buffer.toString();
}
