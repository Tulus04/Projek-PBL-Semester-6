"""
Generate mockup PDF v5 - Modern UI redesign untuk MyPresensi Mobile.

Output: docs/mockups/UI_Mockup_MyPresensi_v5_Modern.pdf

Render 12 mobile screen sebagai vector PDF pakai fpdf2.
Setiap screen di-draw programmatically dengan design tokens dari
mypresensi-mobile/lib/core/theme/app_colors.dart.

Run: python scripts/generate_mockup_pdf_v5.py
"""

from fpdf import FPDF
from pathlib import Path

# ===== Design Tokens (sync app_colors.dart) =====
COLORS = {
    'primary':         '#5483AD',
    'primary_light':   '#7BA3C7',
    'primary_dark':    '#3A6B8F',
    'primary_surface': '#E8F0F7',
    'background':      '#F4F6F8',
    'surface':         '#FFFFFF',
    'surface_variant': '#F8F9FA',
    'border':          '#E2E6EA',
    'border_light':    '#F0F2F4',
    'divider':         '#EEF0F2',
    'text_primary':    '#1A1D21',
    'text_secondary':  '#6B7280',
    'text_tertiary':   '#9CA3AF',
    'success':         '#1A7F37',
    'success_surface': '#ECFDF5',
    'warning':         '#9A6700',
    'warning_surface': '#FFFBEB',
    'danger':          '#CF222E',
    'danger_surface':  '#FEF2F2',
    'info':            '#0969DA',
    'info_surface':    '#EFF6FF',
    'bezel':           '#1A1A1A',
    'white':           '#FFFFFF',
    'black':           '#000000',
}


def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


# ===== Page & Phone Layout =====
PAGE_W, PAGE_H = 210, 297        # A4 portrait mm
MARGIN = 12

# Single phone left + annotation right
PHONE_W, PHONE_H = 78, 158
PHONE_BEZEL = 1.5
PHONE_RADIUS = 7
PHONE_X = MARGIN
PHONE_Y = 38

ANNOT_X = PHONE_X + PHONE_W + 12
ANNOT_W = PAGE_W - MARGIN - ANNOT_X

# Screen area inside phone bezel
SX = PHONE_X + PHONE_BEZEL
SY = PHONE_Y + PHONE_BEZEL
SW = PHONE_W - 2 * PHONE_BEZEL
SH = PHONE_H - 2 * PHONE_BEZEL

# Status bar + bottom nav heights inside screen
STATUS_BAR_H = 6
BOTTOM_NAV_H = 13

# Content area inside screen (between status bar and bottom nav)
CX = SX
CY = SY + STATUS_BAR_H
CW = SW
CH = SH - STATUS_BAR_H  # default no bottom nav


class MockupPDF(FPDF):
    def __init__(self):
        super().__init__('P', 'mm', 'A4')
        self.set_auto_page_break(False)
        self.set_margins(0, 0, 0)
        # Register Arial sebagai Unicode font (Windows). Arial = pengganti Helvetica
        # untuk dukungan karakter di luar Latin-1 (em-dash, en-dash, panah, dll).
        self.add_font('Arial', '', 'C:/Windows/Fonts/arial.ttf')
        self.add_font('Arial', 'B', 'C:/Windows/Fonts/arialbd.ttf')

    # ===== Color helpers =====
    def fill(self, key):
        self.set_fill_color(*hex_to_rgb(COLORS[key]))

    def draw(self, key):
        self.set_draw_color(*hex_to_rgb(COLORS[key]))

    def text_col(self, key):
        self.set_text_color(*hex_to_rgb(COLORS[key]))

    # ===== Shape primitives =====
    def rrect(self, x, y, w, h, r, style='F'):
        """Rounded rectangle."""
        self.rect(x, y, w, h, style=style, round_corners=True, corner_radius=r)

    def card(self, x, y, w, h, fill='surface', border='border', radius=2.5, line_w=0.15):
        """Card with optional border."""
        if border:
            self.fill(fill)
            self.draw(border)
            self.set_line_width(line_w)
            self.rrect(x, y, w, h, radius, style='DF')
        else:
            self.fill(fill)
            self.rrect(x, y, w, h, radius, style='F')

    def chip(self, x, y, label, fill='primary_surface', text='primary',
            font_size=5.5, padding_x=2.5, height=4):
        """Chip / badge."""
        self.set_font('Arial', 'B', font_size)
        text_w = self.get_string_width(label)
        chip_w = text_w + padding_x * 2
        self.fill(fill)
        self.rrect(x, y, chip_w, height, height / 2, style='F')
        self.text_col(text)
        self.set_xy(x, y - 0.2)
        self.cell(chip_w, height, label, align='C')
        return chip_w

    def text_at(self, x, y, text, color='text_primary', size=8, bold=False, align='L'):
        """Set font + color + draw text at position."""
        self.text_col(color)
        self.set_font('Arial', 'B' if bold else '', size)
        self.set_xy(x, y)
        if align == 'L':
            self.cell(0, size * 0.4, text, align='L')
        else:
            w = self.get_string_width(text) + 2
            self.set_xy(x, y)
            self.cell(w, size * 0.4, text, align=align)

    def hline(self, x1, y, x2, color='divider', w=0.15):
        """Horizontal divider line."""
        self.draw(color)
        self.set_line_width(w)
        self.line(x1, y, x2, y)

    # ===== Phone frame =====
    def draw_phone_bezel(self):
        # Outer dark bezel
        self.fill('bezel')
        self.rrect(PHONE_X, PHONE_Y, PHONE_W, PHONE_H, PHONE_RADIUS, style='F')
        # Screen background
        self.fill('background')
        self.rrect(SX, SY, SW, SH, PHONE_RADIUS - PHONE_BEZEL, style='F')
        # Notch
        notch_w, notch_h = 18, 2.5
        nx = SX + (SW - notch_w) / 2
        self.fill('bezel')
        self.rrect(nx, SY + 0.6, notch_w, notch_h, 1.2, style='F')

    def draw_status_bar(self):
        """Status bar inside screen (time + indicators)."""
        self.text_col('text_primary')
        self.set_font('Arial', 'B', 6)
        self.set_xy(SX + 4, SY + 1.8)
        self.cell(20, 3, '09:41', align='L')
        # Right indicators (signal, wifi, battery as small rects)
        rx = SX + SW - 14
        # Signal bars
        for i in range(4):
            self.fill('text_primary')
            self.rect(rx + i * 1.2, SY + 3.2 - i * 0.3, 0.8, 1.5 + i * 0.3, style='F')
        # Wifi (3 arcs simulated as nested filled segments)
        wx = rx + 6
        self.fill('text_primary')
        self.ellipse(wx, SY + 2.5, 2.2, 1.6, style='F')
        self.fill('background')
        self.ellipse(wx + 0.3, SY + 2.7, 1.6, 1.0, style='F')
        # Battery
        bx = rx + 9
        self.draw('text_primary')
        self.set_line_width(0.15)
        self.rect(bx, SY + 2.6, 4, 1.8, style='D')
        self.fill('text_primary')
        self.rect(bx + 4, SY + 3.1, 0.4, 0.8, style='F')
        self.rect(bx + 0.3, SY + 2.9, 3.4, 1.2, style='F')

    # ===== Icons (simple geometric) =====
    def icon(self, name, x, y, size=4, color='text_primary'):
        """Draw simple geometric icon at top-left (x, y) with bbox `size`."""
        s = size
        cx, cy = x + s / 2, y + s / 2
        rgb = hex_to_rgb(COLORS[color])
        self.set_draw_color(*rgb)
        self.set_fill_color(*rgb)
        self.set_line_width(0.4)

        if name == 'home':
            # Roof triangle + body rect
            self.polygon([(x, y + s * 0.45), (cx, y + s * 0.05),
                          (x + s, y + s * 0.45)], style='F')
            self.rect(x + s * 0.18, y + s * 0.45, s * 0.64, s * 0.5, style='F')
        elif name == 'qr':
            # 4 corners of QR
            t = s * 0.25
            for cx0, cy0 in [(x, y), (x + s - t, y), (x, y + s - t), (x + s - t, y + s - t)]:
                self.set_line_width(0.5)
                self.line(cx0, cy0, cx0 + t * 0.7, cy0)
                self.line(cx0, cy0, cx0, cy0 + t * 0.7)
                if cx0 == x + s - t:
                    self.line(cx0 + t, cy0, cx0 + t, cy0 + t * 0.7)
                if cy0 == y + s - t:
                    self.line(cx0, cy0 + t, cx0 + t * 0.7, cy0 + t)
                if cx0 == x + s - t and cy0 == y + s - t:
                    self.line(cx0 + t, cy0 + 0.3, cx0 + t, cy0 + t)
                    self.line(cx0 + 0.3, cy0 + t, cx0 + t, cy0 + t)
        elif name == 'history':
            # Clock-ish: circle outline + clock hand
            self.set_line_width(0.5)
            self.ellipse(cx - s * 0.42, cy - s * 0.42, s * 0.84, s * 0.84, style='D')
            self.line(cx, cy, cx, cy - s * 0.3)
            self.line(cx, cy, cx + s * 0.22, cy)
        elif name == 'bell':
            # Bell shape
            self.polygon([(cx - s * 0.35, cy + s * 0.2),
                          (cx - s * 0.35, cy - s * 0.1),
                          (cx, cy - s * 0.4),
                          (cx + s * 0.35, cy - s * 0.1),
                          (cx + s * 0.35, cy + s * 0.2)], style='F')
            self.rect(cx - s * 0.4, cy + s * 0.18, s * 0.8, s * 0.08, style='F')
            self.ellipse(cx - s * 0.08, cy + s * 0.28, s * 0.16, s * 0.12, style='F')
        elif name == 'profile':
            # Head circle + body arc
            self.ellipse(cx - s * 0.22, y + s * 0.05, s * 0.44, s * 0.4, style='F')
            self.ellipse(cx - s * 0.4, cy + s * 0.05, s * 0.8, s * 0.7, style='F')
            self.set_fill_color(*hex_to_rgb(COLORS['surface']))
            self.rect(x - 0.5, cy + s * 0.4, s + 1, s * 0.5, style='F')
            self.set_fill_color(*rgb)
        elif name == 'check':
            self.set_line_width(0.7)
            self.line(x + s * 0.2, cy, cx - s * 0.05, cy + s * 0.25)
            self.line(cx - s * 0.05, cy + s * 0.25, x + s * 0.85, cy - s * 0.25)
        elif name == 'arrow_right':
            self.set_line_width(0.4)
            self.line(x + s * 0.25, cy, x + s * 0.75, cy)
            self.line(x + s * 0.55, cy - s * 0.2, x + s * 0.75, cy)
            self.line(x + s * 0.55, cy + s * 0.2, x + s * 0.75, cy)
        elif name == 'fingerprint':
            for r in [s * 0.15, s * 0.25, s * 0.35, s * 0.45]:
                self.set_line_width(0.3)
                self.ellipse(cx - r, cy - r, 2 * r, 2 * r * 1.1, style='D')
        elif name == 'location':
            self.polygon([(cx, y + s * 0.05),
                          (x + s * 0.2, cy + s * 0.05),
                          (cx, y + s),
                          (x + s * 0.8, cy + s * 0.05)], style='F')
            self.set_fill_color(*hex_to_rgb(COLORS['surface']))
            self.ellipse(cx - s * 0.13, cy - s * 0.18, s * 0.26, s * 0.26, style='F')
        elif name == 'calendar':
            self.set_line_width(0.4)
            self.rect(x + s * 0.05, y + s * 0.2, s * 0.9, s * 0.75, style='D')
            self.line(x + s * 0.05, y + s * 0.4, x + s * 0.95, y + s * 0.4)
            self.line(x + s * 0.3, y + s * 0.05, x + s * 0.3, y + s * 0.3)
            self.line(x + s * 0.7, y + s * 0.05, x + s * 0.7, y + s * 0.3)
        elif name == 'face':
            self.set_line_width(0.4)
            self.ellipse(cx - s * 0.4, cy - s * 0.4, s * 0.8, s * 0.8, style='D')
            self.ellipse(cx - s * 0.18, cy - s * 0.15, s * 0.06, s * 0.06, style='F')
            self.ellipse(cx + s * 0.12, cy - s * 0.15, s * 0.06, s * 0.06, style='F')
            self.line(cx - s * 0.15, cy + s * 0.15, cx + s * 0.15, cy + s * 0.15)
        elif name == 'chevron_right':
            self.set_line_width(0.5)
            self.line(cx - s * 0.1, cy - s * 0.25, cx + s * 0.15, cy)
            self.line(cx - s * 0.1, cy + s * 0.25, cx + s * 0.15, cy)
        elif name == 'chevron_down':
            self.set_line_width(0.5)
            self.line(cx - s * 0.25, cy - s * 0.1, cx, cy + s * 0.15)
            self.line(cx + s * 0.25, cy - s * 0.1, cx, cy + s * 0.15)
        elif name == 'plus':
            self.set_line_width(0.6)
            self.line(cx - s * 0.3, cy, cx + s * 0.3, cy)
            self.line(cx, cy - s * 0.3, cx, cy + s * 0.3)
        elif name == 'flash':
            self.polygon([(cx - s * 0.05, y + s * 0.1),
                          (cx - s * 0.3, cy + s * 0.1),
                          (cx, cy),
                          (cx + s * 0.05, y + s * 0.1)], style='F')
            self.polygon([(cx + s * 0.05, y + s * 0.1),
                          (cx + s * 0.3, cy - s * 0.1),
                          (cx, cy),
                          (cx, y + s)], style='F')
        elif name == 'mail':
            self.set_line_width(0.4)
            self.rect(x + s * 0.05, y + s * 0.2, s * 0.9, s * 0.6, style='D')
            self.line(x + s * 0.05, y + s * 0.2, cx, cy + s * 0.05)
            self.line(x + s * 0.95, y + s * 0.2, cx, cy + s * 0.05)
        elif name == 'help':
            self.set_line_width(0.4)
            self.ellipse(cx - s * 0.4, cy - s * 0.4, s * 0.8, s * 0.8, style='D')
            self.text_col(color)
            self.set_font('Arial', 'B', size * 1.6)
            self.set_xy(x, cy - s * 0.35)
            self.cell(s, s * 0.7, '?', align='C')
        elif name == 'logout':
            self.set_line_width(0.4)
            self.rect(x + s * 0.05, y + s * 0.1, s * 0.55, s * 0.8, style='D')
            self.line(cx + s * 0.1, cy, x + s, cy)
            self.line(x + s * 0.8, cy - s * 0.2, x + s, cy)
            self.line(x + s * 0.8, cy + s * 0.2, x + s, cy)
        elif name == 'search':
            self.set_line_width(0.4)
            self.ellipse(x + s * 0.1, y + s * 0.1, s * 0.6, s * 0.6, style='D')
            self.line(x + s * 0.6, y + s * 0.6, x + s * 0.95, y + s * 0.95)
        elif name == 'settings':
            self.set_line_width(0.3)
            self.ellipse(cx - s * 0.15, cy - s * 0.15, s * 0.3, s * 0.3, style='D')
            for ang_i in range(8):
                import math
                ang = ang_i * math.pi / 4
                x1 = cx + math.cos(ang) * s * 0.35
                y1 = cy + math.sin(ang) * s * 0.35
                x2 = cx + math.cos(ang) * s * 0.5
                y2 = cy + math.sin(ang) * s * 0.5
                self.line(x1, y1, x2, y2)
        elif name == 'sun':
            self.ellipse(cx - s * 0.2, cy - s * 0.2, s * 0.4, s * 0.4, style='F')
            for ang_i in range(8):
                import math
                ang = ang_i * math.pi / 4
                x1 = cx + math.cos(ang) * s * 0.3
                y1 = cy + math.sin(ang) * s * 0.3
                x2 = cx + math.cos(ang) * s * 0.45
                y2 = cy + math.sin(ang) * s * 0.45
                self.set_line_width(0.5)
                self.line(x1, y1, x2, y2)
        elif name == 'class':
            # Book/class icon
            self.set_line_width(0.4)
            self.rect(x + s * 0.15, y + s * 0.1, s * 0.7, s * 0.8, style='D')
            self.line(x + s * 0.15, y + s * 0.3, x + s * 0.85, y + s * 0.3)
            self.line(x + s * 0.3, y + s * 0.5, x + s * 0.7, y + s * 0.5)
            self.line(x + s * 0.3, y + s * 0.65, x + s * 0.7, y + s * 0.65)
        elif name == 'graph':
            # Bar chart
            self.fill(color)
            self.rect(x + s * 0.1, cy + s * 0.1, s * 0.18, s * 0.3, style='F')
            self.rect(x + s * 0.4, y + s * 0.3, s * 0.18, s * 0.6, style='F')
            self.rect(x + s * 0.7, y + s * 0.5, s * 0.18, s * 0.4, style='F')
        elif name == 'document':
            self.set_line_width(0.4)
            self.polygon([(x + s * 0.15, y + s * 0.05),
                          (x + s * 0.7, y + s * 0.05),
                          (x + s * 0.85, y + s * 0.2),
                          (x + s * 0.85, y + s * 0.95),
                          (x + s * 0.15, y + s * 0.95)], style='D')
            self.line(x + s * 0.3, y + s * 0.4, x + s * 0.7, y + s * 0.4)
            self.line(x + s * 0.3, y + s * 0.55, x + s * 0.7, y + s * 0.55)
            self.line(x + s * 0.3, y + s * 0.7, x + s * 0.55, y + s * 0.7)
        elif name == 'flag':
            self.set_line_width(0.4)
            self.line(x + s * 0.2, y + s * 0.1, x + s * 0.2, y + s * 0.9)
            self.polygon([(x + s * 0.2, y + s * 0.1),
                          (x + s * 0.85, y + s * 0.25),
                          (x + s * 0.2, y + s * 0.5)], style='F')

    # ===== Bottom navigation =====
    def draw_bottom_nav(self, active=0):
        nav_y = SY + SH - BOTTOM_NAV_H
        self.fill('surface')
        self.rect(SX, nav_y, SW, BOTTOM_NAV_H, style='F')
        self.draw('border_light')
        self.set_line_width(0.1)
        self.line(SX, nav_y, SX + SW, nav_y)
        labels = ['Beranda', 'Scan', 'Riwayat', 'Notif', 'Profil']
        icons_n = ['home', 'qr', 'history', 'bell', 'profile']
        tab_w = SW / 5
        for i, (label, ic) in enumerate(zip(labels, icons_n)):
            cx = SX + tab_w * i + tab_w / 2
            is_active = i == active
            color = 'primary' if is_active else 'text_tertiary'
            if is_active:
                self.fill('primary_surface')
                self.rrect(cx - 5.5, nav_y + 1.5, 11, 5, 2.5, style='F')
            self.icon(ic, cx - 1.6, nav_y + 2, 3.2, color)
            self.text_col(color)
            self.set_font('Arial', 'B' if is_active else '', 4.5)
            self.set_xy(cx - tab_w / 2, nav_y + 7.8)
            self.cell(tab_w, 3, label, align='C')

    # ===== Annotation panel =====
    def draw_annotation(self, title, subtitle, sections):
        """
        sections: list of dict {'title': str, 'items': [str, ...]}
        """
        self.text_col('primary')
        self.set_font('Arial', 'B', 14)
        self.set_xy(ANNOT_X, PHONE_Y)
        self.cell(ANNOT_W, 6, title)
        self.text_col('text_secondary')
        self.set_font('Arial', '', 8)
        self.set_xy(ANNOT_X, PHONE_Y + 6.5)
        self.multi_cell(ANNOT_W, 3.5, subtitle)
        y = self.get_y() + 4
        for sec in sections:
            self.text_col('text_primary')
            self.set_font('Arial', 'B', 9)
            self.set_xy(ANNOT_X, y)
            self.cell(ANNOT_W, 4, sec['title'])
            y += 4.8
            for item in sec['items']:
                self.text_col('primary')
                self.set_font('Arial', 'B', 7)
                self.set_xy(ANNOT_X, y)
                self.cell(2, 3.5, '·')
                self.text_col('text_secondary')
                self.set_font('Arial', '', 7.5)
                self.set_xy(ANNOT_X + 3, y)
                self.multi_cell(ANNOT_W - 3, 3.3, item)
                y = self.get_y() + 1
            y += 2

    # ===== Page header =====
    def page_header(self, num, title):
        self.text_col('text_tertiary')
        self.set_font('Arial', 'B', 8)
        self.set_xy(MARGIN, 10)
        self.cell(0, 4, f'MyPresensi Mobile  ·  Mockup v5  ·  Halaman {num}')
        self.text_col('text_primary')
        self.set_font('Arial', 'B', 14)
        self.set_xy(MARGIN, 16)
        self.cell(0, 6, title)
        self.draw('border')
        self.set_line_width(0.2)
        self.line(MARGIN, 26, PAGE_W - MARGIN, 26)

    def page_footer(self):
        self.text_col('text_tertiary')
        self.set_font('Arial', '', 7)
        self.set_xy(MARGIN, PAGE_H - 10)
        self.cell(0, 3, 'TRPL · Politeknik Pertanian Negeri Samarinda  ·  Design System: Talenta-inspired, Material 3')
        self.set_xy(PAGE_W - MARGIN - 20, PAGE_H - 10)
        self.cell(20, 3, f'{self.page_no()}', align='R')


