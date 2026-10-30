import { useEffect, useMemo, useState } from 'react';
import { supabase } from './lib/supabase';
import {
  ArrowLeft, ArrowRight, CalendarDays, Clock3, FileCheck2, FileText,
  Info, LoaderCircle, UsersRound, ConciergeBell, ShieldCheck, ChevronRight,
} from 'lucide-react';

const todayLocal = () => {
  const d = new Date();
  const offset = d.getTimezoneOffset();
  return new Date(d.getTime() - offset * 60000).toISOString().slice(0, 10);
};

const SERVICES = {
  pelayanan: {
    key: 'pelayanan', title: 'Absensi Petugas Pelayanan', short: 'Petugas Pelayanan',
    description: 'Pencatatan kehadiran petugas yang melaksanakan pelayanan kepada masyarakat.',
    icon: UsersRound, accent: '#1769bd', tint: '#eaf3ff',
  },
  resepsionis: {
    key: 'resepsionis', title: 'Absensi Resepsionis', short: 'Resepsionis',
    description: 'Pencatatan kehadiran petugas yang menerima, menyambut, dan mengarahkan pengunjung.',
    icon: ConciergeBell, accent: '#087f8c', tint: '#e6f7f7',
  },
  ppid: {
    key: 'ppid', title: 'Absensi Petugas PPID', short: 'Petugas PPID',
    description: 'Pencatatan kehadiran petugas yang menangani pelayanan informasi publik dan dokumentasi.',
    icon: FileText, accent: '#6554b5', tint: '#f0edff',
  },
};

function ServiceIcon({ category, size = 22 }) {
  const Icon = SERVICES[category]?.icon || FileCheck2;
  return <Icon size={size} aria-hidden="true" />;
}

