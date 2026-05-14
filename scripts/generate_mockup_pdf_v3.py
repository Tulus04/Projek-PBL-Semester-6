from fpdf import FPDF

class PDF(FPDF):
    def header(self):
        self.set_font('helvetica', 'B', 15)
        self.cell(0, 10, 'MyPresensi - Desain UI/UX Mockup (Tema Talenta & TRPL)', align='C', new_x='LMARGIN', new_y='NEXT')
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
pdf.cell(0, 10, '1. Tampilan Aplikasi Mobile (Dashboard Mahasiswa - Gaya Talenta)', new_x='LMARGIN', new_y='NEXT')

pdf.set_font('helvetica', '', 11)
pdf.multi_cell(0, 7, 'Desain dirombak total mengadopsi gaya Mekari Talenta. Elemen UI dibungkus dalam "Card" (kartu) bersudut tumpul dengan bayangan drop-shadow yang sangat halus. Latar belakang (background) sangat terang dengan "White Space" ekstensif. Warna Biru TRPL disematkan secara elegan pada tombol presensi dan indikator aktif.')
pdf.ln(5)

# Insert Mobile Image
mobile_img_path = r'C:\Users\riki\.gemini\antigravity\brain\cb1c83dd-c3b0-4e0d-adec-8149f35a5dfa\talenta_mobile_blue_mockup_1775477025903.png'
pdf.image(mobile_img_path, x='C', w=120)

# Web App Mockup
pdf.add_page()
pdf.set_font('helvetica', 'B', 14)
pdf.cell(0, 10, '2. Tampilan Web Dashboard (Admin/Dosen - Gaya Talenta)', new_x='LMARGIN', new_y='NEXT')

pdf.set_font('helvetica', '', 11)
pdf.multi_cell(0, 7, 'Antarmuka web admin kini jauh lebih bersih. Menghilangkan batasan (border) solid yang kaku dan menggantinya dengan "Post-Flat Design" khas Mekari Talenta. Sangat profesional, luas, dan mudah dibaca oleh dosen atau admin prodi.')
pdf.ln(5)

# Insert Web Image
web_img_path = r'C:\Users\riki\.gemini\antigravity\brain\cb1c83dd-c3b0-4e0d-adec-8149f35a5dfa\talenta_web_blue_mockup_1775477009240.png'
pdf.image(web_img_path, x='C', w=160)

output_path = r'C:\Users\riki\Documents\Projek-PBL-Semester-6\UI_Mockup_MyPresensi_v3.pdf'
pdf.output(output_path)
print(f"PDF successfully generated at {output_path}")