# =====================================================================
# SCREEN RENDERERS - setiap function gambar konten di dalam phone screen
# Bounding box: SX, SY+STATUS_BAR_H .. SX+SW, SY+SH-BOTTOM_NAV_H (jika nav ditampilkan)
# =====================================================================

def render_cover(pdf: MockupPDF):
    """Halaman 1: Cover - title, subtitle, branding."""
    pdf.add_page()
    # Background gradient simulation: solid primary band on top
    pdf.fill('primary')
    pdf.rect(0, 0, PAGE_W, 90, style='F')
    pdf.fill('primary_dark')
    pdf.rect(0, 80, PAGE_W, 10, style='F')

    # Big title
    pdf.text_col('white')
    pdf.set_font('Arial', 'B', 32)
    pdf.set_xy(MARGIN, 30)
    pdf.cell(0, 12, 'MyPresensi')
    pdf.set_font('Arial', '', 16)
    pdf.set_xy(MARGIN, 46)
    pdf.cell(0, 8, 'Mobile UI Redesign - Mockup v5')

    # Tagline
    pdf.set_font('Arial', '', 11)
    pdf.set_xy(MARGIN, 58)
    pdf.cell(0, 6, 'Modern, professional, content-rich. Talenta-inspired DNA + Material 3.')

    # Subtitle box
    pdf.fill('surface')
    pdf.draw('border')
    pdf.set_line_width(0.3)
    pdf.rrect(MARGIN, 110, PAGE_W - 2 * MARGIN, 50, 4, style='DF')

    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 12)
    pdf.set_xy(MARGIN + 8, 118)
    pdf.cell(0, 5, 'Tujuan Redesign')
    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 9.5)
    pdf.set_xy(MARGIN + 8, 126)
    pdf.multi_cell(PAGE_W - 2 * (MARGIN + 8), 4.5,
                   'Memperbaiki kepadatan informasi dan keterbacaan UI mobile MyPresensi yang sebelumnya '
                   'terasa kosong dan kurang informatif. Setiap screen kini punya struktur jelas, '
                   '3-state lengkap (loading/empty/error), dan elemen visual yang mendukung tugas user '
                   '(mahasiswa) tanpa over-design. Tetap respect design lock: warna TRPL, typography '
                   'Plus Jakarta Sans + Inter, library Riverpod + GoRouter + Material 3.')

    # Daftar isi
    pdf.fill('surface')
    pdf.draw('border')
    pdf.rrect(MARGIN, 170, PAGE_W - 2 * MARGIN, 95, 4, style='DF')

    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 12)
    pdf.set_xy(MARGIN + 8, 178)
    pdf.cell(0, 5, 'Daftar Mockup')

    items = [
        ('1.', 'Sistem Desain', 'Color tokens, typography, spacing, elevation'),
        ('2.', 'Splash & Login', 'Loading state + welcoming login form'),
        ('3.', 'Beranda (Home)', 'Header kompak, stats, jadwal hari ini, sesi aktif, shortcuts'),
        ('4.', 'Scan QR', 'Camera overlay dengan instruksi & feedback'),
        ('5.', 'Hasil Presensi', 'Konfirmasi visual setelah submit berhasil'),
        ('6.', 'Riwayat Kehadiran', 'Filter, calendar heatmap, chart, daftar record'),
        ('7.', 'Detail Riwayat (Bottom Sheet)', 'Expand info per record tanpa pindah screen'),
        ('8.', 'Notifikasi', 'Tab All/Unread, group per tanggal, swipe action'),
        ('9.', 'Profil', 'Cover banner, avatar, stats, menu grouped'),
        ('10.', 'Pengajuan Izin (List + Form)', 'Riwayat pengajuan + form submission'),
        ('11.', 'Daftar Wajah (Face Registration)', 'Guided pose dengan circle frame'),
        ('12.', 'Empty State Variants', 'Ilustrasi konsisten di seluruh app'),
    ]
    y = 188
    for num, title, desc in items:
        pdf.text_col('primary')
        pdf.set_font('Arial', 'B', 8)
        pdf.set_xy(MARGIN + 8, y)
        pdf.cell(8, 4, num)
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 8)
        pdf.set_xy(MARGIN + 16, y)
        pdf.cell(60, 4, title)
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 7.5)
        pdf.set_xy(MARGIN + 76, y)
        pdf.cell(0, 4, desc)
        y += 5.5

    # Brand footer
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 7.5)
    pdf.set_xy(MARGIN, PAGE_H - 18)
    pdf.cell(0, 4, 'TRPL · Politeknik Pertanian Negeri Samarinda')
    pdf.set_xy(MARGIN, PAGE_H - 14)
    pdf.cell(0, 4, 'Proyek PBL Semester 6 · Riki & Tim · 2026')


