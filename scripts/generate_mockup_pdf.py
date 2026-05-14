from fpdf import FPDF

class PDF(FPDF):
    def header(self):
        self.set_font('helvetica', 'B', 15)
        self.cell(0, 10, 'MyPresensi - Desain UI/UX Mockup', align='C', new_x='LMARGIN', new_y='NEXT')
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
pdf.cell(0, 10, '1. Tampilan Aplikasi Mobile (Dashboard Mahasiswa)', new_x='LMARGIN', new_y='NEXT')

pdf.set_font('helvetica', '', 11)
pdf.multi_cell(0, 7, 'Desain menggunakan warna dasar hijau Politani. Mengusung gaya modern, flat, dan profesional tanpa elemen dekoratif berlebihan. Tombol utama (Call-to-Action) untuk registrasi absensi digambarkan secara jelas dan dominan.')
pdf.ln(5)

# Insert Mobile Image
mobile_img_path = r'C:\Users\riki\.gemini\antigravity\brain\cb1c83dd-c3b0-4e0d-adec-8149f35a5dfa\mobile_dashboard_mockup_1775472642070.png'
# Typically images generated are square 1024x1024 or similar, so let's set width to 120 and center it.
pdf.image(mobile_img_path, x='C', w=120)

# Web App Mockup
pdf.add_page()
pdf.set_font('helvetica', 'B', 14)
pdf.cell(0, 10, '2. Tampilan Web Dashboard (Admin/Dosen)', new_x='LMARGIN', new_y='NEXT')

pdf.set_font('helvetica', '', 11)
pdf.multi_cell(0, 7, 'Antarmuka admin menggunakan layout standard enterprise (sidebar navigasi kiri, header statistik di atas). Tabel data bersih dan efisien untuk memonitor rekap kehadiran mahasiswa secara komprehensif.')
pdf.ln(5)

# Insert Web Image
web_img_path = r'C:\Users\riki\.gemini\antigravity\brain\cb1c83dd-c3b0-4e0d-adec-8149f35a5dfa\web_dashboard_mockup_1775472674691.png'
pdf.image(web_img_path, x='C', w=160)

output_path = r'C:\Users\riki\Documents\Projek-PBL-Semester-6\UI_Mockup_MyPresensi.pdf'
pdf.output(output_path)
print(f"PDF successfully generated at {output_path}")
