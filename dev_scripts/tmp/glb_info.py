import json, struct, sys
for path in sys.argv[1:]:
    data = open(path, 'rb').read()
    n = struct.unpack('<I', data[12:16])[0]
    j = json.loads(data[20:20 + n])
    print("==", path)
    print(" asset", j.get("asset"))
    print(" meshes", len(j.get("meshes", [])), "nodes", len(j.get("nodes", [])), "skins", len(j.get("skins", [])))
    tris = 0
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            if "indices" in p:
                tris += j["accessors"][p["indices"]]["count"] // 3
            print("  prim attrs", list(p["attributes"].keys()), "mat", p.get("material"))
    print(" triangles", tris)
    for s in j.get("skins", []):
        print(" joints", len(s["joints"]), [j["nodes"][k].get("name") for k in s["joints"]][:60])
    for a in j.get("animations", []):
        ch = a["channels"]
        inp = j["accessors"][a["samplers"][0]["input"]]
        print(" anim", a.get("name"), "channels", len(ch), "dur", inp.get("max"))
    for im in j.get("images", []):
        bv = j["bufferViews"][im["bufferView"]] if "bufferView" in im else None
        print(" image", im.get("name"), im.get("mimeType"), bv["byteLength"] if bv else im.get("uri"))
    for mat in j.get("materials", []):
        print(" material", mat.get("name"), list(mat.keys()))