def render_design_system(pdf: MockupPDF):
    """Halaman 2: Design System - palette, typography, spacing."""
    pdf.add_page()
    pdf.page_header(2, 'Sistem Desain')

    # === Color Palette ===
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 11)
    pdf.set_xy(MARGIN, 32)
    pdf.cell(0, 5, 'Palet Warna')
    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 8)
    pdf.set_xy(MARGIN, 38)
    pdf.cell(0, 4, 'Disinkronkan dengan app_colors.dart - JANGAN gunakan warna di luar token ini.')

    color_groups = [
        ('Primary (TRPL Blue)', [
            ('primary', '#5483AD', 'Tombol utama, link aktif, brand'),
            ('primary_light', '#7BA3C7', 'Hover state, accent ringan'),
            ('primary_dark', '#3A6B8F', 'Pressed state, gradient end'),
            ('primary_surface', '#E8F0F7', 'Background highlight, card aktif'),
        ]),
        ('Status', [
            ('success', '#1A7F37', 'Badge "Hadir", confirmation'),
            ('warning', '#9A6700', 'Badge "Izin/Sakit", caution'),
            ('danger', '#CF222E', 'Badge "Alpa", error, destructive'),
            ('info', '#0969DA', 'Info banner, neutral notification'),
        ]),
        ('Neutral', [
            ('text_primary', '#1A1D21', 'Headline, body utama'),
            ('text_secondary', '#6B7280', 'Body sekunder, label'),
            ('text_tertiary', '#9CA3AF', 'Placeholder, caption'),
            ('border', '#E2E6EA', 'Card border, divider tegas'),
        ]),
    ]

    y = 46
    for group_name, items in color_groups:
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 9)
        pdf.set_xy(MARGIN, y)
        pdf.cell(0, 4, group_name)
        y += 6
        for token, hex_val, desc in items:
            # Color swatch
            pdf.fill(token)
            pdf.draw('border')
            pdf.set_line_width(0.15)
            pdf.rrect(MARGIN, y, 10, 8, 1.5, style='DF')
            # Token name
            pdf.text_col('text_primary')
            pdf.set_font('Arial', 'B', 8)
            pdf.set_xy(MARGIN + 13, y + 0.5)
            pdf.cell(45, 3.5, token)
            # Hex
            pdf.text_col('text_secondary')
            pdf.set_font('Courier', '', 7.5)
            pdf.set_xy(MARGIN + 13, y + 4)
            pdf.cell(45, 3, hex_val)
            # Description
            pdf.text_col('text_secondary')
            pdf.set_font('Arial', '', 7.5)
            pdf.set_xy(MARGIN + 60, y + 2)
            pdf.cell(0, 4, desc)
            y += 9
        y += 2

    # === Typography ===
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 11)
    pdf.set_xy(120, 32)
    pdf.cell(0, 5, 'Tipografi')
    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 8)
    pdf.set_xy(120, 38)
    pdf.cell(0, 4, 'Plus Jakarta Sans (heading) + Inter (body)')

    typo_samples = [
        ('Display Large', 32, True, 'Beranda'),
        ('Display Small', 24, True, 'MyPresensi'),
        ('Headline Md', 20, True, 'Sesi Aktif'),
        ('Headline Sm', 18, True, 'Riwayat Kehadiran'),
        ('Title Lg', 16, True, 'Pertemuan 5'),
        ('Title Md', 14, False, 'Pemrograman Berbasis Web'),
        ('Body Lg', 11, False, 'Selamat datang kembali'),
        ('Body Md', 10, False, 'Submitted at 09:42 WITA'),
        ('Caption', 8, False, '23 Mei 2026 · 09:30'),
    ]
    y = 46
    for label, size, bold, sample in typo_samples:
        pdf.text_col('text_tertiary')
        pdf.set_font('Arial', '', 7)
        pdf.set_xy(120, y)
        pdf.cell(20, 4, label)
        pdf.text_col('text_secondary')
        pdf.set_font('Courier', '', 6.5)
        pdf.cell(12, 4, f'{size}px')
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B' if bold else '', size * 0.55)
        pdf.set_xy(120, y + 4)
        pdf.cell(0, size * 0.5, sample)
        y += size * 0.55 + 5

    # === Spacing & Elevation note ===
    pdf.fill('surface_variant')
    pdf.draw('border')
    pdf.set_line_width(0.15)
    pdf.rrect(MARGIN, 235, PAGE_W - 2 * MARGIN, 38, 3, style='DF')
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 9)
    pdf.set_xy(MARGIN + 5, 240)
    pdf.cell(0, 4, 'Spacing & Elevation Scale')
    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 7.5)
    pdf.set_xy(MARGIN + 5, 247)
    pdf.multi_cell(PAGE_W - 2 * (MARGIN + 5), 3.5,
                   'Spacing: 4 / 8 / 12 / 16 / 20 / 24 / 32 px (kelipatan 4). '
                   'Border radius: 8 (chip), 12 (input), 14 (button), 16 (card), 20 (header). '
                   'Card border: 0.5px solid #E2E6EA - TIDAK pakai box-shadow tebal di mobile, '
                   'kecuali bottom nav (shadow halus 0,-2,12 alpha 0.06). '
                   'Animasi: 200-400ms easeOut untuk transisi antar state.')

    pdf.page_footer()


def render_login_screen(pdf: MockupPDF):
    """Login screen content inside phone bbox."""
    pdf.draw_status_bar()
    # Background subtle gradient (solid + lighter band on top)
    pdf.fill('primary_surface')
    pdf.rect(SX, SY + STATUS_BAR_H, SW, 50, style='F')

    # Logo (rounded square with fingerprint icon)
    logo_size = 14
    lx = SX + (SW - logo_size) / 2
    ly = SY + 18
    pdf.fill('primary')
    pdf.rrect(lx, ly, logo_size, logo_size, 3, style='F')
    pdf.icon('fingerprint', lx + 3, ly + 3, 8, 'white')

    # Title
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 13)
    pdf.set_xy(SX, ly + logo_size + 3)
    pdf.cell(SW, 5, 'MyPresensi', align='C')
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 7)
    pdf.set_xy(SX, ly + logo_size + 8)
    pdf.cell(SW, 3, 'TRPL · Politani Samarinda', align='C')

    # Form card
    fcx = SX + 4
    fcy = SY + STATUS_BAR_H + 50
    fcw = SW - 8
    fch = 92
    pdf.card(fcx, fcy, fcw, fch, fill='surface', border='border', radius=4)

    # Form title
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 10)
    pdf.set_xy(fcx + 5, fcy + 5)
    pdf.cell(0, 4, 'Masuk ke Akun')
    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 6.5)
    pdf.set_xy(fcx + 5, fcy + 10)
    pdf.cell(0, 3, 'Gunakan akun yang terdaftar di sistem')

    # Email field
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 6.5)
    pdf.set_xy(fcx + 5, fcy + 18)
    pdf.cell(0, 3, 'Email')
    pdf.fill('surface_variant')
    pdf.draw('border')
    pdf.set_line_width(0.15)
    pdf.rrect(fcx + 5, fcy + 22, fcw - 10, 9, 2.2, style='DF')
    pdf.icon('mail', fcx + 7, fcy + 24.5, 4, 'text_tertiary')
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 7)
    pdf.set_xy(fcx + 13, fcy + 24.5)
    pdf.cell(0, 4, 'nama@politani.ac.id')

    # Password field
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 6.5)
    pdf.set_xy(fcx + 5, fcy + 35)
    pdf.cell(0, 3, 'Password')
    pdf.fill('surface_variant')
    pdf.draw('primary')
    pdf.set_line_width(0.4)
    pdf.rrect(fcx + 5, fcy + 39, fcw - 10, 9, 2.2, style='DF')
    pdf.text_col('text_primary')
    pdf.set_font('Arial', '', 8)
    pdf.set_xy(fcx + 8, fcy + 41)
    pdf.cell(0, 4, '··········')

    # Forgot password link
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 6.5)
    pdf.set_xy(fcx + 5, fcy + 50)
    pdf.cell(fcw - 10, 3, 'Lupa password?', align='R')

    # Login button
    pdf.fill('primary')
    pdf.rrect(fcx + 5, fcy + 56, fcw - 10, 11, 3, style='F')
    pdf.text_col('white')
    pdf.set_font('Arial', 'B', 8)
    pdf.set_xy(fcx + 5, fcy + 60)
    pdf.cell(fcw - 10, 3, 'Masuk', align='C')

    # Help text
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 6)
    pdf.set_xy(fcx + 5, fcy + 73)
    pdf.cell(fcw - 10, 3, 'Butuh bantuan? Hubungi admin prodi.', align='C')

    # Version
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 5.5)
    pdf.set_xy(SX, SY + SH - 8)
    pdf.cell(SW, 3, 'v1.0.0  ·  Build 2026.05', align='C')


def render_home_screen(pdf: MockupPDF):
    """Home (Beranda) - header kompak, stats, jadwal, sesi aktif, shortcuts."""
    pdf.draw_status_bar()
    pdf.draw_bottom_nav(active=0)

    y = SY + STATUS_BAR_H + 1

    # === Header kompak (greeting + avatar mini + bell) ===
    pdf.fill('primary')
    pdf.rect(SX, y, SW, 26, style='F')
    # Light wave decoration
    pdf.fill('primary_light')
    pdf.ellipse(SX + SW - 30, y - 12, 60, 30, style='F')
    pdf.fill('primary')
    pdf.rect(SX, y + 14, SW, 12, style='F')

    # Greeting
    pdf.text_col('white')
    pdf.set_font('Arial', '', 6.5)
    pdf.set_xy(SX + 4, y + 3)
    pdf.cell(0, 3, 'Selamat Pagi')
    pdf.set_font('Arial', 'B', 11)
    pdf.set_xy(SX + 4, y + 7)
    pdf.cell(0, 5, 'Riki, halo!')
    pdf.set_font('Arial', '', 6)
    pdf.set_xy(SX + 4, y + 14)
    pdf.cell(0, 3, '23222048 · TRPL Semester 6')

    # Bell + avatar mini (right side)
    pdf.fill('white')
    pdf.set_fill_color(255, 255, 255)
    # Bell
    pdf.set_draw_color(255, 255, 255)
    pdf.set_line_width(0.4)
    bell_x = SX + SW - 18
    pdf.icon('bell', bell_x, y + 5, 5, 'white')
    # Bell badge dot
    pdf.fill('danger')
    pdf.ellipse(bell_x + 3.2, y + 5, 1.6, 1.6, style='F')

    # Avatar circle
    avatar_x = SX + SW - 10
    pdf.fill('white')
    pdf.ellipse(avatar_x, y + 5, 6, 6, style='F')
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(avatar_x, y + 6.3)
    pdf.cell(6, 3, 'RA', align='C')

    y += 22

    # === Stats bar (3 metric cards) ===
    pdf.fill('surface')
    pdf.rrect(SX + 3, y + 4, SW - 6, 20, 2.5, style='F')
    # Border
    pdf.draw('border')
    pdf.set_line_width(0.15)
    pdf.rrect(SX + 3, y + 4, SW - 6, 20, 2.5, style='D')

    metrics = [
        ('92%', 'Kehadiran', 'success'),
        ('18', 'Hadir', 'primary'),
        ('1', 'Izin', 'warning'),
    ]
    mw = (SW - 6) / 3
    for i, (val, lbl, col) in enumerate(metrics):
        mx = SX + 3 + mw * i
        if i > 0:
            pdf.draw('divider')
            pdf.set_line_width(0.15)
            pdf.line(mx, y + 7, mx, y + 21)
        pdf.text_col(col)
        pdf.set_font('Arial', 'B', 11)
        pdf.set_xy(mx, y + 7)
        pdf.cell(mw, 5, val, align='C')
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(mx, y + 14)
        pdf.cell(mw, 3, lbl, align='C')

    y += 28

    # === "Jadwal Hari Ini" ===
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 8)
    pdf.set_xy(SX + 4, y)
    pdf.cell(0, 4, 'Jadwal Hari Ini')
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 6.5)
    pdf.set_xy(SX + SW - 25, y)
    pdf.cell(20, 4, 'Lihat Semua', align='R')
    y += 6

    # Schedule timeline 2 items
    schedule = [
        ('07:30', '09:30', 'Pemrograman Berbasis Web', 'Lab 1', 'success', 'Selesai'),
        ('10:00', '12:00', 'Manajemen Proyek TI', 'Ruang 4.2', 'primary', 'Berlangsung'),
    ]
    for start, end, name, room, col, status in schedule:
        pdf.card(SX + 3, y, SW - 6, 14, fill='surface', border='border', radius=2.5)
        # Time
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 7)
        pdf.set_xy(SX + 5, y + 2)
        pdf.cell(13, 3, start)
        pdf.text_col('text_tertiary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(SX + 5, y + 5.5)
        pdf.cell(13, 3, f'– {end}')
        # Vertical accent line
        pdf.fill(col)
        pdf.rect(SX + 18.5, y + 2, 0.8, 10, style='F')
        # Course
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 7)
        pdf.set_xy(SX + 21, y + 2)
        pdf.cell(0, 3, name)
        pdf.text_col('text_tertiary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(SX + 21, y + 5.5)
        pdf.cell(0, 3, f'Ruang: {room}')
        # Status chip
        chip_label = status.upper()
        pdf.set_font('Arial', 'B', 5)
        text_w = pdf.get_string_width(chip_label) + 4
        pdf.fill(f'{col}_surface' if f'{col}_surface' in COLORS else 'primary_surface')
        pdf.rrect(SX + SW - 5 - text_w, y + 2, text_w, 4, 2, style='F')
        pdf.text_col(col)
        pdf.set_xy(SX + SW - 5 - text_w, y + 1.7)
        pdf.cell(text_w, 4, chip_label, align='C')
        y += 16

    # === Shortcut grid 4 column ===
    y += 2
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 8)
    pdf.set_xy(SX + 4, y)
    pdf.cell(0, 4, 'Akses Cepat')
    y += 6

    shortcuts = [
        ('qr', 'Scan QR', 'primary'),
        ('document', 'Pengajuan', 'warning'),
        ('face', 'Wajah Saya', 'success'),
        ('help', 'Bantuan', 'info'),
    ]
    sw_w = (SW - 6) / 4
    for i, (ic, lbl, col) in enumerate(shortcuts):
        sx = SX + 3 + sw_w * i
        pdf.card(sx + 1, y, sw_w - 2, 18, fill='surface', border='border', radius=2.5)
        # Icon container
        pdf.fill(f'{col}_surface' if f'{col}_surface' in COLORS else 'primary_surface')
        pdf.rrect(sx + (sw_w - 2) / 2 - 4 + 1, y + 2.5, 8, 8, 2, style='F')
        pdf.icon(ic, sx + (sw_w - 2) / 2 - 2 + 1, y + 4.5, 4, col)
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 5.5)
        pdf.set_xy(sx + 1, y + 13)
        pdf.cell(sw_w - 2, 3, lbl, align='C')

    y += 21

    # === Sesi Aktif spotlight ===
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 8)
    pdf.set_xy(SX + 4, y)
    pdf.cell(0, 4, 'Sesi Aktif Sekarang')
    # Live dot
    pdf.fill('success')
    pdf.ellipse(SX + 28, y + 1.5, 2, 2, style='F')
    pdf.text_col('success')
    pdf.set_font('Arial', 'B', 5.5)
    pdf.set_xy(SX + 31, y + 0.5)
    pdf.cell(0, 4, 'LIVE')
    y += 6

    # Active session card with CTA
    pdf.fill('primary_surface')
    pdf.draw('primary')
    pdf.set_line_width(0.3)
    pdf.rrect(SX + 3, y, SW - 6, 22, 3, style='DF')

    pdf.icon('class', SX + 6, y + 3, 6, 'primary')
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 7.5)
    pdf.set_xy(SX + 14, y + 3)
    pdf.cell(0, 3, 'Manajemen Proyek TI')
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 5.5)
    pdf.set_xy(SX + 14, y + 7)
    pdf.cell(0, 3, 'Pertemuan 6 · Pak Andi · Ruang 4.2')

    # Countdown
    pdf.text_col('warning')
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + 14, y + 11)
    pdf.cell(0, 3, 'Kode QR berakhir dalam 02:14')

    # Scan button
    pdf.fill('primary')
    pdf.rrect(SX + 6, y + 15.5, SW - 12, 5, 1.5, style='F')
    pdf.text_col('white')
    pdf.set_font('Arial', 'B', 6.5)
    pdf.set_xy(SX + 6, y + 16.5)
    pdf.cell(SW - 12, 3, 'Scan QR Sekarang  >', align='C')


