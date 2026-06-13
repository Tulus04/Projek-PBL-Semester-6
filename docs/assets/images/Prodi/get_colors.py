from PIL import Image
from collections import Counter
import sys

def get_dominant_colors(image_path, num_colors=3):
    try:
        img = Image.open(image_path)
        img = img.resize((50, 50)) # Resize for faster processing
        img_rgb = img.convert("RGB")
        
        pixels = list(img_rgb.getdata())
        
        # Count pixel colors
        counts = Counter(pixels)
        
        # Get the most common colors
        common = counts.most_common(num_colors + 5) # Get a few more to filter out white/black if needed
        
        for idx, (color, count) in enumerate(common):
            r, g, b = color
            hex_color = "#{:02x}{:02x}{:02x}".format(r, g, b)
            print(f"Color {idx+1}: RGB({r:>3}, {g:>3}, {b:>3}) | HEX: {hex_color} | Count: {count}")
            
    except Exception as e:
        print("Error:", e)

if __name__ == '__main__':
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    trpl_image_path = os.path.join(script_dir, "TRPL.jpg")
    get_dominant_colors(trpl_image_path)
