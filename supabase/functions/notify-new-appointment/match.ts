// Bildirim eşleştirme mantığı (saf fonksiyonlar; Deno ve Node'da test edilebilir).
// Kural: seviye uyuşmalı. Kullanıcı meslek etiketi eklediyse yalnızca o mesleklerle
// eşleşen ilanlarda bildirim alır; hiç etiketi yoksa seviyesine uyan tüm ilanlarda alır.

export interface NotifyAppointment {
  title: string;
  institution: string;
  description?: string | null;
  education_levels: string[];
  departments: string[];
}

export interface NotifyUser {
  education_level: string;
  followed_professions: string[] | null;
}

/** Türkçe harf ve büyük/küçük harf duyarsız karşılaştırma için sadeleştirir (SQL tr_fold ile aynı). */
export function foldTr(text: string | null | undefined): string {
  const map: Record<string, string> = {
    'İ': 'i', 'I': 'i', 'ı': 'i', 'Ş': 's', 'ş': 's', 'Ğ': 'g', 'ğ': 'g',
    'Ü': 'u', 'ü': 'u', 'Ö': 'o', 'ö': 'o', 'Ç': 'c', 'ç': 'c',
  };
  let out = '';
  for (const ch of text ?? '') out += map[ch] ?? ch;
  return out.toLowerCase();
}

export function professionMatches(professions: string[], a: NotifyAppointment): boolean {
  const hay = foldTr([a.title, a.description ?? '', a.institution, a.departments.join(' ')].join(' '));
  return professions.some((p) => {
    const needle = foldTr(p.trim());
    return needle.length >= 2 && hay.includes(needle);
  });
}

export function shouldNotify(user: NotifyUser, a: NotifyAppointment): boolean {
  const levelOk = a.education_levels.length === 0 || a.education_levels.includes(user.education_level);
  if (!levelOk) return false;
  const profs = (user.followed_professions ?? []).filter((p) => p.trim().length >= 2);
  return profs.length === 0 || professionMatches(profs, a);
}