def render_scan_qr_screen(pdf: MockupPDF):
    """Scan QR screen - full camera with overlay frame."""
    # Camera dark bg
    pdf.fill('black')
    pdf.rect(SX, SY + STATUS_BAR_H, SW, SH - STATUS_BAR_H, style='F')

    # Status bar (light text on dark)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + 4, SY + 1.8)
    pdf.cell(20, 3, '09:41')

    # Top bar
    pdf.set_fill_color(0, 0, 0)
    # Back button
    pdf.fill('text_secondary')
    pdf.set_fill_color(60, 60, 60)
    pdf.rrect(SX + 3, SY + 8, 7, 7, 2, style='F')
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Arial', 'B', 9)
    pdf.set_xy(SX + 3, SY + 9.5)
    pdf.cell(7, 4, '<', align='C')

    # Title pill
    pdf.set_fill_color(60, 60, 60)
    pdf.rrect(SX + (SW - 30) / 2, SY + 9, 30, 5.5, 2.7, style='F')
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + (SW - 30) / 2, SY + 10.2)
    pdf.cell(30, 3, 'Scan QR Presensi', align='C')

    # Torch
    pdf.set_fill_color(60, 60, 60)
    pdf.rrect(SX + SW - 10, SY + 8, 7, 7, 2, style='F')
    pdf.icon('flash', SX + SW - 10 + 1.5, SY + 9.5, 4, 'white')

    # Scan frame (semi transparent overlay simulated)
    frame_size = 50
    fx = SX + (SW - frame_size) / 2
    fy = SY + 30
    # Lighter rect inside
    pdf.set_fill_color(20, 20, 20)
    pdf.rrect(fx, fy, frame_size, frame_size, 4, style='F')

    # Corner brackets
    cl = 7
    cw = 0.9
    pdf.fill('primary')
    # Top-left
    pdf.rect(fx, fy, cl, cw, style='F')
    pdf.rect(fx, fy, cw, cl, style='F')
    # Top-right
    pdf.rect(fx + frame_size - cl, fy, cl, cw, style='F')
    pdf.rect(fx + frame_size - cw, fy, cw, cl, style='F')
    # Bottom-left
    pdf.rect(fx, fy + frame_size - cw, cl, cw, style='F')
    pdf.rect(fx, fy + frame_size - cl, cw, cl, style='F')
    # Bottom-right
    pdf.rect(fx + frame_size - cl, fy + frame_size - cw, cl, cw, style='F')
    pdf.rect(fx + frame_size - cw, fy + frame_size - cl, cw, cl, style='F')

    # Scan line animation simulation
    pdf.fill('primary')
    pdf.rect(fx + 3, fy + frame_size / 2, frame_size - 6, 0.5, style='F')

    # Mock QR pattern inside frame
    pdf.set_fill_color(80, 80, 80)
    cell_size = 1.8
    grid = [
        '1110011',
        '1010110',
        '1101011',
        '0110101',
        '1011110',
        '1101001',
        '0110110',
    ]
    pattern_x = fx + (frame_size - 7 * cell_size) / 2
    pattern_y = fy + (frame_size - 7 * cell_size) / 2
    for row, line in enumerate(grid):
        for col, ch in enumerate(line):
            if ch == '1':
                pdf.rect(pattern_x + col * cell_size, pattern_y + row * cell_size,
                         cell_size, cell_size, style='F')

    # Bottom info card
    bcy = SY + SH - 38
    pdf.fill('surface')
    pdf.rrect(SX + 3, bcy, SW - 6, 32, 3, style='F')

    # QR icon
    pdf.fill('primary_surface')
    pdf.rrect(SX + (SW - 10) / 2, bcy + 3, 10, 10, 2.5, style='F')
    pdf.icon('qr', SX + (SW - 10) / 2 + 1, bcy + 4, 8, 'primary')

    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 7.5)
    pdf.set_xy(SX + 3, bcy + 16)
    pdf.cell(SW - 6, 3, 'Arahkan kamera ke QR Code', align='C')
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 6)
    pdf.set_xy(SX + 3, bcy + 20)
    pdf.cell(SW - 6, 3, 'QR ditampilkan oleh dosen di layar kelas', align='C')

    # Help row
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + 3, bcy + 26)
    pdf.cell(SW - 6, 3, 'QR tidak terdeteksi? Lihat panduan >', align='C')


def render_attendance_result(pdf: MockupPDF):
    """Hasil Presensi - success confirmation."""
    pdf.draw_status_bar()
    y = SY + STATUS_BAR_H + 8

    # Success badge animation simulation (concentric circles)
    cx = SX + SW / 2
    cy = y + 18
    pdf.fill('success_surface')
    pdf.ellipse(cx - 22, cy - 22, 44, 44, style='F')
    pdf.fill('white')
    pdf.ellipse(cx - 18, cy - 18, 36, 36, style='F')
    pdf.fill('success')
    pdf.ellipse(cx - 14, cy - 14, 28, 28, style='F')
    # Check mark
    pdf.set_draw_color(255, 255, 255)
    pdf.set_line_width(1.6)
    pdf.line(cx - 6, cy + 1, cx - 1, cy + 6)
    pdf.line(cx - 1, cy + 6, cx + 7, cy - 5)

    # Title
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 14)
    pdf.set_xy(SX, y + 42)
    pdf.cell(SW, 6, 'Presensi Berhasil!', align='C')
    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 8)
    pdf.set_xy(SX, y + 50)
    pdf.cell(SW, 4, 'Kehadiranmu sudah tercatat di sistem', align='C')

    # Detail card
    cy0 = y + 62
    pdf.card(SX + 4, cy0, SW - 8, 60, fill='surface', border='border', radius=3)

    # Header inside card
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + 7, cy0 + 4)
    pdf.cell(0, 3, 'DETAIL PRESENSI')
    pdf.hline(SX + 7, cy0 + 9, SX + SW - 7)

    rows = [
        ('Mata Kuliah', 'Manajemen Proyek TI'),
        ('Pertemuan', 'Pertemuan 6 - Risk Management'),
        ('Dosen', 'Andi Pratama, M.T.'),
        ('Waktu', '23 Mei 2026 · 10:42 WITA'),
        ('Lokasi', 'Politani Samarinda · 12 m'),
        ('Status', 'Hadir'),
    ]
    ry = cy0 + 11
    for label, val in rows:
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 6.5)
        pdf.set_xy(SX + 7, ry)
        pdf.cell(28, 3, label)
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 6.5)
        pdf.set_xy(SX + 35, ry)
        pdf.cell(0, 3, val)
        ry += 6.5

    # Status badge
    pdf.fill('success_surface')
    pdf.rrect(SX + 35, ry - 8.5, 14, 4.5, 2, style='F')
    pdf.text_col('success')
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + 35, ry - 8)
    pdf.cell(14, 4, 'HADIR', align='C')

    # CTA buttons
    pdf.fill('primary')
    pdf.rrect(SX + 4, SY + SH - 22, SW - 8, 9, 2.5, style='F')
    pdf.text_col('white')
    pdf.set_font('Arial', 'B', 7.5)
    pdf.set_xy(SX + 4, SY + SH - 19.5)
    pdf.cell(SW - 8, 4, 'Kembali ke Beranda', align='C')

    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 6.5)
    pdf.set_xy(SX, SY + SH - 9)
    pdf.cell(SW, 4, 'Lihat Riwayat Kehadiran >', align='C')


