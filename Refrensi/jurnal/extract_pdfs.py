import os
from pypdf import PdfReader

dir_path = "C:\\Users\\riki\\Documents\\Projek-PBL-Semester-6\\Refrensi\\jurnal"

for file in os.listdir(dir_path):
    if file.endswith(".pdf"):
        pdf_path = os.path.join(dir_path, file)
        txt_path = pdf_path + ".txt"
        
        try:
            reader = PdfReader(pdf_path)
            text = ""
            for page in reader.pages:
                text += page.extract_text() + "\n"
            
            with open(txt_path, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"Extracted: {file}")
        except Exception as e:
            print(f"Error reading {file}: {e}")
