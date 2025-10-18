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

Jika ingin menambahkan informasi booth, silakan update `config/override.json` override di repository [https://github.com/mentegago/cf21-map-config](https://github.com/mentegago/cf21-map-config)

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