def render_history_screen(pdf: MockupPDF):
    """Riwayat - filter sticky + heatmap + chart + record list."""
    pdf.draw_status_bar()
    pdf.draw_bottom_nav(active=2)

    y = SY + STATUS_BAR_H + 1

    # AppBar
    pdf.fill('surface')
    pdf.rect(SX, y, SW, 9, style='F')
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 9)
    pdf.set_xy(SX + 4, y + 2)
    pdf.cell(0, 4, 'Riwayat Kehadiran')
    pdf.icon('search', SX + SW - 8, y + 2.5, 4, 'text_primary')
    y += 10

    # Filter chips (sticky horizontal scroll)
    pdf.fill('surface_variant')
    pdf.rect(SX, y, SW, 9, style='F')
    pdf.set_xy(SX + 3, y + 2)
    chip_x = SX + 3
    chips = [('Bulan Ini', True), ('Semester', False), ('Semua MK', False)]
    for label, active in chips:
        pdf.set_font('Arial', 'B', 5.5)
        text_w = pdf.get_string_width(label) + 5
        if active:
            pdf.fill('primary')
            pdf.rrect(chip_x, y + 2, text_w, 4.5, 2.2, style='F')
            pdf.text_col('white')
        else:
            pdf.fill('surface')
            pdf.draw('border')
            pdf.set_line_width(0.15)
            pdf.rrect(chip_x, y + 2, text_w, 4.5, 2.2, style='DF')
            pdf.text_col('text_secondary')
        pdf.set_xy(chip_x, y + 1.7)
        pdf.cell(text_w, 4.5, label, align='C')
        chip_x += text_w + 2
    y += 11

    # Summary card with mini chart
    pdf.fill('primary')
    pdf.rrect(SX + 3, y, SW - 6, 28, 3, style='F')
    pdf.fill('primary_light')
    pdf.ellipse(SX + SW - 18, y - 8, 30, 20, style='F')
    pdf.fill('primary')
    pdf.rrect(SX + 3, y, SW - 6, 28, 3, style='F')

    pdf.text_col('white')
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + 6, y + 3)
    pdf.cell(0, 3, 'TINGKAT KEHADIRAN BULAN INI')
    pdf.set_font('Arial', 'B', 22)
    pdf.set_xy(SX + 6, y + 7)
    pdf.cell(0, 8, '92%')
    pdf.set_font('Arial', '', 6)
    pdf.set_xy(SX + 6, y + 17)
    pdf.cell(0, 3, '23 dari 25 pertemuan')

    # Mini bar chart on right
    chart_x = SX + SW - 30
    chart_y = y + 8
    pdf.set_fill_color(255, 255, 255)
    bars = [12, 15, 10, 18, 14, 16, 13]  # heights for 7 bars
    for i, h in enumerate(bars):
        pdf.set_fill_color(255, 255, 255)
        bar_y = chart_y + 14 - h * 0.7
        pdf.rect(chart_x + i * 3.2, bar_y, 2.5, h * 0.7, style='F')
    pdf.text_col('white')
    pdf.set_font('Arial', '', 5)
    pdf.set_xy(chart_x, y + 23)
    pdf.cell(25, 3, 'M T W T F S S', align='C')

    y += 32

    # Stats breakdown
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 7.5)
    pdf.set_xy(SX + 4, y)
    pdf.cell(0, 4, 'Ringkasan')
    y += 5

    breakdown = [
        ('check', 'Hadir', '23', 'success'),
        ('mail', 'Izin', '1', 'info'),
        ('plus', 'Sakit', '1', 'warning'),
        ('flag', 'Alpa', '0', 'danger'),
    ]
    bw = (SW - 6) / 4
    for i, (ic, lbl, val, col) in enumerate(breakdown):
        bx = SX + 3 + bw * i
        pdf.card(bx + 1, y, bw - 2, 18, fill='surface', border='border', radius=2.5)
        pdf.fill(f'{col}_surface' if f'{col}_surface' in COLORS else 'primary_surface')
        pdf.rrect(bx + (bw - 2) / 2 - 3 + 1, y + 2, 6, 6, 1.5, style='F')
        pdf.icon(ic, bx + (bw - 2) / 2 - 2 + 1, y + 3, 4, col)
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 9)
        pdf.set_xy(bx + 1, y + 9)
        pdf.cell(bw - 2, 4, val, align='C')
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(bx + 1, y + 13.5)
        pdf.cell(bw - 2, 3, lbl, align='C')

    y += 22

    # Records list
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 7.5)
    pdf.set_xy(SX + 4, y)
    pdf.cell(0, 4, 'Daftar Kehadiran')
    y += 5

    records = [
        ('Pemrograman Web', 'Pertemuan 5', '23 Mei · 09:30', 'Hadir', 'success', 'check'),
        ('Manajemen Proyek', 'Pertemuan 4', '22 Mei · 10:15', 'Hadir', 'success', 'check'),
        ('Basis Data Lanjut', 'Pertemuan 5', '21 Mei · 13:00', 'Izin', 'info', 'mail'),
        ('Pemrograman Web', 'Pertemuan 4', '20 Mei · 09:30', 'Hadir', 'success', 'check'),
    ]
    for name, sess, time, status, col, ic in records:
        if y > SY + SH - BOTTOM_NAV_H - 8:
            break
        pdf.card(SX + 3, y, SW - 6, 11, fill='surface', border='border', radius=2)
        pdf.fill(f'{col}_surface' if f'{col}_surface' in COLORS else 'primary_surface')
        pdf.rrect(SX + 5, y + 2, 6.5, 6.5, 1.8, style='F')
        pdf.icon(ic, SX + 5.5, y + 2.5, 5.5, col)
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 6.5)
        pdf.set_xy(SX + 13, y + 1.8)
        pdf.cell(0, 3, name)
        pdf.text_col('text_tertiary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(SX + 13, y + 5)
        pdf.cell(0, 3, f'{sess}  ·  {time}')
        # Status chip
        pdf.set_font('Arial', 'B', 5.5)
        text_w = pdf.get_string_width(status.upper()) + 4
        pdf.fill(f'{col}_surface' if f'{col}_surface' in COLORS else 'primary_surface')
        pdf.rrect(SX + SW - 5 - text_w, y + 3.5, text_w, 4, 2, style='F')
        pdf.text_col(col)
        pdf.set_xy(SX + SW - 5 - text_w, y + 3.2)
        pdf.cell(text_w, 4, status.upper(), align='C')
        y += 12.5


def render_history_detail_sheet(pdf: MockupPDF):
    """Riwayat dengan bottom sheet detail (overlay)."""
    # First render history screen as background (dimmed)
    render_history_screen(pdf)

    # Dim overlay
    pdf.set_fill_color(0, 0, 0)
    pdf.rect(SX, SY + STATUS_BAR_H, SW, SH - STATUS_BAR_H - BOTTOM_NAV_H, style='F')

    # Bottom sheet
    sheet_h = 92
    sheet_y = SY + SH - BOTTOM_NAV_H - sheet_h
    pdf.fill('surface')
    # Draw with only top corners rounded
    pdf.rect(SX, sheet_y, SW, sheet_h, style='F',
             round_corners=('TOP_LEFT', 'TOP_RIGHT'), corner_radius=4)

    # Drag handle
    pdf.fill('border')
    pdf.rrect(SX + (SW - 12) / 2, sheet_y + 2.5, 12, 1.2, 0.6, style='F')

    # Header
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 10)
    pdf.set_xy(SX + 4, sheet_y + 6)
    pdf.cell(0, 4, 'Pemrograman Web')
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 6.5)
    pdf.set_xy(SX + 4, sheet_y + 11)
    pdf.cell(0, 3, 'Pertemuan 5 - Database Integration')

    # Status big chip
    pdf.fill('success_surface')
    pdf.rrect(SX + 4, sheet_y + 16, 16, 5, 2.5, style='F')
    pdf.text_col('success')
    pdf.set_font('Arial', 'B', 6.5)
    pdf.set_xy(SX + 4, sheet_y + 16.3)
    pdf.cell(16, 4.5, 'HADIR', align='C')

    pdf.hline(SX + 4, sheet_y + 24, SX + SW - 4)

    # Detail rows
    rows = [
        ('Tanggal', '23 Mei 2026'),
        ('Jam Submit', '09:32 WITA'),
        ('Dosen', 'Dr. Indah Sari'),
        ('Lokasi', 'Politani · 8 meter'),
        ('Verifikasi', 'GPS + QR + Wajah OK'),
        ('Catatan', '-'),
    ]
    ry = sheet_y + 27
    for label, val in rows:
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 6.5)
        pdf.set_xy(SX + 4, ry)
        pdf.cell(28, 3, label)
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 6.5)
        pdf.set_xy(SX + 32, ry)
        pdf.cell(0, 3, val)
        ry += 6

    # Action button
    pdf.fill('primary_surface')
    pdf.rrect(SX + 4, sheet_y + sheet_h - 11, SW - 8, 7, 2, style='F')
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 6.5)
    pdf.set_xy(SX + 4, sheet_y + sheet_h - 9)
    pdf.cell(SW - 8, 3, 'Tutup', align='C')


def render_notification_screen(pdf: MockupPDF):
    """Notifikasi - tabs All/Unread + group per tanggal."""
    pdf.draw_status_bar()
    pdf.draw_bottom_nav(active=3)

    y = SY + STATUS_BAR_H + 1

    # AppBar
    pdf.fill('surface')
    pdf.rect(SX, y, SW, 9, style='F')
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 9)
    pdf.set_xy(SX + 4, y + 2)
    pdf.cell(0, 4, 'Notifikasi')
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + SW - 32, y + 2.5)
    pdf.cell(28, 3, 'Tandai semua', align='R')
    y += 10

    # Tabs
    pdf.fill('surface')
    pdf.rect(SX, y, SW, 8, style='F')
    pdf.draw('border')
    pdf.set_line_width(0.1)
    pdf.line(SX, y + 8, SX + SW, y + 8)
    # Active tab: Semua
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 7)
    pdf.set_xy(SX, y + 1)
    pdf.cell(SW / 2, 5, 'Semua  · 12', align='C')
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', 'B', 7)
    pdf.set_xy(SX + SW / 2, y + 1)
    pdf.cell(SW / 2, 5, 'Belum Dibaca · 3', align='C')
    # Active indicator
    pdf.fill('primary')
    pdf.rect(SX + SW / 4 - 8, y + 7, 16, 0.8, style='F')
    y += 10

    # Group: Hari Ini
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + 4, y)
    pdf.cell(0, 3, 'HARI INI')
    y += 4

    notifs = [
        ('check', 'success', 'Presensi tercatat', 'Pertemuan 5 - Pemrograman Web. Status: Hadir.', '5 menit lalu', True),
        ('bell', 'primary', 'Sesi baru dibuka', 'Manajemen Proyek TI · Pertemuan 6 telah dimulai. Segera scan QR.', '20 menit lalu', True),
        ('document', 'warning', 'Pengajuan izin disetujui', 'Izin sakit tanggal 22 Mei 2026 telah disetujui oleh dosen.', '2 jam lalu', True),
    ]
    for ic, col, title, msg, time, unread in notifs:
        bg = 'primary_surface' if unread else 'surface'
        border = 'primary' if unread else 'border'
        pdf.fill(bg)
        pdf.draw(border)
        pdf.set_line_width(0.2 if unread else 0.15)
        pdf.rrect(SX + 3, y, SW - 6, 18, 2.5, style='DF')
        # Icon
        pdf.fill(f'{col}_surface' if f'{col}_surface' in COLORS else 'primary_surface')
        pdf.rrect(SX + 5, y + 2, 7, 7, 2, style='F')
        pdf.icon(ic, SX + 5.5, y + 2.5, 6, col)
        # Content
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 7)
        pdf.set_xy(SX + 14, y + 1.8)
        pdf.cell(0, 3, title)
        # Unread dot
        if unread:
            pdf.fill('primary')
            pdf.ellipse(SX + SW - 8, y + 2.5, 1.6, 1.6, style='F')
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(SX + 14, y + 5)
        pdf.multi_cell(SW - 18, 2.6, msg)
        pdf.text_col('text_tertiary')
        pdf.set_font('Arial', '', 5)
        pdf.set_xy(SX + 14, y + 13.5)
        pdf.cell(0, 3, time)
        y += 20

    # Group: Kemarin
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + 4, y)
    pdf.cell(0, 3, 'KEMARIN')
    y += 4

    notifs2 = [
        ('plus', 'info', 'Pengingat: Sesi besok', 'Pertemuan 6 PBL akan dimulai pukul 08:00 WITA.', 'Kemarin', False),
    ]
    for ic, col, title, msg, time, unread in notifs2:
        if y > SY + SH - BOTTOM_NAV_H - 6:
            break
        pdf.card(SX + 3, y, SW - 6, 16, fill='surface', border='border', radius=2.5)
        pdf.fill(f'{col}_surface' if f'{col}_surface' in COLORS else 'primary_surface')
        pdf.rrect(SX + 5, y + 2, 6.5, 6.5, 1.8, style='F')
        pdf.icon(ic, SX + 5.5, y + 2.5, 5.5, col)
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 6.5)
        pdf.set_xy(SX + 13, y + 1.8)
        pdf.cell(0, 3, title)
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(SX + 13, y + 5)
        pdf.multi_cell(SW - 17, 2.5, msg)
        pdf.text_col('text_tertiary')
        pdf.set_font('Arial', '', 5)
        pdf.set_xy(SX + 13, y + 11.5)
        pdf.cell(0, 3, time)
        y += 18


