# LumaTune Music Player

LumaTune is a modern desktop music player application built with Python, CustomTkinter, and Pygame. It features a beautiful UI, album and playlist management, and MP3 playback capabilities.

## Features

- **Album Library**: Browse albums with artwork, artist, and track details.
- **Playlist Management**: Create, edit, and delete custom playlists.
- **Suggested Playlists**: Get automatically generated playlists based on your library.
- **MP3 Playback**: Play, pause, seek, and skip tracks with smooth controls.
- **Volume Control**: Adjust playback volume with a slider and icon.
- **Custom Dialogs**: Intuitive dialogs for playlist creation and track selection.
- **Responsive UI**: Built with CustomTkinter for a modern, dark-themed interface.

## Installation

1. **Clone the repository**
   ```powershell
   git clone <repo-url>
   cd <repo-folder>
   ```
2. **Install dependencies**
   ```powershell
   pip install customtkinter pillow pygame mutagen
   ```
3. **Prepare your music and images**
   - Place your MP3 files in the `musics/` folder.
   - Place album artwork images in the `images/` folder.
   - Update `input.txt` with your album and track info, then run:
     ```powershell
     python convert_txt_to_json.py
     ```
   - This will generate `input.json` for the app.

## Usage

Run the main application:
```powershell
python main.py
```

## File Structure

```
├── main.py                  # Main application code
├── convert_txt_to_json.py   # Utility to convert input.txt to input.json
├── input.txt                # Text file with album/track info
├── input.json               # JSON file used by the app
├── images/                  # Album artwork images
├── musics/                  # MP3 music files
├── icons/                   # UI icons (e.g., volume)
```

## Data Format

- **input.txt**: Human-readable album and track info
- **input.json**: Structured data for the app (generated from input.txt)

## Dependencies
- [CustomTkinter](https://github.com/TomSchimansky/CustomTkinter)
- [Pillow](https://python-pillow.org/)
- [Pygame](https://www.pygame.org/)
- [Mutagen](https://mutagen.readthedocs.io/en/latest/)

## Screenshots

_Add screenshots of the UI here if available._

## License

MIT License

---

**LumaTune** — A beautiful, customizable music player for your desktop.
