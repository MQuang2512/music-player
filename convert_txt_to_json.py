import json

def parse_input_txt(txt_path):
    with open(txt_path, 'r', encoding='utf-8') as f:
        lines = [line.strip() for line in f if line.strip()]
    
    i = 0
    albums = []
    while i < len(lines):
        title = lines[i]
        artist = lines[i+1]
        artwork = lines[i+2]
        num_tracks = int(lines[i+3])
        i += 4
        tracks = []
        for _ in range(num_tracks):
            track_name = lines[i]
            track_file = lines[i+1]
            tracks.append({"name": track_name, "location": track_file})
            i += 2
        albums.append({
            "title": title,
            "artist": artist,
            "artwork": artwork,
            "tracks": tracks
        })
    return albums

if __name__ == "__main__":
    result = parse_input_txt("input.txt")
    with open("input.json", "w", encoding="utf-8") as f:
        json.dump(result, f, indent=4, ensure_ascii=False)
    print("✅ Converted input.txt to input.json")
