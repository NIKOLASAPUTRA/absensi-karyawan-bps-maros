# Perubahan Sistem Absensi Terpadu BPS Kabupaten Maros

## Yang diubah
- `src/App.jsx`: halaman pilihan layanan dan satu formulir yang dipakai oleh kategori `pelayanan`, `resepsionis`, dan `ppid`.
- `src/styles.css`: gaya responsif dengan identitas visual BPS dan aksen berbeda per layanan.
- `supabase/migrations/20261030_attendance_categories.sql`: migrasi untuk kolom kategori dan RPC tujuh parameter, dengan wrapper RPC enam parameter lama.

## Urutan penerapan
1. Cadangkan database Supabase sebelum migrasi.
2. Buka Supabase SQL Editor dan jalankan seluruh isi `supabase/migrations/20261030_attendance_categories.sql`.
3. Pastikan migrasi berhasil, lalu deploy frontend yang diperbarui.
4. Pastikan variabel `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY` yang sudah digunakan project tetap tersedia di `.env.local` / pengaturan environment deployment. Jangan masukkan service-role key ke frontend.
5. Uji ketiga kategori dengan data uji yang disetujui. Verifikasi `attendance_category` pada `public.service_attendance`.

## Catatan kompatibilitas dan cakupan
- Baris lama di `public.service_attendance` dipertahankan; kategori kosong diisi `pelayanan`.
- RPC lama enam parameter dipertahankan sebagai wrapper yang menyimpan kategori `pelayanan`.
- Batasan satu absensi per pegawai per tanggal, validasi status, validasi tanggal (kemarin atau hari ini), validasi waktu, serta pemeriksaan pegawai aktif tetap dipertahankan.
- ZIP sumber yang diterima hanya berisi formulir publik di `src/App.jsx`; tidak ada halaman/dashboard admin atau kode rekap admin pada project ini. Karena itu filter kategori di dashboard admin tidak dapat ditambahkan dengan aman tanpa file halaman admin yang sebenarnya. Data rekap dapat difilter berdasarkan kolom `attendance_category` setelah kolom ini diterapkan.
- Migrasi ini tidak mengubah konfigurasi RLS tabel absensi, tidak menghapus tabel, dan tidak mengubah autentikasi admin.

## Query verifikasi setelah migrasi
```sql
select attendance_category, count(*) as total
from public.service_attendance
group by attendance_category
order by attendance_category;

select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'service_attendance'
  and column_name = 'attendance_category';
```
