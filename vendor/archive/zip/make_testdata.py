import zipfile

with zipfile.ZipFile("helloworld.zip64", "w", allowZip64=True) as zip:
    with zip.open("example.txt", "w", force_zip64=True) as f:
        f.write(b"Hello world")

with zipfile.ZipFile(
    "helloworld_deflate.zip", "w", compression=zipfile.ZIP_DEFLATED
) as zip:
    with zip.open("example.txt", "w") as f:
        f.write(b"Hello world, world")
