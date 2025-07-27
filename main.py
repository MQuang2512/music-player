# music_player.py
import os
import json
import customtkinter as ctk
from tkinter import filedialog, messagebox, simpledialog
from PIL import Image
import pygame
from mutagen.mp3 import MP3

# Configuration
SCREEN_W, SCREEN_H = 1200, 750
SIDEBAR_WIDTH = 220
BAR_HEIGHT = 100
ARTWORK_SIZE = 100

# Data models
class Track:
    def __init__(self, name, location, album=None):
        self.name = name
        self.location = location
        self.album = album

class Album:
    def __init__(self, title, artist, artwork_path, tracks):
        self.title = title
        self.artist = artist
        self.artwork_path = artwork_path
        self.artwork = Image.open(artwork_path).resize((ARTWORK_SIZE, ARTWORK_SIZE))
        self.ctk_artwork = ctk.CTkImage(light_image=self.artwork, dark_image=self.artwork, size=(ARTWORK_SIZE, ARTWORK_SIZE))
        self.tracks = [Track(t['name'], t['location'], self) for t in tracks]

class Playlist:
    def __init__(self, name):
        self.name = name
        self.tracks = []

    def add_track(self, track):
        if track not in self.tracks:
            self.tracks.append(track)

    def remove_track(self, index):
        if 0 <= index < len(self.tracks):
            self.tracks.pop(index)

# Custom Dialog for Creating Playlist
class CreatePlaylistDialog(ctk.CTkToplevel):
    def __init__(self, parent, albums):
        super().__init__(parent)
        self.parent = parent
        self.albums = albums
        self.result = None
        self.selected_tracks = []
        
        self.title("Create New Playlist")
        self.geometry("800x600")
        self.transient(parent)
        self.grab_set()
        
        # Playlist name
        name_frame = ctk.CTkFrame(self)
        name_frame.pack(fill="x", padx=20, pady=10)
        
        ctk.CTkLabel(name_frame, text="Playlist Name:", font=("Segoe UI", 14)).pack(side="left", padx=10)
        self.name_entry = ctk.CTkEntry(name_frame, placeholder_text="Enter playlist name...")
        self.name_entry.pack(side="left", fill="x", expand=True, padx=10)
        
        # Main content area
        content_frame = ctk.CTkFrame(self)
        content_frame.pack(fill="both", expand=True, padx=20, pady=10)
        
        # Left side - Available tracks
        left_frame = ctk.CTkFrame(content_frame)
        left_frame.pack(side="left", fill="both", expand=True, padx=(0, 10))
        
        ctk.CTkLabel(left_frame, text="Available Tracks", font=("Segoe UI", 16, "bold")).pack(pady=10)
        
        self.tracks_scroll = ctk.CTkScrollableFrame(left_frame)
        self.tracks_scroll.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Right side - Selected tracks
        right_frame = ctk.CTkFrame(content_frame)
        right_frame.pack(side="right", fill="both", expand=True, padx=(10, 0))
        
        ctk.CTkLabel(right_frame, text="Selected Tracks", font=("Segoe UI", 16, "bold")).pack(pady=10)
        
        self.selected_scroll = ctk.CTkScrollableFrame(right_frame)
        self.selected_scroll.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Buttons
        button_frame = ctk.CTkFrame(self)
        button_frame.pack(fill="x", padx=20, pady=10)
        
        ctk.CTkButton(button_frame, text="Cancel", command=self.cancel).pack(side="right", padx=10)
        ctk.CTkButton(button_frame, text="Create Playlist", command=self.create_playlist).pack(side="right", padx=10)
        
        self.populate_tracks()
        self.update_selected_display()
        
    def populate_tracks(self):
        for album in self.albums:
            # Album header
            album_frame = ctk.CTkFrame(self.tracks_scroll, fg_color="#2a2a2a")
            album_frame.pack(fill="x", pady=5)
            
            album_label = ctk.CTkLabel(album_frame, text=f"{album.artist} - {album.title}", 
                                     font=("Segoe UI", 12, "bold"))
            album_label.pack(pady=5)
            
            # Tracks
            for track in album.tracks:
                track_frame = ctk.CTkFrame(self.tracks_scroll, fg_color="#1a1a1a")
                track_frame.pack(fill="x", pady=2)
                
                track_label = ctk.CTkLabel(track_frame, text=track.name, anchor="w")
                track_label.pack(side="left", padx=10, fill="x", expand=True)
                
                add_btn = ctk.CTkButton(track_frame, text="Add", width=50,
                                      command=lambda t=track: self.add_track(t))
                add_btn.pack(side="right", padx=5)
                
    def add_track(self, track):
        if track not in self.selected_tracks:
            self.selected_tracks.append(track)
            self.update_selected_display()
            
    def remove_track(self, track):
        if track in self.selected_tracks:
            self.selected_tracks.remove(track)
            self.update_selected_display()
            
    def update_selected_display(self):
        for widget in self.selected_scroll.winfo_children():
            widget.destroy()
            
        for track in self.selected_tracks:
            track_frame = ctk.CTkFrame(self.selected_scroll, fg_color="#1a1a1a")
            track_frame.pack(fill="x", pady=2)
            
            track_info = f"{track.album.artist} - {track.name}"
            track_label = ctk.CTkLabel(track_frame, text=track_info, anchor="w")
            track_label.pack(side="left", padx=10, fill="x", expand=True)
            
            remove_btn = ctk.CTkButton(track_frame, text="Remove", width=60,
                                     command=lambda t=track: self.remove_track(t))
            remove_btn.pack(side="right", padx=5)
            
    def create_playlist(self):
        name = self.name_entry.get().strip()
        if not name:
            messagebox.showerror("Error", "Please enter a playlist name")
            return
            
        if not self.selected_tracks:
            messagebox.showerror("Error", "Please select at least one track")
            return
            
        playlist = Playlist(name)
        for track in self.selected_tracks:
            playlist.add_track(track)
            
        self.result = playlist
        self.destroy()
        
    def cancel(self):
        self.result = None
        self.destroy()

