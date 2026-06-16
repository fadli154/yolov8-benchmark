# PROJECT_CONTEXT.md

# Smart Waste Detector Benchmark (Flutter + TensorFlow Lite)

## Project Overview

Buat sebuah aplikasi Android menggunakan Flutter dan Dart yang dapat melakukan **deteksi sampah secara real-time menggunakan kamera belakang** dengan model **YOLOv8 TensorFlow Lite**.

Aplikasi ini digunakan untuk **membandingkan performa YOLOv8n dan YOLOv8s** pada perangkat Android secara langsung.

Aplikasi harus production-ready dan tidak menggunakan dummy data, simulation mode, mock detection, placeholder detection, maupun fake benchmark.

Semua hasil benchmark harus berasal dari inferensi model sebenarnya.

---

# Model

Model tersedia:

```
assets/models/best_yolov8n.tflite
assets/models/best_yolov8s.tflite
```

Label:

```
assets/models/labels.txt
```

Isi label:

```
kaca
kertas
logam
plastik
```

Gunakan model TensorFlow Lite secara langsung.

Jangan menggunakan API cloud.

Semua inferensi dilakukan secara offline di perangkat Android.

---

# Main Features

## Home Screen

Tampilkan:

Smart Waste Detector

Subtitle:

YOLOv8 Android Benchmark

Button:

* Test YOLOv8n
* Test YOLOv8s
* Compare Models

---

## Detection Screen

memencet floating button (icon video) -> masuk halaman deteksi:

* buka kamera belakang
* pilih model yang ingin di pakai antara nano atau small
* load model yang dipilih
* jalankan inferensi realtime
* tampilkan preview kamera fullscreen
* saat user close halaman deteksi sistem deteksi akan mati tanpa force close/crash

Deteksi harus berjalan terus menerus menggunakan camera stream.

---

## Bounding Box

Untuk setiap objek tampilkan:

* rectangle
* class label
* confidence (%)

Contoh:

```
Plastic 96%
Paper 92%
Glass 88%
Metal 95%
```

Bounding box wajib mengikuti posisi objek.

---

# Performance Overlay

Di pojok kiri atas tampilkan HUD transparan:

```
MODEL : YOLOv8n

FPS : 27.8

Latency : 36 ms

RAM : 164 MB

Objects : 3
```

Jika model Small:

```
MODEL : YOLOv8s

FPS : 18.2

Latency : 59 ms

RAM : 238 MB

Objects : 3
```

Semua nilai dihitung secara realtime.

---

# FPS Counter

Hitung FPS asli dari:

```
processed frame
-------------------
elapsed time
```

Jangan menggunakan angka statis.

Update setiap detik.

---

# Inference Time

Hitung:

```
start inference
↓

model.run()

↓

finish inference
```

Tampilkan dalam millisecond.

Contoh:

```
31 ms
47 ms
58 ms
```

---

# RAM Usage

Ambil memory usage aplikasi saat runtime.

Update realtime.

Tampilkan dalam MB.

---

# Detection Count

Hitung jumlah object yang lolos confidence threshold.

Misal:

Plastic
Glass
Paper

Total:

```
Objects : 3
```

---

# Confidence Threshold

Tambahkan slider:

```
0.25
0.50
0.75
```

Deteksi langsung berubah mengikuti threshold.

---

# Switch Model

Saat kamera aktif terdapat tombol:

```
Switch Model
```

Jika ditekan:

YOLOv8n

↓

YOLOv8s

↓

YOLOv8n

tanpa restart aplikasi.

Interpreter lama harus ditutup sebelum membuka interpreter baru.

---

# Compare Screen

Halaman Compare menampilkan:

| Metric           | YOLOv8n | YOLOv8s |
| ---------------- | ------- | ------- |
| Average FPS      | xx      | xx      |
| Average Latency  | xx      | xx      |
| RAM Usage        | xx      | xx      |
| Model Size       | xx      | xx      |
| Detected Objects | xx      | xx      |

Tambahkan kesimpulan otomatis:

Contoh:

```
YOLOv8n memiliki FPS lebih tinggi dan latency lebih rendah sehingga lebih cocok untuk Android kelas menengah.

YOLOv8s memiliki akurasi lebih baik namun membutuhkan resource lebih besar.
```

---

# TensorFlow Lite

Gunakan:

```
tflite_flutter
```

Jangan menggunakan flutter_vision.

Gunakan Interpreter TensorFlow Lite langsung.

---

# YOLO Decoder

Implementasikan decoder YOLOv8 TFLite lengkap:

* tensor parsing
* confidence extraction
* class probability
* bounding box decode
* scaling ke ukuran layar
* Non Maximum Suppression (NMS)

Harus kompatibel dengan model export Ultralytics YOLOv8 TFLite.

---

# Camera

Gunakan package camera.

Gunakan kamera belakang.

Streaming realtime.

Jangan freeze.

Inference asynchronous.

Jangan menjalankan inference bersamaan.

Gunakan mutex atau busy flag.

---

# UI

Material 3

Dark mode

Hijau sebagai accent color.

Gunakan glassmorphism untuk HUD benchmark.

---

# Error Handling

Jika model gagal load:

```
Failed to load model
```

Jika kamera gagal:

```
Camera initialization failed
```

Jika permission ditolak:

```
Camera permission required
```

---

# Performance

Target:

* 20+ FPS untuk YOLOv8n
* 12+ FPS untuk YOLOv8s

UI tetap smooth.

Tidak boleh lag.

---

# Project Structure

```
lib/

main.dart

pages/
    home_page.dart
    detection_page.dart
    compare_page.dart

services/
    detector_service.dart
    benchmark_service.dart
    camera_service.dart

widgets/
    bounding_box_painter.dart
    performance_hud.dart
    metric_card.dart

models/
    detection.dart
    benchmark.dart

assets/

models/
    best_yolov8n.tflite
    best_yolov8s.tflite
    labels.txt
```

---

# Final Output

Generate FULL Flutter project.

Tidak boleh ada:

* TODO
* placeholder
* simulation mode
* mock detection
* fake benchmark
* fake FPS
* fake RAM
* fake latency

Semua hasil harus berasal dari inferensi model TensorFlow Lite secara nyata di Android.

Project harus bisa dijalankan menggunakan:

```
flutter pub get

flutter run
```

tanpa perlu modifikasi tambahan.
