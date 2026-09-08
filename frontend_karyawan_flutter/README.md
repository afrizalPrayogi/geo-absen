# Frontend Karyawan Flutter

Frontend mobile karyawan berdasarkan UI/UX yang sudah disepakati.

## Prasyarat

- Flutter SDK terinstall.
- Backend lokal berjalan di `http://localhost:3000` atau `http://10.0.2.2:3000` untuk Android emulator.

## Jalankan

Untuk Android emulator:

```bash
cd C:\Users\aprayogi\.cache\frontend_karyawan_flutter
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Untuk Flutter desktop/web di mesin yang sama:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Untuk HP fisik, ganti `API_BASE_URL` ke IP LAN komputer backend, contoh:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

## Akun Dummy

- Username: `budi`
- Password: `password`

## Catatan Platform

Project ini dibuat manual karena Flutter SDK belum tersedia di environment ini. Setelah Flutter tersedia, jalankan:

```bash
flutter create .
flutter pub get
```

Jika target Android/iOS, tambahkan permission platform untuk lokasi dan kamera/gallery sesuai package `geolocator` dan `image_picker`.
