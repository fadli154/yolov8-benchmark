# PROJECT CONTEXT UPDATE

Nama Proyek: Waste Detection Mobile App

Tujuan:
Aplikasi Flutter untuk mendeteksi sampah secara real-time menggunakan model YOLOv8 TFLite (YOLOv8n dan YOLOv8s) dengan fitur benchmark untuk penelitian/jurnal yang membandingkan performa kedua model.

Tech Stack:

* Flutter 3.x
* Dart 3.x
* GetX (state management + navigation)
* Camera package
* Flutter Vision
* Flutter TTS
* TFLite YOLOv8
* fl_chart (visualisasi benchmark)
* Shared Preferences / GetStorage

Fitur Saat Ini:
✓ Real-time object detection menggunakan kamera.
✓ Mendukung 2 model:

* YOLOv8n (Nano)
* YOLOv8s (Small)
  ✓ Switch model saat aplikasi berjalan.
  ✓ Voice feedback menggunakan TTS.
  ✓ Benchmark:
* FPS
* Latency
* RAM Usage
* Jumlah objek terdeteksi
* Ukuran model
  ✓ Overlay bounding box.
  ✓ Glassmorphism UI.

Masalah Saat Ini:

1. Aplikasi sangat berat saat deteksi berlangsung.
2. Switching model sering menyebabkan force close/crash.
3. Keluar dari halaman deteksi terkadang freeze.
4. Glass card expand/collapse kadang berubah sendiri tau kebuka tutup sendiri.
5. FPS rendah dan UI lag.
6. Memory usage tinggi.
7. Benchmark untuk jurnal masih kurang detail, tambahkan detail detail yang berguna untuk perbandingan antar model.
8. Arsitektur kode masih monolithic (DetectionPage terlalu besar >1000 baris).

Target Perbaikan:

1. Stabil tanpa crash.
2. Switching model lancar.
3. Performa lebih ringan.
4. Menggunakan best practice Flutter.
5. Benchmark lebih lengkap untuk kebutuhan jurnal.
6. UI tetap modern namun efisien.
7. saat close page detection_page.dart appnya tidak freeze dan camera langsung terclose secara lancar