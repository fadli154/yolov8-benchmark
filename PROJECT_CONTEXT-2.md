# PROJECT_CONTEXT.md
# Smart Waste Detector Benchmark

## 1. Project Overview

Buat aplikasi Flutter Android bernama **Smart Waste Detector Benchmark**.

Aplikasi ini adalah **Android-based mobile benchmarking framework** untuk:
1. mendeteksi sampah secara real-time,
2. membandingkan performa **YOLOv8n** dan **YOLOv8s**,
3. menguji beberapa **inference backend / delegate**:
   - CPU
   - GPU delegate
   - NNAPI delegate,
4. melakukan benchmark statistik yang rapi dan dapat digunakan dalam jurnal ilmiah.

Aplikasi ini bukan sekadar demo deteksi.
Aplikasi ini adalah alat penelitian untuk benchmarking performa model TensorFlow Lite pada Android.

---

## 2. Tujuan Utama

### Tujuan fungsional
- Real-time waste detection berjalan dengan baik.
- Model YOLOv8n dan YOLOv8s bisa dipilih dan diuji.
- Backend CPU, GPU delegate, dan NNAPI delegate bisa dipilih.
- Benchmark dapat dijalankan dalam durasi menit, bukan hanya 30 detik.
- Hasil benchmark disimpan, diringkas, dan bisa diekspor.
- Performa tiap kombinasi model-backend dihitung dengan statistik yang benar.

### Tujuan ilmiah
- Menyediakan basis data benchmark yang bisa dipakai untuk jurnal IEEE.
- Menunjukkan trade-off antara akurasi deteksi dan efisiensi komputasi.
- Membandingkan model terbaik untuk Android real-time deployment.

---

## 3. Model yang Digunakan

Model tersedia dalam assets:

- `assets/models/best_yolov8n.tflite`
- `assets/models/best_yolov8s.tflite`
- `assets/models/labels.txt`

Label kelas:
- Glass
- Paper
- Metal
- Plastic

---

## 4. Inference Backend / Delegate

Aplikasi harus mendukung tiga backend:

1. **CPU backend**
2. **GPU delegate**
3. **NNAPI delegate**

Istilah yang dipakai di UI dan laporan:
- "Inference Backend"
- atau "Delegate"

Jangan menampilkan istilah teknis secara berantakan.
Buat nama yang jelas:
- CPU
- GPU Delegate
- NNAPI Delegate

Jika backend tidak tersedia di perangkat, tampilkan status yang jelas dan aman.

---

## 5. Benchmark Design

### Wajib ada repeated benchmark
Setiap kombinasi berikut harus bisa diuji beberapa kali:
- YOLOv8n + CPU
- YOLOv8n + GPU
- YOLOv8n + NNAPI
- YOLOv8s + CPU
- YOLOv8s + GPU
- YOLOv8s + NNAPI

### Wajib ada statistik
Untuk setiap kombinasi, hitung:
- mean
- standard deviation
- minimum
- maximum
- coefficient of variation jika memungkinkan

### Wajib ada multi-run
Minimum 5 run per kombinasi.

### Wajib ada durasi benchmark configurable
Benchmark dapat dijalankan dalam:
- 1 menit
- 3 menit
- 5 menit
atau durasi lain yang bisa diatur.

### Wajib ada warm-up
Sebelum pengukuran utama:
- jalankan warm-up frames
- jangan masukkan warm-up ke statistik final

---

## 6. Metrics to Track

Aplikasi harus mencatat metrik berikut:

### Performance Metrics
- Average FPS
- Minimum FPS
- Maximum FPS
- Average Latency (ms)
- Minimum Latency (ms)
- Maximum Latency (ms)
- Average RAM Usage (MB)
- Peak RAM Usage (MB)
- Model Size (MB)
- Average Detected Objects
- Detection Success Rate
- FPS Stability (%)
- Inference Count
- Session Duration
- Backend Used
- Model Used
- Run Index
- Timestamp

### Statistical Metrics
- Mean
- Standard Deviation
- Minimum
- Maximum
- Coefficient of Variation

---

## 7. UI/UX Requirements