export default function App() {
  const [category, setCategory] = useState(null);
  const [employees, setEmployees] = useState([]);
  const [loadingEmployees, setLoadingEmployees] = useState(true);
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState({ type: '', text: '' });
  const [form, setForm] = useState({
    attendance_date: todayLocal(), employee_id: '', attendance_status: 'hadir',
    start_time: '', end_time: '', notes: '',
  });

  const activeService = category ? SERVICES[category] : null;
  const selectedEmployee = useMemo(
    () => employees.find((employee) => String(employee.id) === String(form.employee_id)),
    [employees, form.employee_id]
  );

  useEffect(() => {
    let active = true;
    async function loadEmployees() {
      setLoadingEmployees(true);
      const { data, error } = await supabase.rpc('public_service_employee_list');
      if (!active) return;
      if (error) {
        setNotice({ type: 'error', text: 'Daftar pegawai belum dapat dimuat. Pastikan RPC daftar pegawai tersedia di Supabase.' });
      } else {
        setEmployees(data || []);
      }
      setLoadingEmployees(false);
    }
    loadEmployees();
    return () => { active = false; };
  }, []);

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }));
    setNotice({ type: '', text: '' });
  }

  function openService(key) {
    if (!SERVICES[key]) return;
    setCategory(key);
    setNotice({ type: '', text: '' });
  }

  async function submit(event) {
    event.preventDefault();
    setNotice({ type: '', text: '' });
    if (!category || !SERVICES[category]) {
      setNotice({ type: 'error', text: 'Pilih jenis layanan absensi terlebih dahulu.' });
      return;
    }
    if (!form.employee_id || !form.attendance_date || !form.attendance_status || !form.start_time || !form.end_time) {
      setNotice({ type: 'error', text: 'Mohon lengkapi nama pegawai, tanggal, status, jam mulai, dan jam selesai.' });
      return;
    }
    if (form.end_time <= form.start_time) {
      setNotice({ type: 'error', text: 'Jam selesai harus lebih akhir daripada jam mulai.' });
      return;
    }

    setSaving(true);
    const { error } = await supabase.rpc('submit_public_service_attendance', {
      p_employee_id: form.employee_id,
      p_attendance_date: form.attendance_date,
      p_status: form.attendance_status,
      p_start_time: form.start_time,
      p_end_time: form.end_time,
      p_notes: form.notes.trim() || null,
      p_attendance_category: category,
    });
    setSaving(false);

    if (error) {
      const message = error.message?.toLowerCase() || '';
      const duplicate = message.includes('duplicate') || message.includes('already') || message.includes('unique') || error.code === '23505';
      setNotice({
        type: 'error',
        text: duplicate
          ? 'Absensi untuk nama pegawai tersebut pada tanggal ini sudah tercatat. Satu pegawai hanya dapat memiliki satu absensi per tanggal.'
          : message.includes('kategori')
            ? 'Kategori absensi tidak valid. Muat ulang halaman dan coba kembali.'
            : 'Absensi belum berhasil disimpan. Pastikan migrasi SQL kategori sudah dijalankan di Supabase, lalu coba kembali.',
      });
      return;
    }

    setNotice({ type: 'success', text: `Absensi ${activeService.short.toLowerCase()} berhasil dicatat. Terima kasih.` });
    setForm((current) => ({ ...current, employee_id: '', attendance_status: 'hadir', start_time: '', end_time: '', notes: '' }));
  }

  return (
    <main className="attendance-page">
      <section className={`attendance-card ${activeService ? 'form-card' : 'home-card'}`} style={activeService ? { '--service-accent': activeService.accent, '--service-tint': activeService.tint } : undefined}>
        <header className="page-header">
          <div className="bps-mark" aria-hidden="true">BPS</div>
          <div className="header-copy">
            <p className="eyebrow">BADAN PUSAT STATISTIK</p>
            <h1>Sistem Absensi BPS Kabupaten Maros</h1>
            <p className="subtitle">BPS Kabupaten Maros</p>
          </div>
        </header>

        {!activeService ? (
          <>
            <div className="home-intro">
              <h2>Pilih Jenis Layanan Absensi</h2>
              <p>Pilih jenis layanan absensi sesuai dengan tugas Anda.</p>
            </div>
            <div className="service-grid">
              {Object.values(SERVICES).map((service) => (
                <article className="service-option" key={service.key} style={{ '--service-accent': service.accent, '--service-tint': service.tint }}>
                  <div className="service-icon"><service.icon size={25} /></div>
                  <h3>{service.title}</h3>
                  <p>{service.description}</p>
                  <button className="open-service" type="button" onClick={() => openService(service.key)}>
                    Buka Absensi <ChevronRight size={17} />
                  </button>
                </article>
              ))}
            </div>
          </>
        ) : (
          <>
            <button className="back-link" type="button" onClick={() => { setCategory(null); setNotice({ type: '', text: '' }); }}>
              <ArrowLeft size={17} /> Kembali ke Pilihan Absensi
            </button>
            <div className="intro service-intro">
              <div className="intro-icon"><ServiceIcon category={category} size={23} /></div>
              <div>
                <p className="service-kicker">LAYANAN ABSENSI</p>
                <h2>{activeService.title}</h2>
                <p>{activeService.description}</p>
                {category === 'ppid' && <small>PPID: Pejabat Pengelola Informasi dan Dokumentasi</small>}
              </div>
            </div>

            <nav className="service-switcher" aria-label="Pindah jenis absensi">
              {Object.values(SERVICES).filter((service) => service.key !== category).map((service) => (
                <button key={service.key} type="button" onClick={() => openService(service.key)}>
                  <ServiceIcon category={service.key} size={16} /> {service.short} <ArrowRight size={14} />
                </button>
              ))}
            </nav>

            {notice.text && <div className={`notice ${notice.type}`} role="status">{notice.type === 'success' ? '✓' : '!'} {notice.text}</div>}

            <form onSubmit={submit}>
              <div className="form-grid">
                <label className="field">
                  <span>Tanggal absensi</span>
                  <div className="input-wrap"><CalendarDays size={18} /><input type="date" value={form.attendance_date} onChange={(e) => update('attendance_date', e.target.value)} required /></div>
                </label>
                <label className="field">
                  <span>Nama pegawai</span>
                  <select value={form.employee_id} onChange={(e) => update('employee_id', e.target.value)} disabled={loadingEmployees || employees.length === 0} required>
                    <option value="">{loadingEmployees ? 'Memuat daftar pegawai...' : employees.length ? 'Pilih nama pegawai' : 'Daftar pegawai belum tersedia'}</option>
                    {employees.map((employee) => <option key={employee.id} value={employee.id}>{employee.full_name}</option>)}
                  </select>
                </label>
                <label className="field">
                  <span>NIP</span>
                  <input type="text" value={selectedEmployee?.nip || ''} placeholder="Terisi otomatis setelah nama dipilih" readOnly />
                  {!selectedEmployee && <small>NIP mengikuti data pegawai yang tersedia di Supabase.</small>}
                </label>
                <label className="field">
                  <span>Status kehadiran</span>
                  <select value={form.attendance_status} onChange={(e) => update('attendance_status', e.target.value)} required>
                    <option value="hadir">Hadir</option><option value="izin">Izin</option><option value="sakit">Sakit</option>
                  </select>
                </label>
                <label className="field">
                  <span>Jam mulai bertugas</span>
                  <div className="input-wrap"><Clock3 size={18} /><input type="time" value={form.start_time} onChange={(e) => update('start_time', e.target.value)} required /></div>
                </label>
                <label className="field">
                  <span>Jam selesai bertugas</span>
                  <div className="input-wrap"><Clock3 size={18} /><input type="time" value={form.end_time} onChange={(e) => update('end_time', e.target.value)} required /></div>
                </label>
                <label className="field full-width">
                  <span>Keterangan atau catatan <small>(opsional)</small></span>
                  <textarea rows="3" maxLength="500" value={form.notes} onChange={(e) => update('notes', e.target.value)} placeholder="Tambahkan keterangan jika diperlukan..." />
                </label>
              </div>
              <div className="privacy-note"><Info size={17} /><p>Pastikan nama pegawai dan waktu bertugas sudah benar. Data akan disimpan sebagai kategori <strong>{category}</strong>.</p></div>
              <button className="submit-button" type="submit" disabled={saving || loadingEmployees || employees.length === 0}>
                {saving ? <><LoaderCircle className="spin" size={18} /> Menyimpan...</> : 'KIRIM ABSENSI'}
              </button>
            </form>
          </>
        )}
        <footer className="page-footer">BPS Kabupaten Maros · Sistem Absensi Terpadu</footer>
      </section>
    </main>
  );
}