def render_profile_screen(pdf: MockupPDF):
    """Profil - cover banner + avatar + stats + grouped menu."""
    pdf.draw_status_bar()
    pdf.draw_bottom_nav(active=4)

    y = SY + STATUS_BAR_H + 1

    # Cover banner
    cover_h = 38
    pdf.fill('primary')
    pdf.rect(SX, y, SW, cover_h, style='F')
    # Decoration arc
    pdf.fill('primary_light')
    pdf.ellipse(SX - 15, y - 10, 60, 30, style='F')
    pdf.fill('primary_dark')
    pdf.ellipse(SX + SW - 25, y + 18, 50, 30, style='F')
    pdf.fill('primary')
    pdf.rect(SX, y + 22, SW, cover_h - 22, style='F')

    # Settings icon
    pdf.icon('settings', SX + SW - 9, y + 4, 5, 'white')

    # Avatar (large, overlapping cover)
    avatar_size = 22
    ax = SX + (SW - avatar_size) / 2
    ay = y + cover_h - avatar_size / 2 - 4
    # Outer white ring
    pdf.fill('white')
    pdf.ellipse(ax - 1.5, ay - 1.5, avatar_size + 3, avatar_size + 3, style='F')
    pdf.fill('primary')
    pdf.ellipse(ax, ay, avatar_size, avatar_size, style='F')
    pdf.text_col('white')
    pdf.set_font('Arial', 'B', 11)
    pdf.set_xy(ax, ay + 7)
    pdf.cell(avatar_size, 6, 'RA', align='C')

    # Name + NIM
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 11)
    pdf.set_xy(SX, ay + avatar_size + 2)
    pdf.cell(SW, 5, 'Riki Andriawan', align='C')
    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 7)
    pdf.set_xy(SX, ay + avatar_size + 7)
    pdf.cell(SW, 3, '23222048 · TRPL Semester 6', align='C')

    # Verified badge
    pdf.fill('success_surface')
    pdf.rrect(SX + (SW - 24) / 2, ay + avatar_size + 11, 24, 4.5, 2.2, style='F')
    pdf.text_col('success')
    pdf.set_font('Arial', 'B', 5.5)
    pdf.set_xy(SX + (SW - 24) / 2, ay + avatar_size + 11.2)
    pdf.cell(24, 4.5, 'WAJAH TERVERIFIKASI', align='C')

    y = ay + avatar_size + 19

    # Mini stats
    pdf.fill('surface')
    pdf.draw('border')
    pdf.set_line_width(0.15)
    pdf.rrect(SX + 4, y, SW - 8, 14, 2.5, style='DF')
    stats = [('92%', 'Kehadiran'), ('25', 'Sesi'), ('5', 'Mata Kuliah')]
    sw_w = (SW - 8) / 3
    for i, (val, lbl) in enumerate(stats):
        sx = SX + 4 + sw_w * i
        if i > 0:
            pdf.draw('divider')
            pdf.set_line_width(0.15)
            pdf.line(sx, y + 2, sx, y + 12)
        pdf.text_col('primary')
        pdf.set_font('Arial', 'B', 9)
        pdf.set_xy(sx, y + 2)
        pdf.cell(sw_w, 4, val, align='C')
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(sx, y + 8)
        pdf.cell(sw_w, 3, lbl, align='C')

    y += 18

    # Menu groups
    menu_groups = [
        ('AKUN', [
            ('class', 'Informasi Mata Kuliah', '5 MK aktif', 'primary'),
            ('document', 'Pengajuan Izin / Sakit', '1 pending', 'warning'),
            ('face', 'Verifikasi Wajah', 'Aktif', 'success'),
        ]),
        ('PENGATURAN', [
            ('bell', 'Notifikasi', 'On', 'info'),
            ('help', 'Bantuan & FAQ', '', 'text_secondary'),
            ('logout', 'Keluar dari Akun', '', 'danger'),
        ]),
    ]
    for group_name, items in menu_groups:
        pdf.text_col('text_tertiary')
        pdf.set_font('Arial', 'B', 5.5)
        pdf.set_xy(SX + 4, y)
        pdf.cell(0, 3, group_name)
        y += 4

        pdf.card(SX + 3, y, SW - 6, len(items) * 9, fill='surface', border='border', radius=2.5)
        for i, (ic, label, hint, col) in enumerate(items):
            iy = y + i * 9
            if i > 0:
                pdf.hline(SX + 9, iy, SX + SW - 5, color='divider')
            pdf.icon(ic, SX + 6, iy + 2.5, 4.5, col)
            pdf.text_col('text_primary')
            pdf.set_font('Arial', 'B', 6.5)
            pdf.set_xy(SX + 13, iy + 3)
            pdf.cell(0, 3, label)
            if hint:
                pdf.text_col('text_tertiary')
                pdf.set_font('Arial', '', 5.5)
                pdf.set_xy(SX + SW - 28, iy + 3.2)
                pdf.cell(20, 3, hint, align='R')
            pdf.icon('chevron_right', SX + SW - 8, iy + 3, 3, 'text_tertiary')
        y += len(items) * 9 + 3


def render_leave_list_screen(pdf: MockupPDF):
    """Pengajuan Izin - list of submitted requests + FAB."""
    pdf.draw_status_bar()

    y = SY + STATUS_BAR_H + 1

    # AppBar
    pdf.fill('surface')
    pdf.rect(SX, y, SW, 9, style='F')
    # Back arrow
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 9)
    pdf.set_xy(SX + 3, y + 1.8)
    pdf.cell(5, 4, '<')
    pdf.set_xy(SX + 9, y + 2)
    pdf.cell(0, 4, 'Pengajuan Izin')
    y += 12

    # Summary mini cards
    summaries = [
        ('1', 'Pending', 'warning'),
        ('3', 'Disetujui', 'success'),
        ('0', 'Ditolak', 'danger'),
    ]
    sw_w = (SW - 6) / 3
    for i, (val, lbl, col) in enumerate(summaries):
        sx = SX + 3 + sw_w * i
        pdf.card(sx + 1, y, sw_w - 2, 16, fill='surface', border='border', radius=2.5)
        pdf.text_col(col)
        pdf.set_font('Arial', 'B', 11)
        pdf.set_xy(sx + 1, y + 2)
        pdf.cell(sw_w - 2, 4, val, align='C')
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(sx + 1, y + 9)
        pdf.cell(sw_w - 2, 3, lbl, align='C')
    y += 20

    # Section title
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 8)
    pdf.set_xy(SX + 4, y)
    pdf.cell(0, 4, 'Riwayat Pengajuan')
    y += 6

    requests = [
        ('Sakit', 'Manajemen Proyek TI', '22 Mei 2026', 'Pending', 'warning'),
        ('Izin', 'Pemrograman Web', '20 Mei 2026', 'Disetujui', 'success'),
        ('Izin', 'Basis Data Lanjut', '18 Mei 2026', 'Disetujui', 'success'),
        ('Sakit', 'Algoritma & Struktur Data', '15 Mei 2026', 'Disetujui', 'success'),
    ]
    for kind, course, date, status, col in requests:
        if y > SY + SH - 22:
            break
        pdf.card(SX + 3, y, SW - 6, 14, fill='surface', border='border', radius=2.5)
        # Type badge
        pdf.fill(f'{col}_surface' if f'{col}_surface' in COLORS else 'primary_surface')
        pdf.rrect(SX + 5, y + 2, 12, 4.5, 2.2, style='F')
        pdf.text_col(col)
        pdf.set_font('Arial', 'B', 5.5)
        pdf.set_xy(SX + 5, y + 1.7)
        pdf.cell(12, 4.5, kind.upper(), align='C')
        # Course
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 6.5)
        pdf.set_xy(SX + 19, y + 2)
        pdf.cell(0, 3, course)
        pdf.text_col('text_tertiary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(SX + 19, y + 5.5)
        pdf.cell(0, 3, date)
        # Status chip
        pdf.set_font('Arial', 'B', 5.5)
        text_w = pdf.get_string_width(status.upper()) + 4
        pdf.fill(f'{col}_surface' if f'{col}_surface' in COLORS else 'primary_surface')
        pdf.rrect(SX + SW - 5 - text_w, y + 9, text_w, 4, 2, style='F')
        pdf.text_col(col)
        pdf.set_xy(SX + SW - 5 - text_w, y + 8.7)
        pdf.cell(text_w, 4, status.upper(), align='C')
        # Chevron
        pdf.icon('chevron_right', SX + SW - 7, y + 3, 3, 'text_tertiary')
        y += 16

    # FAB (Floating Action Button)
    fab_size = 13
    fab_x = SX + SW - fab_size - 4
    fab_y = SY + SH - fab_size - 6
    pdf.fill('primary_dark')
    pdf.ellipse(fab_x + 0.5, fab_y + 1, fab_size, fab_size, style='F')  # shadow
    pdf.fill('primary')
    pdf.ellipse(fab_x, fab_y, fab_size, fab_size, style='F')
    pdf.icon('plus', fab_x + 4, fab_y + 4, 5, 'white')


def render_leave_form_screen(pdf: MockupPDF):
    """Pengajuan Izin - Form submission."""
    pdf.draw_status_bar()

    y = SY + STATUS_BAR_H + 1

    # AppBar
    pdf.fill('surface')
    pdf.rect(SX, y, SW, 9, style='F')
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 9)
    pdf.set_xy(SX + 3, y + 1.8)
    pdf.cell(5, 4, '<')
    pdf.set_xy(SX + 9, y + 2)
    pdf.cell(0, 4, 'Ajukan Izin / Sakit')
    y += 12

    # Type selector (segmented control)
    pdf.fill('surface_variant')
    pdf.rrect(SX + 3, y, SW - 6, 9, 2, style='F')
    seg_w = (SW - 6) / 2
    # Active: Izin
    pdf.fill('primary')
    pdf.rrect(SX + 3.5, y + 0.5, seg_w - 0.5, 8, 2, style='F')
    pdf.text_col('white')
    pdf.set_font('Arial', 'B', 7)
    pdf.set_xy(SX + 3, y + 1)
    pdf.cell(seg_w, 5, 'Izin', align='C')
    pdf.text_col('text_secondary')
    pdf.set_xy(SX + 3 + seg_w, y + 1)
    pdf.cell(seg_w, 5, 'Sakit', align='C')
    y += 12

    # Course dropdown
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 7)
    pdf.set_xy(SX + 3, y)
    pdf.cell(0, 3, 'Mata Kuliah')
    y += 4
    pdf.fill('surface')
    pdf.draw('border')
    pdf.set_line_width(0.15)
    pdf.rrect(SX + 3, y, SW - 6, 9, 2.2, style='DF')
    pdf.text_col('text_primary')
    pdf.set_font('Arial', '', 6.5)
    pdf.set_xy(SX + 6, y + 2.5)
    pdf.cell(0, 4, 'Pemrograman Web')
    pdf.icon('chevron_down', SX + SW - 9, y + 2, 4, 'text_tertiary')
    y += 12

    # Date picker
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 7)
    pdf.set_xy(SX + 3, y)
    pdf.cell(0, 3, 'Tanggal Izin')
    y += 4
    pdf.fill('surface')
    pdf.draw('border')
    pdf.rrect(SX + 3, y, SW - 6, 9, 2.2, style='DF')
    pdf.icon('calendar', SX + 5, y + 2, 5, 'text_tertiary')
    pdf.text_col('text_primary')
    pdf.set_font('Arial', '', 6.5)
    pdf.set_xy(SX + 11, y + 2.5)
    pdf.cell(0, 4, '23 Mei 2026')
    y += 12

    # Reason textarea
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 7)
    pdf.set_xy(SX + 3, y)
    pdf.cell(0, 3, 'Alasan')
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 5.5)
    pdf.set_xy(SX + SW - 22, y)
    pdf.cell(20, 3, '0/200', align='R')
    y += 4
    pdf.fill('surface')
    pdf.draw('border')
    pdf.rrect(SX + 3, y, SW - 6, 24, 2.2, style='DF')
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 6.5)
    pdf.set_xy(SX + 5, y + 2.5)
    pdf.cell(0, 4, 'Tulis alasan singkat (mis. acara keluarga,')
    pdf.set_xy(SX + 5, y + 6)
    pdf.cell(0, 4, 'periksa dokter, dll)')
    y += 27

    # File upload (lampiran)
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 7)
    pdf.set_xy(SX + 3, y)
    pdf.cell(0, 3, 'Lampiran (opsional)')
    y += 4
    pdf.fill('primary_surface')
    pdf.draw('primary')
    pdf.set_line_width(0.2)
    pdf.rrect(SX + 3, y, SW - 6, 14, 2.2, style='DF')
    pdf.icon('document', SX + (SW - 6) / 2 - 2, y + 2, 4.5, 'primary')
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 6.5)
    pdf.set_xy(SX + 3, y + 7)
    pdf.cell(SW - 6, 3, 'Tap untuk upload file', align='C')
    pdf.text_col('text_tertiary')
    pdf.set_font('Arial', '', 5)
    pdf.set_xy(SX + 3, y + 10.5)
    pdf.cell(SW - 6, 2.5, 'JPG, PNG, atau PDF · maks 2 MB', align='C')
    y += 18

    # Submit button (sticky bottom)
    pdf.fill('primary')
    pdf.rrect(SX + 3, SY + SH - 14, SW - 6, 10, 3, style='F')
    pdf.text_col('white')
    pdf.set_font('Arial', 'B', 8)
    pdf.set_xy(SX + 3, SY + SH - 11.5)
    pdf.cell(SW - 6, 4, 'Kirim Pengajuan', align='C')


