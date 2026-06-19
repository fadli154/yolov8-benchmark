# 🗑️ Smart Waste Detector — YOLOv8 TFLite Mobile Benchmark 📱🤖

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![TensorFlow Lite](https://img.shields.io/badge/TFLite-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![YOLOv8](https://img.shields.io/badge/YOLOv8-Ultralytics-FF6F00?style=for-the-badge)](https://github.com/ultralytics/ultralytics)

Aplikasi Android berbasis **Flutter** yang dirancang untuk mendeteksi jenis sampah secara *real-time* menggunakan model kecerdasan buatan **YOLOv8 (TensorFlow Lite)**. 

Selain sebagai alat deteksi, aplikasi ini berfungsi sebagai **Platform Benchmarking** untuk mengukur performa deteksi objek (*Edge AI*) langsung pada perangkat ponsel pintar Anda. Anda dapat membandingkan latensi, FPS (*Frames Per Second*), penggunaan RAM, dan stabilitas model dalam berbagai konfigurasi akselerasi *hardware*.

---

## 🎯 Kelas Sampah yang Dapat Dideteksi
Model AI di dalam aplikasi ini telah dilatih secara khusus untuk mengenali **4 kategori sampah utama**:
1. 🍶 **Kaca** (Botol kaca, gelas, cermin)
2. 📰 **Kertas** (Kardus, kertas bekas, koran)
3. 🥫 **Logam** (Kaleng minuman, sendok, logam bekas)
4. 🥤 **Plastik** (Botol plastik, kantong plastik, gelas plastik)

---

## 🚀 Fitur Utama

### 1. Deteksi Real-Time (*On-Device AI*)
*   **Tanpa Internet**: Proses deteksi dilakukan 100% secara lokal di dalam ponsel (*Edge AI*). Data kamera tidak dikirim ke server mana pun, menjamin privasi dan kecepatan maksimal.
*   **Pilihan Model**:
    *   **YOLOv8 Nano (`yolov8n`)**: Sangat ringan (~5.9 MB), sangat cepat, cocok untuk handphone kelas menengah (*mid-range*).
    *   **YOLOv8 Small (`yolov8s`)**: Lebih akurat (~21.4 MB), membutuhkan komputasi lebih tinggi, direkomendasikan untuk handphone kelas atas (*flagship*).

### 2. Pengukuran Performa (Benchmarking Suite)
*   **Metrik Lengkap**: Mengukur kecepatan inferensi (*latency* dalam milidetik), FPS (*Frames Per Second*), penggunaan RAM (MB), serta jumlah objek terdeteksi.
*   **Fase Warm-up**: Secara otomatis mengecualikan beberapa frame awal untuk memastikan hasil pengukuran yang adil dan stabil.
*   **Stabilitas FPS**: Menganalisis variansi performa sepanjang pengujian.

### 3. Akselerasi Perangkat Keras (*Hardware Delegates*)
Anda dapat mengubah jenis pemrosesan secara dinamis saat aplikasi berjalan:
*   **CPU**: Menggunakan core prosesor standar (aman untuk semua perangkat).
*   **GPU Delegate**: Memanfaatkan kartu grafis ponsel untuk mempercepat kalkulasi AI secara signifikan.
*   **NNAPI Delegate**: Memanfaatkan chip khusus AI (*Neural Processing Unit*) pada perangkat Android modern.

### 4. Asisten Suara (*Text-to-Speech*)
*   Aplikasi dilengkapi dengan fitur suara (TTS) yang otomatis menyebutkan jenis sampah yang terdeteksi untuk membantu edukasi interaktif.

### 5. Ekspor & Berbagi Laporan
*   **Laporan PDF**: Menghasilkan dokumen laporan profesional lengkap dengan tabel statistik ringkasan (rata-rata ± standar deviasi), riwayat sesi, dan grafik analisis.
*   **Ekspor CSV**: Menyimpan data mentah per frame ke dalam format tabel `.csv` untuk dianalisis lebih lanjut menggunakan Excel atau Python.

---

## 🛠️ Library & Dependensi yang Digunakan

Aplikasi ini dibangun menggunakan pustaka-pustaka *open-source* terbaik untuk ekosistem Flutter:

| Nama Library | Kegunaan Utama | Penjelasan Sederhana untuk Orang Awam |
| :--- | :--- | :--- |
| **`flutter_vision`** | Deteksi YOLOv8 TFLite | Jembatan yang menjalankan model AI YOLOv8 (.tflite) langsung di sistem Android. |
| **`camera`** | Akses Kamera Fisik | Mengontrol kamera handphone untuk menangkap aliran gambar secara *real-time* per frame. |
| **`get` (GetX)** | State & Navigation | Mengatur perpindahan halaman (routing) dan membagi logika bisnis dengan tampilan aplikasi. |
| **`hive` & `hive_flutter`** | Database Lokal | Database lokal yang sangat cepat untuk menyimpan riwayat hasil benchmark secara *offline*. |
| **`get_storage`** | Penyimpanan Sederhana | Digunakan untuk menyimpan preferensi aplikasi dan migrasi data awal. |
| **`flutter_tts`** | Suara Text-to-Speech | Mengubah teks (misal: "Plastik") menjadi suara ucapan manusia melalui speaker ponsel. |
| **`fl_chart`** | Grafik Interaktif | Menampilkan diagram performa latensi dan FPS agar mudah dibaca oleh pengguna. |
| **`pdf` & `printing`** | Pembuatan PDF & Print | Membuat desain dokumen laporan benchmark dan mengirimkannya ke printer atau menyimpannya. |
| **`csv`** | Format Data Tabel | Memformat rekaman data mentah benchmark menjadi teks CSV yang kompatibel dengan Excel. |
| **`share_plus`** | Berbagi File | Memunculkan menu *Share* bawaan handphone untuk mengirim file PDF/CSV ke WhatsApp, Email, atau Google Drive. |
| **`permission_handler`** | Manajemen Izin | Meminta izin akses Kamera dan Storage ke sistem operasi Android secara aman. |
| **`google_fonts`** | Tipografi Antarmuka | Memuat font modern (seperti *Inter* & *Outfit*) agar tampilan aplikasi tampak premium. |

---

## 📋 Persyaratan Sistem

Sebelum memulai instalasi, pastikan komputer dan perangkat Anda memenuhi syarat berikut:

*   **Flutter SDK**: Versi `3.10.8` atau yang lebih baru.
*   **Dart SDK**: Versi `^3.10.8`.
*   **Java Development Kit (JDK)**: Versi 11 atau 17.
*   **Android Studio**: Diperlukan untuk instalasi SDK Android dan *toolchain* Gradle.
*   **Handphone Android Fisik**: 
    > [!IMPORTANT]
    > **Sangat direkomendasikan menggunakan HP Android fisik** dan bukan emulator. Emulator Android tidak mendukung akses GPU Delegate/NNAPI secara optimal dan performa kamera akan sangat lambat.

---

## ⚙️ Panduan Instalasi (Langkah Demi Langkah)

Bagi pemula, ikuti langkah-langkah di bawah ini untuk memasang projek di komputer Anda:

### Langkah 1: Clone Repository
Buka Terminal (Mac/Linux) atau Command Prompt/PowerShell (Windows), lalu jalankan perintah berikut untuk mengunduh kode projek:
```bash
git clone <url-repository-anda>
cd waste_detection
```

### Langkah 2: Verifikasi Flutter SDK
Pastikan Flutter sudah terinstal dengan benar di komputer Anda dengan mengetik:
```bash
flutter doctor
```
*Pastikan bagian **Flutter** dan **Android toolchain** sudah tercentang hijau.*

### Langkah 3: Unduh Dependensi/Library
Unduh semua library yang terdaftar di dalam `pubspec.yaml` dengan perintah:
```bash
flutter pub get
```

### Langkah 4: Hubungkan Handphone Android Anda
1. Aktifkan **Developer Options** (Opsi Pengembang) di HP Android Anda.
2. Aktifkan **USB Debugging**.
3. Hubungkan HP Android ke komputer menggunakan kabel data USB.
4. Ketik perintah berikut untuk memastikan HP Anda terdeteksi:
   ```bash
   flutter devices
   ```
   *Nama perangkat HP Anda harus muncul di daftar terminal.*

---

## 🚀 Cara Menjalankan Program

### Mode Pengembangan (Debug Mode)
Untuk menjalankan aplikasi langsung ke perangkat yang terhubung dengan mode pemantauan log *debug*:
```bash
flutter run
```
*Tunggu proses kompilasi Gradle selesai. Aplikasi akan terbuka otomatis di handphone Anda.*

### Mode Pengujian Performa (Profile Mode)
> [!TIP]
> **Penting untuk Benchmarking!**
> Untuk mendapatkan hasil pengukuran FPS dan RAM yang akurat sesuai performa asli ponsel, jalankan aplikasi menggunakan **Profile Mode**. Mode debug biasa memiliki *overhead* debugging yang membuat aplikasi terasa lebih lambat.

Jalankan dengan perintah:
```bash
flutter run --profile
```

### Membuat File APK untuk Instalasi Mandiri
Jika Anda ingin membuat file mentahan aplikasi (`.apk`) untuk dibagikan atau diinstal langsung di handphone tanpa komputer:
```bash
flutter build apk --release
```
*File APK yang dihasilkan akan berada di folder:*
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📂 Struktur Direktori Projek

Aplikasi ini menggunakan struktur folder terorganisir untuk memisahkan fitur deteksi dengan halaman statistik utama:

```text
lib/
├── main.dart                  # Titik masuk utama aplikasi (Inisialisasi Hive, GetStorage, Tema)
├── models/                    # Struktur data (Model data benchmark & hasil run)
├── pages/                     # Tampilan halaman utama non-deteksi
│   ├── home_page.dart         # Menu utama (Pilihan model deteksi & tombol benchmark)
│   ├── benchmark_page.dart    # Halaman proses pengetesan benchmark terpantau waktu
│   └── compare_page.dart      # Visualisasi grafik perbandingan performa antar model/backend
├── services/                  # Layanan utilitas umum
│   └── statistics_service.dart# Perhitungan statistik (Mencari rata-rata, standar deviasi, dll.)
├── widgets/                   # Komponen visual yang bisa digunakan berulang kali
└── features/
    └── detection/             # Modul khusus pengolah kecerdasan buatan & kamera
        ├── controllers/       # Logika bisnis deteksi dan benchmark pasif
        ├── pages/             # Tampilan kamera deteksi real-time
        ├── services/          # Pengolah AI (YoloService, CameraService, TtsService)
        └── widgets/           # Overlay kotak pembatas (Bounding Box) dan HUD data
```

---

## 🤝 Kontribusi
Jika Anda ingin mengembangkan aplikasi ini lebih lanjut (misalnya menambah model deteksi baru atau meningkatkan UI):
1. Lakukan *Fork* pada projek ini.
2. Buat *branch* fitur baru Anda (`git checkout -b fitur/baru-keren`).
3. Lakukan *Commit* perubahan Anda (`git commit -m 'Menambahkan fitur baru'`).
4. *Push* ke branch tersebut (`git push origin fitur/baru-keren`).
5. Buat *Pull Request* baru di GitHub.

---

## 📝 Lisensi
Projek ini dilisensikan di bawah **MIT License** - bebas digunakan untuk keperluan edukasi dan pengembangan pribadi.
