# CF21 Booth Map

Aplikasi web untuk melihat peta booth creator di acara Comifuro 21 (CF21).

## Fitur

- 🗺️ **Peta Interaktif** - Lihat seluruh layout booth acara CF21
- 🔍 **Pencarian Creator** - Cari dan temukan booth creator favorit kamu
- 🔗 **Share Link** - Bagikan link langsung ke booth creator tertentu

## Cara Pakai

1. Buka website
2. Geser dan zoom untuk navigasi peta
3. Tap search bar di atas untuk cari creator
4. Pilih creator untuk lihat lokasi booth mereka
5. Tap booth di peta untuk lihat detail creator

## Menambahkan Informasi Booth

Jika ingin menambahkan informasi booth, data list booth ada di `data/creator-data.json`, dengan format sebagai berikut:

```json
{
"name": "Nama booth",
"booths": [
    "BOOTH-1",
    "BOOTH-2",
    "BOOTH-3",
    "BOOTH-4"
],
"day": "SAT/SUN/BOTH",
"profileImage": "assets/profilepicture.jpg",
"informations": [
    {
    "title": "Judul dari section informasinya",
    "content": "Isi dari sectionnya"
    },
    {
    "title": "Judul dari section informasinya",
    "content": "Isi dari sectionnya"
    }
],
"urls": [
    {
    "title": "Judul link 2",
    "url": "https://example.com"
    },
    {
    "title": "Judul link 2",
    "url": "https://example.com"
    }
]
}
```
*`profileImage`, `informations`, dan `urls` opsional.

Kalau ingin menambahkan profile picture, silakan tambahkan di folder `assets/` dan update JSON booth sesuai format di atas. Mohon minimalisir sizenya ya, kalau bisa under 5KB 🙇. Setelah itu, silakan submit PR.

## Build (Khusus buat developer)

App ini dibuat menggunakan Flutter.

```bash
# Install dependencies
flutter pub get

# Run di browser
flutter run -d chrome

# Build untuk production
flutter build web --release
```

## Kontribusi (Khusus buat developer)

Jika ingin kontribusi ke kodingan appnya (bug fixing, nambahin feature, dsb.), mohon dimaklumi, karena ini proyek iseng weekend, kodingannya sangat berantakan, jadi ga rekomen utak-atik kodingannya. Tapi kalau anda psikopat, silakan submit PR.

---

See you at CF21 💖