def render_face_registration_screen(pdf: MockupPDF):
    """Pendaftaran Wajah - guided pose dengan circle frame."""
    # Dark background
    pdf.fill('text_primary')
    pdf.rect(SX, SY + STATUS_BAR_H, SW, SH - STATUS_BAR_H, style='F')

    # Status bar (light)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Arial', 'B', 6)
    pdf.set_xy(SX + 4, SY + 1.8)
    pdf.cell(20, 3, '09:41')

    # Top bar
    pdf.set_fill_color(255, 255, 255)
    # Back button
    pdf.set_fill_color(60, 60, 60)
    pdf.rrect(SX + 3, SY + 8, 7, 7, 2, style='F')
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Arial', 'B', 9)
    pdf.set_xy(SX + 3, SY + 9.5)
    pdf.cell(7, 4, '<', align='C')
    # Title
    pdf.set_xy(SX, SY + 9)
    pdf.cell(SW, 5, 'Daftarkan Wajah', align='C')

    # Step indicator
    pdf.set_fill_color(255, 255, 255)
    pdf.set_xy(SX, SY + 18)
    pdf.set_text_color(200, 200, 200)
    pdf.set_font('Arial', '', 5.5)
    pdf.cell(SW, 3, 'Langkah 1 dari 4', align='C')

    # Progress bar
    bar_y = SY + 23
    pdf.fill('text_secondary')
    pdf.set_fill_color(60, 60, 60)
    pdf.rrect(SX + 12, bar_y, SW - 24, 1.5, 0.7, style='F')
    pdf.fill('primary')
    pdf.rrect(SX + 12, bar_y, (SW - 24) * 0.25, 1.5, 0.7, style='F')

    # Face frame (circle) center
    fx = SX + SW / 2
    fy = SY + 75
    radius = 25
    # Outer guide ring (subtle)
    pdf.set_draw_color(255, 255, 255)
    pdf.set_line_width(0.3)
    pdf.ellipse(fx - radius - 2, fy - radius - 2, radius * 2 + 4, radius * 2 + 4, style='D')
    # Active ring
    pdf.set_draw_color(*hex_to_rgb(COLORS['primary']))
    pdf.set_line_width(1.2)
    pdf.ellipse(fx - radius, fy - radius, radius * 2, radius * 2, style='D')

    # Mock face silhouette inside
    pdf.set_fill_color(40, 40, 40)
    pdf.ellipse(fx - radius + 4, fy - radius + 4, (radius - 4) * 2, (radius - 4) * 2, style='F')
    # Mock face features (simple)
    pdf.set_fill_color(80, 80, 80)
    pdf.ellipse(fx - 7, fy - 7, 3, 3.5, style='F')  # left eye
    pdf.ellipse(fx + 4, fy - 7, 3, 3.5, style='F')  # right eye
    pdf.set_draw_color(80, 80, 80)
    pdf.set_line_width(0.4)
    pdf.line(fx - 5, fy + 5, fx + 5, fy + 5)  # mouth

    # Step labels (4 chips)
    step_y = fy + radius + 8
    steps = [
        ('Lurus', True),
        ('Kedip', False),
        ('Kiri', False),
        ('Kanan', False),
    ]
    chip_w = 17
    for i, (label, active) in enumerate(steps):
        chip_x = SX + (SW - (chip_w * 4 + 6)) / 2 + i * (chip_w + 2)
        if active:
            pdf.fill('primary')
            pdf.rrect(chip_x, step_y, chip_w, 6, 3, style='F')
            pdf.text_col('white')
        else:
            pdf.set_fill_color(50, 50, 50)
            pdf.rrect(chip_x, step_y, chip_w, 6, 3, style='F')
            pdf.set_text_color(140, 140, 140)
        pdf.set_font('Arial', 'B', 5.5)
        pdf.set_xy(chip_x, step_y + 0.5)
        pdf.cell(chip_w, 5, label, align='C')

    # Instruction card
    card_y = step_y + 14
    pdf.fill('surface')
    pdf.rrect(SX + 5, card_y, SW - 10, 38, 3, style='F')

    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 8)
    pdf.set_xy(SX + 5, card_y + 4)
    pdf.cell(SW - 10, 4, 'Hadapkan Wajah Lurus', align='C')

    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 6)
    pdf.set_xy(SX + 8, card_y + 10)
    pdf.multi_cell(SW - 16, 3, 'Posisikan wajah Anda di dalam lingkaran. Pastikan pencahayaan cukup dan tidak ada penghalang seperti masker atau topi.')

    # Capture button
    pdf.fill('primary')
    pdf.rrect(SX + 8, card_y + 26, SW - 16, 8, 3, style='F')
    pdf.text_col('white')
    pdf.set_font('Arial', 'B', 7)
    pdf.set_xy(SX + 8, card_y + 28.5)
    pdf.cell(SW - 16, 3, 'Mulai Capture', align='C')


def render_empty_states(pdf: MockupPDF):
    """Empty state variants - 3 mini phones in one page."""
    pdf.add_page()
    pdf.page_header(11, 'Empty State Variants')

    # Subtitle
    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 9)
    pdf.set_xy(MARGIN, 30)
    pdf.multi_cell(PAGE_W - 2 * MARGIN, 4,
                   'Setiap halaman wajib punya empty state ramah dengan ilustrasi geometris konsisten, '
                   'judul jelas, deskripsi pendek, dan CTA jika relevan. Berikut variasi yang dipakai di '
                   'history, notifikasi, jadwal kosong, dan pengajuan kosong.')

    # 3 phones side by side
    mini_w = 56
    mini_h = 110
    mini_radius = 5
    mini_bezel = 1
    spacing = (PAGE_W - 2 * MARGIN - 3 * mini_w) / 2
    base_y = 50

    variants = [
        ('Belum Ada Riwayat', 'Riwayat presensi akan muncul setelah Anda scan QR pertama.', 'Mulai Scan QR', 'history'),
        ('Belum Ada Notifikasi', 'Notifikasi dari dosen dan sistem akan muncul di sini.', 'Lihat Beranda', 'bell'),
        ('Belum Ada Pengajuan', 'Belum ada pengajuan izin/sakit. Tap tombol di bawah untuk mengajukan.', 'Ajukan Sekarang', 'document'),
    ]

    for idx, (title, desc, cta, ic) in enumerate(variants):
        px = MARGIN + idx * (mini_w + spacing)
        py = base_y

        # Bezel
        pdf.fill('bezel')
        pdf.rrect(px, py, mini_w, mini_h, mini_radius, style='F')
        # Screen
        pdf.fill('background')
        msx = px + mini_bezel
        msy = py + mini_bezel
        msw = mini_w - 2 * mini_bezel
        msh = mini_h - 2 * mini_bezel
        pdf.rrect(msx, msy, msw, msh, mini_radius - mini_bezel, style='F')

        # Notch
        pdf.fill('bezel')
        pdf.rrect(msx + msw / 2 - 6, msy + 0.4, 12, 1.6, 0.8, style='F')

        # Status bar
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 5)
        pdf.set_xy(msx + 2, msy + 1.2)
        pdf.cell(15, 2, '09:41')

        # AppBar
        pdf.fill('surface')
        pdf.rect(msx, msy + 5, msw, 6, style='F')
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 6.5)
        pdf.set_xy(msx + 3, msy + 6)
        pdf.cell(0, 3, title.split(' ', 1)[1] if ' ' in title else title)

        # Big illustration container (geometric)
        ill_y = msy + 30
        pdf.fill('primary_surface')
        pdf.ellipse(msx + msw / 2 - 18, ill_y - 18, 36, 36, style='F')
        pdf.fill('surface')
        pdf.ellipse(msx + msw / 2 - 12, ill_y - 12, 24, 24, style='F')
        # Icon centered
        pdf.icon(ic, msx + msw / 2 - 4, ill_y - 4, 8, 'primary')

        # Title
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 7)
        pdf.set_xy(msx, ill_y + 22)
        pdf.cell(msw, 4, title, align='C')

        # Description
        pdf.text_col('text_secondary')
        pdf.set_font('Arial', '', 5.5)
        pdf.set_xy(msx + 3, ill_y + 28)
        pdf.multi_cell(msw - 6, 2.8, desc, align='C')

        # CTA button
        cta_w = msw - 8
        cta_x = msx + 4
        cta_y = msy + msh - 14
        pdf.fill('primary')
        pdf.rrect(cta_x, cta_y, cta_w, 7, 2.2, style='F')
        pdf.text_col('white')
        pdf.set_font('Arial', 'B', 6)
        pdf.set_xy(cta_x, cta_y + 1.7)
        pdf.cell(cta_w, 3.5, cta, align='C')

        # Variant label (below phone)
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 8)
        pdf.set_xy(px, py + mini_h + 3)
        pdf.cell(mini_w, 4, ['Riwayat Kosong', 'Notifikasi Kosong', 'Pengajuan Kosong'][idx], align='C')

    # Design principle box
    pdf.fill('warning_surface')
    pdf.draw('warning')
    pdf.set_line_width(0.2)
    pdf.rrect(MARGIN, base_y + mini_h + 25, PAGE_W - 2 * MARGIN, 50, 3, style='DF')

    pdf.text_col('warning')
    pdf.set_font('Arial', 'B', 10)
    pdf.set_xy(MARGIN + 6, base_y + mini_h + 30)
    pdf.cell(0, 5, 'Prinsip Empty State')
    pdf.text_col('text_primary')
    pdf.set_font('Arial', '', 8)
    pdf.set_xy(MARGIN + 6, base_y + mini_h + 38)
    pdf.multi_cell(PAGE_W - 2 * (MARGIN + 6), 4,
                   '1. Jangan tampilkan halaman benar-benar kosong - selalu beri ilustrasi + konteks.\n'
                   '2. Ilustrasi pakai geometric shape sederhana (lingkaran + icon) - JANGAN raster image yang berat.\n'
                   '3. Judul singkat (max 3 kata) menjelaskan apa yang kosong.\n'
                   '4. Deskripsi 1-2 kalimat menjelaskan KAPAN data akan muncul.\n'
                   '5. CTA mengarahkan ke aksi produktif berikutnya - JANGAN buntu.')

    pdf.page_footer()


# =====================================================================
# COMPOSE - fungsi pembungkus untuk render satu halaman dengan phone + annotation
# =====================================================================

def add_phone_page(pdf: MockupPDF, num, title, screen_renderer, annot_title, annot_subtitle, annot_sections):
    """Add page dengan 1 phone di kiri + annotation di kanan."""
    pdf.add_page()
    pdf.page_header(num, title)
    pdf.draw_phone_bezel()
    screen_renderer(pdf)
    pdf.draw_annotation(annot_title, annot_subtitle, annot_sections)
    pdf.page_footer()


def add_two_phone_page(pdf: MockupPDF, num, title, renderers, labels, annot):
    """Add page dengan 2 phone side-by-side + annotation di bawah."""
    pdf.add_page()
    pdf.page_header(num, title)

    # Save original phone position
    global PHONE_X, SX, CX
    orig_phone_x = PHONE_X
    orig_sx = SX
    orig_cx = CX

    # Phone 1 (left)
    PHONE_X = MARGIN + 8
    SX = PHONE_X + PHONE_BEZEL
    CX = SX
    pdf.draw_phone_bezel()
    renderers[0](pdf)
    # Label below phone 1
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 9)
    pdf.set_xy(PHONE_X, PHONE_Y + PHONE_H + 3)
    pdf.cell(PHONE_W, 4, labels[0], align='C')

    # Phone 2 (right)
    PHONE_X = PAGE_W - MARGIN - PHONE_W - 8
    SX = PHONE_X + PHONE_BEZEL
    CX = SX
    pdf.draw_phone_bezel()
    renderers[1](pdf)
    # Label below phone 2
    pdf.text_col('text_primary')
    pdf.set_font('Arial', 'B', 9)
    pdf.set_xy(PHONE_X, PHONE_Y + PHONE_H + 3)
    pdf.cell(PHONE_W, 4, labels[1], align='C')

    # Restore
    PHONE_X = orig_phone_x
    SX = orig_sx
    CX = orig_cx

    # Annotation below
    ann_y = PHONE_Y + PHONE_H + 12
    pdf.text_col('primary')
    pdf.set_font('Arial', 'B', 11)
    pdf.set_xy(MARGIN, ann_y)
    pdf.cell(0, 5, annot['title'])
    pdf.text_col('text_secondary')
    pdf.set_font('Arial', '', 8)
    pdf.set_xy(MARGIN, ann_y + 6)
    pdf.multi_cell(PAGE_W - 2 * MARGIN, 4, annot['subtitle'])

    y = pdf.get_y() + 3
    for sec in annot['sections']:
        pdf.text_col('text_primary')
        pdf.set_font('Arial', 'B', 9)
        pdf.set_xy(MARGIN, y)
        pdf.cell(0, 4, sec['title'])
        y += 5
        for item in sec['items']:
            pdf.text_col('primary')
            pdf.set_font('Arial', 'B', 7)
            pdf.set_xy(MARGIN, y)
            pdf.cell(2, 3.5, '·')
            pdf.text_col('text_secondary')
            pdf.set_font('Arial', '', 7.5)
            pdf.set_xy(MARGIN + 3, y)
            pdf.multi_cell(PAGE_W - 2 * MARGIN - 3, 3.3, item)
            y = pdf.get_y() + 0.5
        y += 1.5

    pdf.page_footer()


# =====================================================================
# MAIN
# =====================================================================