# Main Application
class MusicPlayerApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.geometry(f"{SCREEN_W}x{SCREEN_H}")
        self.title("LumaTune")
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("dark-blue")

        self.albums = []
        self.playlists = []
        self.current_album = None
        self.current_track = None
        self.current_playlist = None
        self.playing = False
        self.seeking = False
        self.seek_offset = 0
        self.current_view = "library"  # Track current view
        self.track_duration = 0  # Store current track duration
        self.track_start_time = 0  # When track started playing

        pygame.mixer.init()

        self._load_data("input.json")
        self._build_ui()

    def _load_data(self, filename):
        with open(filename, "r") as f:
            data = json.load(f)
        for entry in data:
            album = Album(entry['title'], entry['artist'], entry['artwork'], entry['tracks'])
            self.albums.append(album)

    def _build_ui(self):
        self.sidebar = ctk.CTkFrame(self, width=SIDEBAR_WIDTH, corner_radius=0, fg_color="#111111")
        self.sidebar.pack(side="left", fill="y")

        ctk.CTkLabel(self.sidebar, text="LumaTune", font=("Arial", 26, "bold"), text_color="white").pack(pady=(30, 10))

        self.btn_library = ctk.CTkButton(self.sidebar, text="Library", command=self._show_library, corner_radius=10)
        self.btn_library.pack(pady=10, padx=20, fill="x")

        self.btn_playlists = ctk.CTkButton(self.sidebar, text="Playlists", command=self._show_playlists, corner_radius=10)
        self.btn_playlists.pack(pady=10, padx=20, fill="x")

        # Add "Playlists for You" button
        self.btn_playlists_for_you = ctk.CTkButton(self.sidebar, text="Playlists for You", 
                                                  command=self._show_playlists_for_you, corner_radius=10,
                                                  fg_color="#2a2a2a", hover_color="#3a3a3a")
        self.btn_playlists_for_you.pack(pady=5, padx=20, fill="x")

        self.main_content_wrapper = ctk.CTkFrame(self, fg_color="#1a1a1a")
        self.main_content_wrapper.pack(side="top", fill="both", expand=True)

        self.main_frame = ctk.CTkScrollableFrame(self.main_content_wrapper, fg_color="#1a1a1a")
        self.main_frame.pack(side="left", fill="both", expand=True)

        self.inline_track_list = ctk.CTkScrollableFrame(self.main_content_wrapper, fg_color="#121212")
        self.inline_track_list.pack(side="right", fill="both", padx=(10, 10), pady=(10, 10))

        self.bar = ctk.CTkFrame(self, height=BAR_HEIGHT, fg_color="#262626")
        self.track_list_box = self.inline_track_list
        self.bar.pack(side="top", fill="x")
        self.track_label = ctk.CTkLabel(self.bar, text="No track playing", font=("Segoe UI", 14))
        self.track_label.pack(pady=(10, 5))

        controls_frame = ctk.CTkFrame(self.bar, fg_color="#262626")
        controls_frame.pack()

        self.btn_prev = ctk.CTkButton(controls_frame, text="⏮", width=40, command=self._previous_track)
        self.btn_prev.pack(side="left", padx=10)

        self.btn_play_pause = ctk.CTkButton(controls_frame, text="⏯", width=40, command=self._toggle_play_pause)
        self.btn_play_pause.pack(side="left", padx=10)

        self.btn_next = ctk.CTkButton(controls_frame, text="⏭", width=40, command=self._next_track)
        self.btn_next.pack(side="left", padx=10)

        volume_frame = ctk.CTkFrame(self.bar, fg_color="#262626")
        volume_frame.pack(pady=5)
        ctk.CTkLabel(volume_frame, text="Volume:").pack(side="left", padx=(10, 5))
        
        # Create volume icon using CTkImage
        try:
            speaker_img = Image.open("icons/volume.png").resize((18,18))
            speaker_icon = ctk.CTkImage(light_image=speaker_img, dark_image=speaker_img, size=(18, 18))
            self.volume_icon_label = ctk.CTkLabel(volume_frame, image=speaker_icon, text="")
            self.volume_icon_label.pack(side="left", padx=(10, 5))
        except FileNotFoundError:
            # Fallback to text if icon file not found
            ctk.CTkLabel(volume_frame, text="🔊").pack(side="left", padx=(10, 5))
        
        self.volume_slider = ctk.CTkSlider(volume_frame, from_=0, to=1, number_of_steps=20, command=self._set_volume)
        self.volume_slider.set(0.8)
        self.volume_slider.pack(side="left", fill="x", expand=True, padx=(0, 10))

        self.seek_frame = ctk.CTkFrame(self.bar, fg_color="#262626")
        self.seek_frame.pack(fill="x", padx=10)
        self.time_label = ctk.CTkLabel(self.seek_frame, text="0:00")
        self.time_label.pack(side="left")
        self.seek_slider = ctk.CTkSlider(self.seek_frame, from_=0, to=100, number_of_steps=100)
        self.seek_slider.set(0)
        self.seek_slider.pack(side="left", fill="x", expand=True, padx=(10,10))
        self.seek_slider.bind("<ButtonPress-1>", lambda e: setattr(self, 'seeking', True))
        self.seek_slider.bind("<ButtonRelease-1>", self._seek_to)
        self.total_label = ctk.CTkLabel(self.seek_frame, text="0:00")
        self.total_label.pack(side="right")
        
        # Start the update loops
        self.after(500, self._update_seek)
        self.after(1000, self._check_track_end)  # Check for track end every second

        # Show library by default
        self._show_library()

    def _seek_to(self, event=None):
        if self.current_track:
            total = self._get_track_length(self.current_track.location)
            if total:
                percent = self.seek_slider.get() / 100.0
                self.seek_offset = percent * total
                self._near_end_triggered = False  # Reset end trigger when seeking
                pygame.mixer.music.play(start=self.seek_offset)
                self.playing = True
                self.seeking = False

    def _check_track_end(self):
        """Check if current track has ended and auto-advance to next track"""
        if self.current_track and self.playing:
            try:
                # Check if music is still playing
                if not pygame.mixer.music.get_busy():
                    # Track has ended, auto-advance to next track
                    self._auto_next_track()
            except:
                pass
        
        # Schedule next check
        self.after(1000, self._check_track_end)
    
    def _auto_next_track(self):
        """Automatically advance to next track when current track ends"""
        tracks = []
        if self.current_playlist:
            tracks = self.current_playlist.tracks
        elif self.current_album:
            tracks = self.current_album.tracks
            
        if tracks and self.current_track:
            try:
                idx = tracks.index(self.current_track)
                if idx < len(tracks) - 1:  # Not the last track
                    next_idx = idx + 1
                    self._play_track(tracks[next_idx])
                else:
                    # Last track - stop playing
                    self.playing = False
                    self.track_label.configure(text="Playlist ended")
            except ValueError:
                # Current track not found in list, stop playing
                self.playing = False
    
    def _update_seek(self):
        if self.current_track and self.playing:
            try:
                pos = pygame.mixer.music.get_pos()
                if pos == -1:
                    return
                
                current_time = pos / 1000 + self.seek_offset
                total = self._get_track_length(self.current_track.location)

                if total:
                    progress = min(100, max(0, (current_time / total) * 100))
                    if not self.seeking:
                        self.seek_slider.set(progress)
                    self.time_label.configure(text=self._format_time(current_time))
                    self.total_label.configure(text=self._format_time(total))

                    if current_time >= total - 1 and not getattr(self, '_near_end_triggered', False):
                        self._near_end_triggered = True
                        self.after(500, self._auto_next_track)  # Auto advance after 0.5 seconds near end
                else:
                    self._near_end_triggered = False
            except:
                pass
        self.after(500, self._update_seek)  # Update every 500ms

    def _format_time(self, seconds):
        mins = int(seconds) // 60
        secs = int(seconds) % 60
        return f"{mins}:{secs:02}"

    def _play_track(self, track):
        if not track:
            return
        
        # Reset tracking variables
        self.seek_offset = 0
        self._near_end_triggered = False
        
        pygame.mixer.music.stop()
        pygame.mixer.music.load(track.location)
        pygame.mixer.music.play()
        pygame.mixer.music.set_volume(self.volume_slider.get())
        
        self.track_label.configure(text=f"Now Playing: {track.album.artist} - {track.name}")
        self.playing = True
        self.current_track = track
        
        # Store track duration and start time for better tracking
        self.track_duration = self._get_track_length(track.location)
        self.track_start_time = pygame.time.get_ticks() / 1000

    def _set_volume(self, value):
        pygame.mixer.music.set_volume(float(value))

    def _toggle_play_pause(self):
        if self.playing:
            pygame.mixer.music.pause()
        else:
            pygame.mixer.music.unpause()
        self.playing = not self.playing

    def _next_track(self):
        tracks = []
        if self.current_playlist:
            tracks = self.current_playlist.tracks
        elif self.current_album:
            tracks = self.current_album.tracks
            
        if tracks and self.current_track:
            try:
                idx = tracks.index(self.current_track)
                next_idx = (idx + 1) % len(tracks)
                self._play_track(tracks[next_idx])
            except ValueError:
                pass

    def _previous_track(self):
        tracks = []
        if self.current_playlist:
            tracks = self.current_playlist.tracks
        elif self.current_album:
            tracks = self.current_album.tracks
            
        if tracks and self.current_track:
            try:
                idx = tracks.index(self.current_track)
                prev_idx = (idx - 1) % len(tracks)
                self._play_track(tracks[prev_idx])
            except ValueError:
                pass

    def _get_track_length(self, filepath):
        try:
            audio = MP3(filepath)
            return audio.info.length
        except:
            return 180

    def _show_library(self):
        self.current_view = "library"
        for widget in self.main_frame.winfo_children():
            widget.destroy()
        header = ctk.CTkLabel(self.main_frame, text="Your Albums", font=("Segoe UI", 22, "bold"))
        header.pack(pady=20)
        for album in self.albums:
            frame = ctk.CTkFrame(self.main_frame, fg_color="#2a2a2a", corner_radius=12)
            frame.pack(padx=20, pady=10, anchor="w", fill="x")
            
            lbl_img = ctk.CTkLabel(frame, image=album.ctk_artwork, text="")
            lbl_img.pack(side="left", padx=10, pady=10)
            
            text = f"{album.artist}\n{album.title}"
            lbl = ctk.CTkLabel(frame, text=text, anchor="w", justify="left", font=("Segoe UI", 14))
            lbl.pack(side="left", padx=10)
            btn_play = ctk.CTkButton(frame, text="▶ Play", width=80, command=lambda alb=album: self._play_album(alb))
            btn_play.pack(side="right", padx=10)

    def _show_playlists(self):
        self.current_view = "playlists"
        for widget in self.main_frame.winfo_children():
            widget.destroy()
        
        # Header with create button
        header_frame = ctk.CTkFrame(self.main_frame, fg_color="#1a1a1a")
        header_frame.pack(fill="x", padx=20, pady=20)
        
        header = ctk.CTkLabel(header_frame, text="My Playlists", font=("Segoe UI", 22, "bold"))
        header.pack(side="left")
        
        create_btn = ctk.CTkButton(header_frame, text="Create New Playlist", 
                                 command=self._create_new_playlist,
                                 fg_color="#1f538d", hover_color="#14375e")
        create_btn.pack(side="right")
        
        # Show existing playlists
        if not self.playlists:
            empty_label = ctk.CTkLabel(self.main_frame, text="No playlists yet. Create your first playlist!", 
                                     font=("Segoe UI", 16), text_color="#888888")
            empty_label.pack(pady=50)
        else:
            for playlist in self.playlists:
                frame = ctk.CTkFrame(self.main_frame, fg_color="#2a2a2a", corner_radius=12)
                frame.pack(padx=20, pady=10, anchor="w", fill="x")
                
                # Playlist icon (using a default music icon)
                icon_frame = ctk.CTkFrame(frame, width=ARTWORK_SIZE, height=ARTWORK_SIZE, fg_color="#404040")
                icon_frame.pack(side="left", padx=10, pady=10)
                icon_frame.pack_propagate(False)
                
                playlist_icon = ctk.CTkLabel(icon_frame, text="♪", font=("Arial", 40), text_color="white")
                playlist_icon.pack(expand=True)
                
                # Playlist info
                info_text = f"{playlist.name}\n{len(playlist.tracks)} tracks"
                lbl = ctk.CTkLabel(frame, text=info_text, anchor="w", justify="left", font=("Segoe UI", 14))
                lbl.pack(side="left", padx=10, fill="x", expand=True)
                
                # Buttons
                button_frame = ctk.CTkFrame(frame, fg_color="transparent")
                button_frame.pack(side="right", padx=10)
                
                btn_play = ctk.CTkButton(button_frame, text="▶ Play", width=80, 
                                       command=lambda pl=playlist: self._play_playlist(pl))
                btn_play.pack(side="top", pady=2)
                
                btn_delete = ctk.CTkButton(button_frame, text="Delete", width=80,
                                         fg_color="#8b0000", hover_color="#a50000",
                                         command=lambda pl=playlist: self._delete_playlist(pl))
                btn_delete.pack(side="top", pady=2)

    def _show_playlists_for_you(self):
        self.current_view = "playlists_for_you"
        for widget in self.main_frame.winfo_children():
            widget.destroy()
        
        header = ctk.CTkLabel(self.main_frame, text="Playlists for You", font=("Segoe UI", 22, "bold"))
        header.pack(pady=20)
        
        # Create some suggested playlists based on available albums
        suggested_playlists = self._generate_suggested_playlists()
        
        if not suggested_playlists:
            empty_label = ctk.CTkLabel(self.main_frame, text="No suggested playlists available", 
                                     font=("Segoe UI", 16), text_color="#888888")
            empty_label.pack(pady=50)
        else:
            for playlist in suggested_playlists:
                frame = ctk.CTkFrame(self.main_frame, fg_color="#2a2a2a", corner_radius=12)
                frame.pack(padx=20, pady=10, anchor="w", fill="x")
                
                # Playlist icon
                icon_frame = ctk.CTkFrame(frame, width=ARTWORK_SIZE, height=ARTWORK_SIZE, fg_color="#1f538d")
                icon_frame.pack(side="left", padx=10, pady=10)
                icon_frame.pack_propagate(False)
                
                playlist_icon = ctk.CTkLabel(icon_frame, text="★", font=("Arial", 40), text_color="white")
                playlist_icon.pack(expand=True)
                
                # Playlist info
                info_text = f"{playlist.name}\n{len(playlist.tracks)} tracks • Suggested"
                lbl = ctk.CTkLabel(frame, text=info_text, anchor="w", justify="left", font=("Segoe UI", 14))
                lbl.pack(side="left", padx=10, fill="x", expand=True)
                
                # Buttons
                button_frame = ctk.CTkFrame(frame, fg_color="transparent")
                button_frame.pack(side="right", padx=10)
                
                btn_play = ctk.CTkButton(button_frame, text="▶ Play", width=80,
                                       command=lambda pl=playlist: self._play_playlist(pl))
                btn_play.pack(side="top", pady=2)
                
                btn_add = ctk.CTkButton(button_frame, text="Add to My Playlists", width=120,
                                      fg_color="#1f538d", hover_color="#14375e",
                                      command=lambda pl=playlist: self._add_suggested_playlist(pl))
                btn_add.pack(side="top", pady=2)

    def _generate_suggested_playlists(self):
        """Generate suggested playlists based on available albums"""
        suggested = []
        
        if len(self.albums) >= 2:
            # Create "Best of Collection" playlist with first track from each album
            best_of = Playlist("Best of Your Collection")
            for album in self.albums[:5]:  # Limit to first 5 albums
                if album.tracks:
                    best_of.add_track(album.tracks[0])
            if best_of.tracks:
                suggested.append(best_of)
        
        # Create artist-specific playlists if we have multiple albums from same artist
        artist_tracks = {}
        for album in self.albums:
            if album.artist not in artist_tracks:
                artist_tracks[album.artist] = []
            artist_tracks[album.artist].extend(album.tracks)
        
        for artist, tracks in artist_tracks.items():
            if len(tracks) >= 3:  # Only create if artist has 3+ tracks
                artist_playlist = Playlist(f"{artist} Collection")
                for track in tracks[:8]:  # Limit to 8 tracks
                    artist_playlist.add_track(track)
                suggested.append(artist_playlist)
        
        return suggested[:3]  # Return max 3 suggested playlists

    def _create_new_playlist(self):
        dialog = CreatePlaylistDialog(self, self.albums)
        self.wait_window(dialog)
        
        if dialog.result:
            self.playlists.append(dialog.result)
            self._show_playlists()  # Refresh the view
            messagebox.showinfo("Success", f"Playlist '{dialog.result.name}' created successfully!")

    def _delete_playlist(self, playlist):
        if messagebox.askyesno("Confirm Delete", f"Are you sure you want to delete playlist '{playlist.name}'?"):
            self.playlists.remove(playlist)
            self._show_playlists()  # Refresh the view

    def _add_suggested_playlist(self, playlist):
        # Create a copy of the suggested playlist
        new_playlist = Playlist(playlist.name)
        for track in playlist.tracks:
            new_playlist.add_track(track)
        
        self.playlists.append(new_playlist)
        messagebox.showinfo("Success", f"Playlist '{playlist.name}' added to your playlists!")

    def _play_album(self, album):
        if album.tracks:
            self.current_album = album
            self.current_playlist = None  # Clear current playlist
            self.current_track = album.tracks[0]
            self._populate_track_list_album(album)
            self._play_track(self.current_track)

    def _play_playlist(self, playlist):
        if playlist.tracks:
            self.current_playlist = playlist
            self.current_album = None  # Clear current album
            self.current_track = playlist.tracks[0]
            self._populate_track_list_playlist(playlist)
            self._play_track(self.current_track)

    def _populate_track_list_album(self, album):
        for widget in self.inline_track_list.winfo_children():
            widget.destroy()
            
        # Album header
        header_frame = ctk.CTkFrame(self.inline_track_list, fg_color="#2a2a2a")
        header_frame.pack(fill="x", pady=(0, 10))
        
        ctk.CTkLabel(header_frame, text=f"{album.artist} - {album.title}", 
                    font=("Segoe UI", 14, "bold")).pack(pady=10)
        
        for track in album.tracks:
            item = ctk.CTkFrame(self.inline_track_list, fg_color="#2a2a2a", corner_radius=8)
            item.pack(fill="x", pady=4, padx=6)
            item.track = track
            label = ctk.CTkLabel(item, text=track.name, font=("Segoe UI", 13), anchor="w")
            label.pack(side="left", padx=10, fill="x", expand=True)
            btn = ctk.CTkButton(item, text="▶", width=30, command=lambda t=track: self._play_track(t))
            btn.pack(side="right", padx=6)

    def _populate_track_list_playlist(self, playlist):
        for widget in self.inline_track_list.winfo_children():
            widget.destroy()
            
        # Playlist header
        header_frame = ctk.CTkFrame(self.inline_track_list, fg_color="#2a2a2a")
        header_frame.pack(fill="x", pady=(0, 10))
        
        ctk.CTkLabel(header_frame, text=f"Playlist: {playlist.name}", 
                    font=("Segoe UI", 14, "bold")).pack(pady=10)
        
        for i, track in enumerate(playlist.tracks):
            item = ctk.CTkFrame(self.inline_track_list, fg_color="#2a2a2a", corner_radius=8)
            item.pack(fill="x", pady=4, padx=6)
            item.track = track
            
            track_info = f"{track.album.artist} - {track.name}"
            label = ctk.CTkLabel(item, text=track_info, font=("Segoe UI", 13), anchor="w")
            label.pack(side="left", padx=10, fill="x", expand=True)
            
            btn_play = ctk.CTkButton(item, text="▶", width=30, command=lambda t=track: self._play_track(t))
            btn_play.pack(side="right", padx=6)
            
            # Add remove button for custom playlists (not suggested ones)
            if playlist in self.playlists:
                btn_remove = ctk.CTkButton(item, text="×", width=30, fg_color="#8b0000", hover_color="#a50000",
                                         command=lambda idx=i, pl=playlist: self._remove_track_from_playlist(pl, idx))
                btn_remove.pack(side="right", padx=2)

    def _remove_track_from_playlist(self, playlist, track_index):
        if 0 <= track_index < len(playlist.tracks):
            playlist.remove_track(track_index)
            self._populate_track_list_playlist(playlist)  # Refresh the display
 
if __name__ == '__main__':
    app = MusicPlayerApp()
    app.mainloop()