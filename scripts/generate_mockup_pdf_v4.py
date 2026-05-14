from fpdf import FPDF

class PDF(FPDF):
    def header(self):
        self.set_font('helvetica', 'B', 15)
        self.cell(0, 10, 'MyPresensi - UI/UX Mockup v4 (Gaya Mekari Talenta + Biru TRPL)', align='C', new_x='LMARGIN', new_y='NEXT')
        self.set_line_width(0.5)
        self.line(10, 22, 200, 22)
        self.ln(10)
        
    def footer(self):
        self.set_y(-15)
        self.set_font('helvetica', 'I', 8)
        self.cell(0, 10, f'Page {self.page_no()}', align='C')

pdf = PDF()

# Mobile App Mockup
pdf.add_page()
pdf.set_font('helvetica', 'B', 14)
pdf.cell(0, 10, '1. Tampilan Aplikasi Mobile (Multi-Screen seperti Mekari Talenta)', new_x='LMARGIN', new_y='NEXT')
pdf.ln(2)

pdf.set_font('helvetica', '', 11)
pdf.multi_cell(0, 7, 'Desain mengadopsi DNA Mekari Talenta: tampilan multi-layar berdampingan, header Biru Baja TRPL (#5483AD), sistem kartu bersudut tumpul (16px border-radius) dengan drop-shadow halus, dan "white space" ekstensif. Menampilkan layar: (1) Dashboard Mahasiswa + Absen Sekarang, (2) Face Scan / Kamera, dan (3) Riwayat Absensi.')
pdf.ln(5)

mobile_img_path = r'C:\Users\riki\.gemini\antigravity\brain\cb1c83dd-c3b0-4e0d-adec-8149f35a5dfa\mypresensi_mobile_talenta_exact_1775478451899.png'
pdf.image(mobile_img_path, x='C', w=160)

# Web App Mockup
pdf.add_page()
pdf.set_font('helvetica', 'B', 14)
pdf.cell(0, 10, '2. Tampilan Web Dashboard Admin (Gaya Mekari Talenta)', new_x='LMARGIN', new_y='NEXT')
pdf.ln(2)

pdf.set_font('helvetica', '', 11)
pdf.multi_cell(0, 7, 'Dashboard Admin mengadopsi gaya Mekari Talenta: sidebar kiri dengan ikon tipis, area konten putih dominan, 3 kartu ringkasan di atas (Hadir / Alpa / Total), tabel data absensi bersih tanpa border berlebihan, dan badge status berwarna (Hijau: Hadir, Merah: Alpa, Kuning: Izin). Grafik garis sederhana di sisi kanan. Warna aksen tunggal: Biru TRPL.')
pdf.ln(5)

web_img_path = r'C:\Users\riki\.gemini\antigravity\brain\cb1c83dd-c3b0-4e0d-adec-8149f35a5dfa\mypresensi_web_talenta_exact_1775478470354.png'
pdf.image(web_img_path, x='C', w=165)

output_path = r'C:\Users\riki\Documents\Projek-PBL-Semester-6\UI_Mockup_MyPresensi_v4_Talenta.pdf'
pdf.output(output_path)
print(f"PDF berhasil dibuat: {output_path}")