### Masalah yang harus dihilangkan
- Jangan memaksa terlalu banyak field masuk ke satu tabel sempit.
- Jangan ada teks overflow.
- Jangan ada elemen yang keluar dari layar.
- Jangan ada layout yang terlalu padat.

### Solusi UI
Gunakan struktur berikut:

1. **Summary**
   - kartu ringkasan per model/backend
   - skor utama
   - highlight hasil benchmark

2. **Statistics**
   - mean ± std
   - perbandingan antar run
   - perbandingan antar backend

3. **Run History**
   - daftar run satu per satu
   - gunakan expandable card atau grouped card
   - jangan semua data dipaksa ke satu tabel

4. **Charts**
   - bar chart
   - line chart
   - radar chart bila perlu
   - pie chart bila relevan

5. **Export**
   - export ke CSV atau format lain yang rapi

### Tampilan yang diinginkan
- clean
- modern
- profesional
- cocok untuk screenshot jurnal
- tidak sempit
- tidak overflow
- tidak memaksa semua data tampil sekaligus

### Ketentuan teks
- Pakai ellipsis atau wrapping pada teks panjang
- Gunakan responsive layout
- Gunakan adaptive cards
- Gunakan scroll bila perlu, tetapi jangan membuat tampilan kacau

---

## 8. Benchmark History

Halaman history harus menampilkan hasil benchmark per run dengan rapi.

Setiap item history minimal memuat:
- model
- backend
- FPS
- latency
- RAM
- tanggal
- run index

Jika detail terlalu banyak, gunakan expandable card atau detail page.

Jangan memaksa semua data ke dalam satu tabel yang sempit.

---

## 9. Session Highlights

Halaman highlights harus menampilkan hasil utama secara ringkas.

Wajib memuat:
- model terbaik
- backend tercepat
- backend paling stabil
- model paling hemat RAM
- model dengan success rate terbaik

Pastikan semua teks muat di layar.
Tidak boleh overflow.
Gunakan layout yang responsif.

---

## 10. Detection and Benchmark Flow

### Detection flow
- buka kamera belakang
- load model
- pilih backend
- lakukan inferensi real-time
- tampilkan bounding box dan label

### Benchmark flow
- warm-up frames
- benchmark session berjalan selama durasi yang dipilih
- catat metrik per frame
- simpan run history
- hitung statistik akhir
- tampilkan hasil ringkasan
- export hasil benchmark

---

## 11. Statistical Analysis

Aplikasi harus menghitung statistik yang benar.

Untuk setiap kombinasi model-backend:
- hitung mean
- hitung standard deviation
- hitung min
- hitung max

Tampilkan hasil sebagai:
- `mean ± std`
atau
- nilai ringkasan yang rapi

Jika ada 5 run:
- tampilkan rata-rata dari 5 run
- tampilkan variasi antar run

Statistik ini sangat penting untuk kebutuhan jurnal ilmiah.

---

## 12. Backend Naming in Paper and UI

Gunakan istilah berikut:
- CPU backend
- GPU delegate
- NNAPI delegate

Jika perlu istilah yang lebih formal:
- CPU inference backend
- GPU-accelerated inference delegate
- NNAPI-accelerated inference delegate

Gunakan istilah ini secara konsisten di seluruh aplikasi.

---

## 13. File and Folder Structure

```txt
lib/
  main.dart
  app.dart
  pages/
    home_page.dart
    detection_page.dart
    benchmark_page.dart
    benchmark_history_page.dart
    comparison_page.dart
    export_page.dart
  services/
    detector_service.dart
    benchmark_service.dart
    model_manager.dart
    backend_manager.dart
    statistics_service.dart
    export_service.dart
  widgets/
    metric_card.dart
    benchmark_summary_card.dart
    benchmark_history_card.dart
    expandable_metric_card.dart
    performance_hud.dart
    comparison_chart.dart
    no_overflow_text.dart
  models/
    detection_result.dart
    benchmark_run.dart
    benchmark_summary.dart
    backend_type.dart
    model_type.dart
    statistics_result.dart
  utils/
    nms.dart
    yolo_decoder.dart
    memory_utils.dart
    time_utils.dart
assets/
  models/
    best_yolov8n.tflite
    best_yolov8s.tflite
    labels.txt

