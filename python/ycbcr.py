from PIL import Image

img = Image.open("/home/anish/VLSI project/JPEG_compression/Images/test.png").convert("RGB").resize((240, 240))

with open("/home/anish/VLSI project/JPEG_compression/Images/test.hex", "w") as fi, open("/home/anish/VLSI project/JPEG_compression/Images/expected.hex", "w") as fe:
    for r, g, b in img.getdata():
        fi.write(f"{r:02x}{g:02x}{b:02x}\n")
        Y  = (77*r + 150*g + 29*b) >> 8
        Cb = ((-43*r - 85*g + 128*b) >> 8) + 128
        Cr = ((128*r - 107*g - 21*b) >> 8) + 128
        fe.write(f"{Y:02x}{Cb:02x}{Cr:02x}\n")