def main():
    pdf = MockupPDF()

    # Page 1: Cover
    render_cover(pdf)

    # Page 2: Design system
    render_design_system(pdf)

    # Page 3: Login
    add_phone_page(
        pdf, 3, 'Login Screen',
        render_login_screen,
        'Login',
        'Form sederhana dengan branding kuat. Background gradient halus primary_surface di area logo, card form putih dengan border subtle.',
        [
            {'title': 'Komponen Utama', 'items': [
                'Logo card 14×14mm dengan gradient primary + ikon sidik jari (fingerprint).',
                'Title display large + subtitle tertiary "TRPL · Politani".',
                'Form card dengan padding 16px, border 0.5px #E2E6EA, border-radius 16px.',
                'Input field: ikon prefix + placeholder, focus state border primary 1.5px.',
                'Tombol primary 52px height, border-radius 14px, font Plus Jakarta SemiBold.',
            ]},
            {'title': 'Behavior', 'items': [
                'Loading state: tombol berisi spinner 20×20 putih, disable input.',
                'Error: snackbar floating di bawah dengan icon danger + pesan ID.',
                'Force change password: GoRouter auto-redirect ke /change-password.',
                '"Lupa password?" link kanan-bawah field password (perlu diimplementasikan).',
            ]},
        ]
    )

    # Page 4: Home
    add_phone_page(
        pdf, 4, 'Beranda (Home)',
        render_home_screen,
        'Home / Beranda',
        'Layar utama yang padat informasi tanpa overload. Header kompak, stats ringkas, jadwal hari ini, sesi aktif spotlight, dan akses cepat 4 shortcut.',
        [
            {'title': 'Section', 'items': [
                'Header kompak (26mm): greeting + nama + NIM + bell + avatar mini.',
                'Stats card horizontal: 92% Kehadiran, 18 Hadir, 1 Izin (1 row, 3 column).',
                '"Jadwal Hari Ini": 2 timeline card dengan jam mulai-selesai, MK, ruang, status chip (Selesai/Berlangsung).',
                'Akses Cepat: 4 shortcut grid (Scan, Pengajuan, Wajah, Bantuan).',
                'Sesi Aktif spotlight: card primary_surface dengan countdown OTP + tombol "Scan QR Sekarang".',
            ]},
            {'title': 'Behavior', 'items': [
                'Pull-to-refresh invalidate authProvider + activeSessionsProvider.',
                'Stagger animation 100ms × 4 section (fade+slide).',
                'Greeting otomatis ganti per jam: Pagi/Siang/Sore/Malam.',
                'Jika tidak ada sesi aktif -> spotlight card hilang, "Akses Cepat" geser ke atas.',
                'Bell icon: badge dot merah jika ada notifikasi unread.',
            ]},
        ]
    )

    # Page 5: Scan QR
    add_phone_page(
        pdf, 5, 'Scan QR',
        render_scan_qr_screen,
        'Scan QR Presensi',
        'Full-screen camera dengan overlay frame. Corner bracket primary, scan line animasi, info card di bawah dengan instruksi & link bantuan.',
        [
            {'title': 'Komponen', 'items': [
                'Camera full-screen (mobile_scanner package, ResolutionPreset.normal).',
                'Top bar: back button + title pill + torch toggle (semua di-overlay dark 0.4).',
                'Frame scanner: 50×50mm dengan corner bracket primary 0.9mm tebal, length 7mm.',
                'Scan line horizontal animasi sliding atas-bawah dalam frame.',
                'Bottom info card surface dengan ikon QR + instruksi + link "Lihat panduan".',
            ]},
            {'title': 'Behavior', 'items': [
                'Auto-detect QR via mobile_scanner.onDetect - flag _isProcessing cegah double-scan.',
                'Setelah deteksi -> loading overlay "Mengambil GPS..." -> "Mengirim presensi..." -> push /attendance-result.',
                'QR tidak valid: snackbar danger + reset _isProcessing untuk scan ulang.',
                'Torch state diobservasi via ValueListenableBuilder untuk update warna ikon.',
            ]},
        ]
    )

    # Page 6: Attendance Result
    add_phone_page(
        pdf, 6, 'Hasil Presensi',
        render_attendance_result,
        'Konfirmasi Presensi',
        'Layar konfirmasi visual dengan animasi check mark + detail lengkap presensi yang baru tercatat. Memberikan rasa berhasil dan transparan.',
        [
            {'title': 'Komponen', 'items': [
                'Success badge: 3 lingkaran konsentris (success_surface -> white -> success) + check mark putih tebal.',
                'Title "Presensi Berhasil!" display medium primary text + subtitle secondary.',
                'Detail card: 6 row (MK, Pertemuan, Dosen, Waktu, Lokasi, Status) dengan label kiri + value kanan.',
                'Status badge "HADIR" success_surface chip.',
                'CTA primer "Kembali ke Beranda" + secondary text "Lihat Riwayat >".',
            ]},
            {'title': 'Behavior', 'items': [
                'Animasi: lingkaran scale-in 400ms easeOutCubic + check stroke 300ms delay.',
                'Detail diisi dari response /api/mobile/attendance/submit (server hitung distance Haversine).',
                'Tombol "Kembali ke Beranda" -> context.go("/") + reset attendanceSubmitProvider.',
                'Auto-haptic feedback (HapticFeedback.heavyImpact) saat layar muncul.',
            ]},
        ]
    )

    # Page 7: Riwayat
    add_phone_page(
        pdf, 7, 'Riwayat Kehadiran',
        render_history_screen,
        'Riwayat',
        'Halaman riwayat dengan filter sticky, summary card berisi mini bar chart, breakdown per status, dan daftar record yang ringkas.',
        [
            {'title': 'Komponen', 'items': [
                'AppBar: title "Riwayat Kehadiran" + ikon search.',
                'Filter chip horizontal scroll: Bulan Ini (active) / Semester / Semua MK / + filter dropdown.',
                'Summary card primary: 92% besar + label "23 dari 25 pertemuan" + mini bar chart 7 hari.',
                'Breakdown 4 grid: Hadir / Izin / Sakit / Alpa (dengan ikon + count).',
                'Daftar record: 11mm height per row, ikon status + nama MK + pertemuan + waktu + status chip.',
            ]},
            {'title': 'Behavior', 'items': [
                'Filter chip mengubah summary + chart + record (server-side filter via query param).',
                'Tap record -> bottom sheet detail (lihat halaman 8).',
                'Search bar: filter by nama MK atau tanggal.',
                'Pull-to-refresh invalidate historyProvider.',
                'Empty state ramah jika filter tidak ada hasil.',
            ]},
        ]
    )

    # Page 8: Riwayat Detail Bottom Sheet
    add_phone_page(
        pdf, 8, 'Detail Riwayat (Bottom Sheet)',
        render_history_detail_sheet,
        'Bottom Sheet Detail',
        'Saat user tap record di Riwayat, muncul modal bottom sheet (bukan navigate ke screen baru) berisi info lengkap. Lebih cepat & menjaga konteks.',
        [
            {'title': 'Komponen', 'items': [
                'Drag handle 12×1.2mm di atas sheet untuk indikasi swipe-to-dismiss.',
                'Header: nama MK + pertemuan + topik (jika ada).',
                'Status chip besar: HADIR / IZIN / SAKIT / ALPA dengan warna sesuai.',
                '6 row detail: Tanggal, Jam Submit, Dosen, Lokasi (+jarak), Verifikasi (GPS+QR+Wajah), Catatan.',
                'Tombol Tutup primary_surface di bawah sheet.',
            ]},
            {'title': 'Behavior', 'items': [
                'Dismiss: swipe down / tap luar sheet / tombol Tutup.',
                'Background dim hitam alpha 0.5 + content tap-through ke history list.',
                'Animasi: slide-up 300ms easeOutCubic dari bawah.',
                'Sheet menampilkan max-height 60% screen height.',
                'Implementasi via showModalBottomSheet di Flutter dengan custom shape.',
            ]},
        ]
    )

    # Page 9: Notifikasi
    add_phone_page(
        pdf, 9, 'Notifikasi',
        render_notification_screen,
        'Notifikasi',
        'Tab Semua/Belum Dibaca dengan group per tanggal. Card unread punya background primary_surface + border primary. Action "Tandai semua".',
        [
            {'title': 'Komponen', 'items': [
                'AppBar: title + action "Tandai semua" link primary di kanan.',
                'Tabs 2 segmen: "Semua · 12" (active) / "Belum Dibaca · 3" - indikator bawah primary 0.8mm.',
                'Group header text_tertiary uppercase: "HARI INI", "KEMARIN", "MINGGU INI".',
                'Card unread: bg primary_surface + border primary + dot kecil primary di kanan-atas.',
                'Card read: bg surface + border subtle.',
                'Per card: ikon type (success/warning/info) + title bold + message 2-line + waktu relatif.',
            ]},
            {'title': 'Behavior', 'items': [
                'Tap card unread -> mark read otomatis + navigate ke deep link sesuai type.',
                'Swipe left -> action "Hapus" (slide reveal red).',
                'Swipe right -> action "Tandai sudah dibaca" (slide reveal primary).',
                'Pull-to-refresh fetch notifikasi terbaru.',
                'Realtime update via Supabase realtime channel (perlu diimplementasikan).',
            ]},
        ]
    )

    # Page 10: Profil
    add_phone_page(
        pdf, 10, 'Profil',
        render_profile_screen,
        'Profil',
        'Cover banner primary + avatar overlap + verified badge. Mini stats (Kehadiran, Sesi, MK). Menu grouped: Akun + Pengaturan.',
        [
            {'title': 'Komponen', 'items': [
                'Cover banner 38mm: primary dengan dekorasi ellipse halus (primary_light + primary_dark).',
                'Settings ikon kanan atas (link ke pengaturan).',
                'Avatar besar 22mm dengan ring putih 1.5mm overlap di bottom cover.',
                'Nama display medium + NIM + semester text_secondary.',
                'Verified badge "WAJAH TERVERIFIKASI" success_surface chip.',
                'Mini stats card: 92% Kehadiran / 25 Sesi / 5 MK (3 column).',
                'Menu grouped: AKUN (3 item) + PENGATURAN (3 item) - header text_tertiary uppercase.',
            ]},
            {'title': 'Behavior', 'items': [
                'Tap avatar -> option ganti foto (perlu diimplementasikan).',
                'Tap "Verifikasi Wajah" -> /face-register atau /face-status jika sudah terdaftar.',
                'Tap "Pengajuan Izin" -> /leave-requests dengan badge counter pending.',
                'Tap "Keluar dari Akun" -> SweetAlert konfirmasi -> logout + clear secure storage + reset Dio.',
            ]},
        ]
    )

    # Page 11: Leave (List + Form) - 2 phones in 1 page
    add_two_phone_page(
        pdf, 11, 'Pengajuan Izin / Sakit',
        [render_leave_list_screen, render_leave_form_screen],
        ['Daftar Pengajuan', 'Form Pengajuan'],
        {
            'title': 'Pengajuan Izin / Sakit',
            'subtitle': 'Mahasiswa bisa lihat riwayat pengajuan + summary status (Pending / Disetujui / Ditolak), dan ajukan baru via FAB. Form pakai segmented control untuk pilih tipe (Izin / Sakit) + dropdown MK + date picker + textarea + upload lampiran opsional.',
            'sections': [
                {'title': 'Komponen List Screen', 'items': [
                    'Summary 3 card: Pending (warning) / Disetujui (success) / Ditolak (danger).',
                    'Daftar request: type chip + nama MK + tanggal + status chip.',
                    'FAB primary 13mm di kanan-bawah dengan ikon "+" untuk ajukan baru.',
                ]},
                {'title': 'Komponen Form Screen', 'items': [
                    'Segmented control 2 tab: Izin / Sakit (dengan animation slide indicator).',
                    'Dropdown mata kuliah + date picker dengan ikon kalender.',
                    'Textarea Alasan dengan counter 0/200 di kanan-atas label.',
                    'Upload area dashed border primary_surface dengan ikon document + hint format.',
                    'Sticky bottom: tombol "Kirim Pengajuan" primary 10mm.',
                ]},
                {'title': 'Behavior', 'items': [
                    'Submit form -> POST /api/mobile/leave-requests -> toast success -> push back ke list dengan refresh.',
                    'Validasi Zod: tipe enum, course_id required, date min today, reason 10-200 chars.',
                    'Lampiran: max 2MB, format JPG/PNG/PDF, upload ke Supabase Storage bucket private.',
                    'Tap card di list -> bottom sheet detail (mirip Riwayat).',
                ]},
            ]
        }
    )

    # Page 12: Face Registration
    add_phone_page(
        pdf, 12, 'Daftar Wajah (Face Registration)',
        render_face_registration_screen,
        'Pendaftaran Wajah',
        'Layar dengan dark background + circle frame untuk panduan posisi wajah. 4 step pose (Lurus / Kedip / Kiri / Kanan) dengan progress bar.',
        [
            {'title': 'Komponen', 'items': [
                'Background hitam (camera dim) untuk fokus ke wajah.',
                'Circle frame primary 25mm radius dengan outer guide ring putih.',
                '4 chip step horizontal: Lurus (active primary) / Kedip / Kiri / Kanan (inactive abu).',
                'Progress bar 1.5mm: 25% terisi (step 1 dari 4).',
                'Card surface bottom dengan instruksi spesifik per step + tombol "Mulai Capture".',
            ]},
            {'title': 'Behavior', 'items': [
                'Pose lookStraight: capture 7 frame embedding via tflite_flutter (MobileFaceNet 192-d).',
                'Pose lainnya (blink/turnLeft/turnRight): hanya liveness check via ML Kit headEulerAngle/eyeOpen.',
                'Setelah 4 step: average 7 frame + L2 normalize -> POST /api/mobile/face/register.',
                'Threshold default 0.65 (LFW MobileFaceNet) - bukan 0.75 (heuristic lama, BUG-010).',
                'Setelah berhasil: SweetAlert sukses + back ke profil dengan flag isFaceRegistered=true.',
            ]},
        ]
    )

    # Page 13: Empty States
    render_empty_states(pdf)

    # Output
    out_dir = Path(__file__).parent.parent / 'docs' / 'mockups'
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / 'UI_Mockup_MyPresensi_v5_Modern.pdf'
    pdf.output(str(out_path))
    print(f'PDF berhasil dibuat: {out_path}')
    print(f'Total halaman: {pdf.page_no()}')


if __name__ == '__main__':
    main()
