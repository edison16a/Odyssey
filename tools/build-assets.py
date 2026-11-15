"""
Copies every image the seed data points at into the app's asset catalog.

Each mockup path such as assets/media/places/doe-library.jpg becomes an
image set named places-doe-library, which is the same name Media.name(for:)
builds in Swift. Photos are capped at 1200px so the app stays small.

    python3 tools/build-assets.py ../Odyssey/mockup Odyssey/Resources/seed.json Odyssey/Media.xcassets
"""
import json, os, re, shutil, sys
from PIL import Image

mockup, seed_path, catalog = sys.argv[1:4]
seed = open(seed_path).read()
paths = sorted(set(re.findall(r'assets/[\w/.-]+\.(?:jpg|jpeg|png|svg)', seed)))
paths += ["assets/brand/odyssey-app-icon.svg", "assets/brand/odyssey-mark-black.svg", "assets/brand/odyssey-mark-white.svg",
          "assets/brand/odyssey-wordmark-black.svg", "assets/brand/odyssey-wordmark-white.svg"]
paths += ["assets/media/people/p%02d.jpg" % i for i in range(1, 11)]
paths += ["assets/media/indoor/%s" % n for n in os.listdir(os.path.join(mockup, "assets/media/indoor"))
          if n.endswith(".jpg")]
paths += ["assets/media/streak/%s" % n for n in os.listdir(os.path.join(mockup, "assets/media/streak"))
          if n.endswith(".jpg")]

def asset_name(path):
    path = re.sub(r'^assets/(media/|vendor/)?', '', path)
    return re.sub(r'\.\w+$', '', path).replace('/', '-')

shutil.rmtree(catalog, ignore_errors=True)
os.makedirs(catalog)
json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(catalog, "Contents.json"), "w"), indent=2)

made = 0
for path in sorted(set(paths)):
    src = os.path.join(mockup, path)
    if not os.path.exists(src):
        print("missing", path)
        continue
    name = asset_name(path)
    folder = os.path.join(catalog, name + ".imageset")
    os.makedirs(folder)
    ext = path.rsplit(".", 1)[1]
    filename = name + "." + ("jpg" if ext == "jpeg" else ext)
    if ext == "svg":
        shutil.copy(src, os.path.join(folder, filename))
        props = {"preserves-vector-representation": True}
    else:
        image = Image.open(src)
        image.thumbnail((1200, 1200))
        if ext == "png":
            image.save(os.path.join(folder, filename), optimize=True)
        else:
            image.convert("RGB").save(os.path.join(folder, filename), quality=82, optimize=True)
        props = {}
    contents = {"images": [{"filename": filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
    if props:
        contents["properties"] = props
    json.dump(contents, open(os.path.join(folder, "Contents.json"), "w"), indent=2)
    made += 1
print(made, "image sets")
