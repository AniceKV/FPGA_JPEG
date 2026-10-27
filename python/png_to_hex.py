from PIL import Image
img = Image.open("/home/anish/VLSI project/JPEG_compression/Images/test.png").convert("RGB").resize((64, 64))  # keep it small, multiple of 8
with open("/home/anish/VLSI project/JPEG_compression/Images/test.hex", "w") as f:
    for r, g, b in img.getdata():
        f.write(f"{r:02x}{g:02x}{b:02x}\n")