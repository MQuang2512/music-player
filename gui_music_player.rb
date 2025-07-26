require 'gosu'

# Window dimensions and colors
SCREEN_W = 800
SCREEN_H = 600
BAR_HEIGHT = 100

# Z-order layers
module ZOrder
  BACKGROUND, UI = *0..1
end

# Helper to detect clicks within a dimension
class Dimension
  attr_accessor :left, :top, :right, :bottom
  def initialize(l, t, r, b)
    @left, @top, @right, @bottom = l, t, r, b
  end
end

# Track: holds name, file location, album reference, and UI dimension
class Track
  attr_accessor :name, :location, :dim, :album
  def initialize(name, location, album = nil)
    @name, @location, @album = name, location, album
    @dim = nil
  end
  
  def full_name
    @album ? "#{@album.artist} - #{@name}" : @name
  end
end

# Playlist: holds name and array of tracks
class Playlist
  attr_accessor :name, :tracks, :dim
  def initialize(name)
    @name = name
    @tracks = []
    @dim = nil
  end
  
  def add_track(track)
    @tracks << track unless @tracks.include?(track)
  end
  
  def remove_track(index)
    @tracks.delete_at(index) if index >= 0 && index < @tracks.length
  end
  
  def duration
    # Estimate total duration (would need actual track lengths)
    @tracks.length * 180 # 3 minutes average per track
  end
end

# Album: holds title, artist, artwork image, and tracks
class Album
  attr_reader :title, :artist, :artwork, :tracks
  def initialize(title, artist, artwork, tracks)
    @title, @artist, @artwork, @tracks = title, artist, artwork, tracks
    # Set album reference for each track
    @tracks.each { |track| track.album = self }
  end
end

# Main application window
class MusicPlayerMain < Gosu::Window
  SIDEBAR_WIDTH   = 200
  MENU_ITEMS      = ['Library', 'Playlists']
  ALBUM_COLUMNS   = 4
  ARTWORK_SCALE   = 0.3
  TRACK_FONT_SIZE = 25
  CONTROL_SIZE    = 24

  def initialize
    super SCREEN_W, SCREEN_H
    self.caption = 'Music Player'

    @font         = Gosu::Font.new(TRACK_FONT_SIZE)
    @menu_font    = Gosu::Font.new(20)
    @control_font = Gosu::Font.new(CONTROL_SIZE)
    @small_font   = Gosu::Font.new(16)

    data     = read_input('input.txt')
    @albums  = parse_albums(data)
    compute_album_positions

    # Playlist system
    @playlists = []
    @current_view = :library # :library, :playlists, :playlist_detail
    @selected_playlist = nil
    @creating_playlist = false
    @text_input = Gosu::TextInput.new
    self.text_input = nil
    @selected_tracks_for_playlist = []

    @current_album = 0
    @current_track = 0
    @current_playlist_track = 0
    @playing_from_playlist = false
    @song          = nil
    @playing       = false
    @volume        = 1.0
    @target_bg     = nil
    @bg_alpha      = 255

    play_current
  end

  # Read raw lines from input file
  def read_input(path)
    File.read(path).lines.map(&:chomp)
  end

  # Convert raw lines into Album objects
  def parse_albums(lines)
    arr = []
    idx = 0; count = lines[idx].to_i; idx += 1
    count.times do
      title   = lines[idx]; idx += 1
      artist  = lines[idx]; idx += 1
      artfile = lines[idx]; idx += 1
      img     = Gosu::Image.new(artfile)
      n       = lines[idx].to_i; idx += 1
      tracks  = []
      n.times do
        name     = lines[idx]; idx += 1
        location = lines[idx]; idx += 1
        tracks << Track.new(name, location)
      end
      arr << Album.new(title, artist, img, tracks)
    end
    arr
  end

  # Determine grid positions for album artwork
  def compute_album_positions
    @album_positions = []
    return if @albums.empty?
    w = @albums.first.artwork.width * ARTWORK_SCALE
    h = @albums.first.artwork.height * ARTWORK_SCALE
    @albums.each_with_index do |alb, i|
      col = i % ALBUM_COLUMNS; row = i / ALBUM_COLUMNS
      x   = SIDEBAR_WIDTH + 20 + col * (w + 20)
      y   = 20 + row * (h + 20)
      @album_positions << Dimension.new(x, y, x + w, y + h)
    end
  end

  # Play the currently selected track and prepare background fade
  def play_current
    @song&.stop
    
    # Get current track based on mode
    tr = get_current_track
    return unless tr # Exit if no track available
    
    if @playing_from_playlist && @selected_playlist && tr.album
      @target_bg = tr.album.artwork
    elsif !@playing_from_playlist
      @target_bg = @albums[@current_album].artwork
    else
      @target_bg = nil
    end
    
    @song = Gosu::Song.new(tr.location)
    @song.play(false)
    @song.volume = @volume if @song.respond_to?(:volume=)
    @playing = true
    @bg_alpha = 0
    
    # Initialize progress tracking
    @start_time = Gosu.milliseconds / 1000.0
    if @song.respond_to?(:duration)
      @song_length = @song.duration
    elsif @song.respond_to?(:length)
      @song_length = @song.length
    else
      @song_length = 180.0  # fallback duration (3 minutes)
    end
  end

  # Helper method to get current track safely
  def get_current_track
    if @playing_from_playlist && @selected_playlist
      return nil if @selected_playlist.tracks.empty?
      @current_playlist_track = 0 if @current_playlist_track >= @selected_playlist.tracks.length
      @selected_playlist.tracks[@current_playlist_track]
    else
      return nil if @albums.empty? || @albums[@current_album].tracks.empty?
      @current_track = 0 if @current_track >= @albums[@current_album].tracks.length
      @albums[@current_album].tracks[@current_track]
    end
  end

  # Draw dynamic background with fade-in from album artwork
  def draw_background
    if @target_bg
      sx = SCREEN_W.to_f / @target_bg.width
      sy = SCREEN_H.to_f / @target_bg.height
      color = Gosu::Color.new((@bg_alpha << 24) | 0xFFFFFF)
      @target_bg.draw(0,0,ZOrder::BACKGROUND,sx,sy,color)
    else
      Gosu.draw_quad(0,0,Gosu::Color::BLACK,0,SCREEN_H,Gosu::Color::BLACK,SCREEN_W,0,Gosu::Color::BLACK,SCREEN_W,SCREEN_H,Gosu::Color::BLACK,ZOrder::BACKGROUND)
    end
    Gosu.draw_quad(0,0,Gosu::Color.argb(0x22000000),0,SCREEN_H,Gosu::Color.argb(0x66000000),SCREEN_W,0,Gosu::Color.argb(0x22000000),SCREEN_W,SCREEN_H,Gosu::Color.argb(0x66000000),ZOrder::UI)
  end

  # Draw sidebar menu
  def draw_sidebar
    Gosu.draw_rect(0,0,SIDEBAR_WIDTH,SCREEN_H,Gosu::Color.argb(0xCC000000),ZOrder::UI)
    y = 50
    MENU_ITEMS.each_with_index do |item, i|
      color = (@current_view == :library && item == 'Library') || 
              (@current_view == :playlists && item == 'Playlists') ? 
              Gosu::Color::YELLOW : Gosu::Color::WHITE
      @menu_font.draw_text(item, 20, y, ZOrder::UI, 1.0, 1.0, color)
      y += 40
    end
  end

  # Main content area based on current view
  def draw_main_content
    case @current_view
    when :library
      draw_album_grid
      draw_track_list
    when :playlists
      draw_playlist_view
    when :playlist_detail
      draw_playlist_detail_view
    end
  end

  # Draw playlist management view
  def draw_playlist_view
    x_start = SIDEBAR_WIDTH + 20
    y_start = 20

    # Title
    @font.draw_text("My Playlists", x_start, y_start, ZOrder::UI)
    
    # Create playlist button
    button_y = y_start + 50
    Gosu.draw_rect(x_start, button_y, 150, 30, Gosu::Color::BLUE, ZOrder::UI)
    @menu_font.draw_text("+ Create Playlist", x_start + 10, button_y + 5, ZOrder::UI)
    
    # Playlist input field (if creating)
    if @creating_playlist
      input_y = button_y + 40
      Gosu.draw_rect(x_start, input_y, 200, 25, Gosu::Color::WHITE, ZOrder::UI)
      Gosu.draw_rect(x_start + 2, input_y + 2, 196, 21, Gosu::Color::BLACK, ZOrder::UI)
      @small_font.draw_text(@text_input.text, x_start + 5, input_y + 3, ZOrder::UI, 1.0, 1.0, Gosu::Color::WHITE)
      
      # Create/Cancel buttons
      Gosu.draw_rect(x_start + 210, input_y, 60, 25, Gosu::Color::GREEN, ZOrder::UI)
      @small_font.draw_text("Create", x_start + 220, input_y + 5, ZOrder::UI)
      
      Gosu.draw_rect(x_start + 275, input_y, 60, 25, Gosu::Color::RED, ZOrder::UI)
      @small_font.draw_text("Cancel", x_start + 285, input_y + 5, ZOrder::UI)
    end

    # List existing playlists
    list_y = @creating_playlist ? button_y + 80 : button_y + 50
    @playlists.each_with_index do |playlist, i|
      y = list_y + i * 40
      
      # Playlist item background
      Gosu.draw_rect(x_start, y, 400, 35, Gosu::Color.argb(0x44FFFFFF), ZOrder::UI)
      
      # Playlist info
      @menu_font.draw_text(playlist.name, x_start + 10, y + 5, ZOrder::UI)
      @small_font.draw_text("#{playlist.tracks.length} tracks", x_start + 10, y + 20, ZOrder::UI, 1.0, 1.0, Gosu::Color::GRAY)
      
      # Delete button
      Gosu.draw_rect(x_start + 350, y + 5, 40, 25, Gosu::Color::RED, ZOrder::UI)
      @small_font.draw_text("Delete", x_start + 355, y + 10, ZOrder::UI)
      
      # Store dimensions for click detection
      playlist.dim = Dimension.new(x_start, y, x_start + 400, y + 35)
    end
  end

  # Draw detailed playlist view
  def draw_playlist_detail_view
    return unless @selected_playlist
    
    x_start = SIDEBAR_WIDTH + 20
    y_start = 20
    content_width = SCREEN_W - SIDEBAR_WIDTH - 40
    left_panel_width = (content_width * 0.6).to_i
    right_panel_width = (content_width * 0.35).to_i
    right_panel_x = x_start + left_panel_width + 20

    # Back button
    Gosu.draw_rect(x_start, y_start, 80, 30, Gosu::Color::GRAY, ZOrder::UI)
    @menu_font.draw_text("< Back", x_start + 10, y_start + 5, ZOrder::UI)

    # Playlist title
    @font.draw_text(@selected_playlist.name, x_start + 100, y_start, ZOrder::UI)
    @small_font.draw_text("#{@selected_playlist.tracks.length} tracks", x_start + 100, y_start + 30, ZOrder::UI, 1.0, 1.0, Gosu::Color::GRAY)

    # Add tracks section (left panel)
    add_y = y_start + 70
    @menu_font.draw_text("Add Tracks:", x_start, add_y, ZOrder::UI)
    
    # Scrollable area for track selection
    scroll_area_y = add_y + 30
    scroll_area_height = SCREEN_H - BAR_HEIGHT - scroll_area_y - 20
    
    # Show available albums for track selection (limited height)
    current_y = scroll_area_y
    max_display_y = scroll_area_y + scroll_area_height - 60
    
    @albums.each_with_index do |album, album_idx|
      break if current_y > max_display_y
      
      # Album header
      @small_font.draw_text("#{album.artist} - #{album.title}", x_start, current_y, ZOrder::UI, 1.0, 1.0, Gosu::Color::CYAN)
      current_y += 18
      
      # Album tracks (only show first few if running out of space)
      tracks_to_show = album.tracks.length
      if current_y + (tracks_to_show * 18) > max_display_y
        tracks_to_show = [(max_display_y - current_y) / 18, 0].max
      end
      
      album.tracks[0...tracks_to_show].each_with_index do |track, track_idx|
        # Track selection checkbox
        checkbox_x = x_start + 10
        is_selected = @selected_tracks_for_playlist.include?(track)
        
        Gosu.draw_rect(checkbox_x, current_y, 12, 12, is_selected ? Gosu::Color::GREEN : Gosu::Color::WHITE, ZOrder::UI)
        if is_selected
          @small_font.draw_text("✓", checkbox_x + 1, current_y - 2, ZOrder::UI, 1.0, 1.0, Gosu::Color::WHITE)
        end
        
        # Track name (truncate if too long)
        track_name = track.name.length > 25 ? track.name[0...22] + "..." : track.name
        @small_font.draw_text(track_name, checkbox_x + 20, current_y, ZOrder::UI)
        
        # Store track dimension for click detection
        track.dim = Dimension.new(checkbox_x, current_y, checkbox_x + left_panel_width - 20, current_y + 12)
        
        current_y += 18
      break if current_y > max_display_y
      end
      
      current_y += 5 # spacing between albums
    end

    # Add selected tracks button (fixed position)
    if !@selected_tracks_for_playlist.empty?
      add_button_y = SCREEN_H - BAR_HEIGHT - 50
      Gosu.draw_rect(x_start, add_button_y, 180, 25, Gosu::Color::GREEN, ZOrder::UI)
      @small_font.draw_text("Add Selected (#{@selected_tracks_for_playlist.length})", x_start + 5, add_button_y + 5, ZOrder::UI)
    end

    # Current playlist tracks (right panel)
    @menu_font.draw_text("Playlist Tracks:", right_panel_x, add_y, ZOrder::UI)
    
    # Play playlist button at top of right panel
    if !@selected_playlist.tracks.empty?
      play_button_y = add_y + 25
      Gosu.draw_rect(right_panel_x, play_button_y, 100, 25, Gosu::Color::GREEN, ZOrder::UI)
      @small_font.draw_text("Play Playlist", right_panel_x + 10, play_button_y + 5, ZOrder::UI)
      playlist_start_y = play_button_y + 35
    else
      playlist_start_y = add_y + 30
    end
    
    # Display playlist tracks
    @selected_playlist.tracks.each_with_index do |track, i|
      track_y = playlist_start_y + i * 22
      break if track_y > SCREEN_H - BAR_HEIGHT - 30
      
      # Highlight currently playing track
      if @playing_from_playlist && i == @current_playlist_track
        Gosu.draw_rect(right_panel_x - 3, track_y - 1, right_panel_width, 18, Gosu::Color.argb(0x44FFFF00), ZOrder::UI)
      end
      
      # Track info (truncate if too long)
      track_text = "#{i + 1}. #{track.full_name}"
      if track_text.length > 20
        track_text = track_text[0...17] + "..."
      end
      @small_font.draw_text(track_text, right_panel_x, track_y, ZOrder::UI)
      
      # Remove button
      remove_x = right_panel_x + right_panel_width - 25
      Gosu.draw_rect(remove_x, track_y, 20, 15, Gosu::Color::RED, ZOrder::UI)
      @small_font.draw_text("X", remove_x + 6, track_y + 1, ZOrder::UI)
    end
  end

  # Determine hovered album index
  def hovered_album_index
    return nil if @current_view != :library
    mx,my = mouse_x, mouse_y
    @album_positions.find_index { |d| mx.between?(d.left,d.right) && my.between?(d.top,d.bottom) }
  end

  # Draw album grid with hover border effect
  def draw_album_grid
    @albums.each_with_index do |alb, i|
      dim = @album_positions[i]
      # Draw artwork at fixed scale
      alb.artwork.draw(dim.left, dim.top, ZOrder::UI, ARTWORK_SCALE, ARTWORK_SCALE)
      # Draw only border on hover
      if hovered_album_index == i
        left   = dim.left - 2
        top    = dim.top - 2
        right  = dim.right + 2
        bottom = dim.bottom + 2
        # Top border
        Gosu.draw_rect(left, top, right - left, 4, Gosu::Color::YELLOW, ZOrder::UI)
        # Bottom border
        Gosu.draw_rect(left, bottom - 4, right - left, 4, Gosu::Color::YELLOW, ZOrder::UI)
        # Left border
        Gosu.draw_rect(left, top, 4, bottom - top, Gosu::Color::YELLOW, ZOrder::UI)
        # Right border
        Gosu.draw_rect(right - 4, top, 4, bottom - top, Gosu::Color::YELLOW, ZOrder::UI)
      end
    end
  end

  # Draw track list with current indicator
  def draw_track_list
    x0 = SCREEN_W-200; y = 20
    @albums[@current_album].tracks.each_with_index do |tr,i|
      @font.draw_text(tr.name,x0,y,ZOrder::UI)
      w=@font.text_width(tr.name); h=@font.height
      tr.dim = Dimension.new(x0,y,x0+w,y+h)
      if (!@playing_from_playlist && i==@current_track)
        Gosu.draw_rect(x0-8,y,6,h,Gosu::Color::RED,ZOrder::UI)
      end
      y+=h+10
    end
  end

  # Draw Now Playing bar with correct controls
  def draw_now_playing_bar
    y0 = SCREEN_H - BAR_HEIGHT
    Gosu.draw_rect(0,y0,SCREEN_W,BAR_HEIGHT,Gosu::Color.argb(0xCC000000),ZOrder::UI)
    
    # Get current track safely
    tr = get_current_track
    if tr
      if @playing_from_playlist && @selected_playlist && tr.album
        tr.album.artwork.draw(10,y0+10,ZOrder::UI,0.2,0.2)
        @menu_font.draw_text(tr.album.artist,80,y0+40,ZOrder::UI)
        @font.draw_text(tr.name,80,y0+10,ZOrder::UI)
      elsif !@playing_from_playlist
        alb=@albums[@current_album]; alb.artwork.draw(10,y0+10,ZOrder::UI,0.2,0.2)
        @font.draw_text(tr.name,80,y0+10,ZOrder::UI); @menu_font.draw_text(alb.artist,80,y0+40,ZOrder::UI)
      else
        # Fallback for playlist tracks without album info
        @font.draw_text(tr.name,80,y0+10,ZOrder::UI)
        @menu_font.draw_text("Unknown Artist",80,y0+40,ZOrder::UI)
      end
    else
      # No track available
      @font.draw_text("No Track",80,y0+10,ZOrder::UI)
      @menu_font.draw_text("No Artist",80,y0+40,ZOrder::UI)
    end
    
    cx=SCREEN_W/2; cy=y0+30
    draw_prev_icon(cx-60,cy)
    if @playing
      draw_pause_icon(cx-20,cy)
    else
      draw_play_icon(cx-20,cy)
    end
    draw_next_icon(cx+20,cy)
    # Seek bar
    bx, by, bw, bh = cx-200, y0+70, 400, 5
    Gosu.draw_rect(bx, by, bw, bh, Gosu::Color::GRAY, ZOrder::UI)
    if @start_time && @song_length
      elapsed = (Gosu.milliseconds / 1000.0) - @start_time
      elapsed = @song_length if elapsed > @song_length
      prog = bw * elapsed / @song_length
      Gosu.draw_rect(bx, by, prog, bh, Gosu::Color::WHITE, ZOrder::UI)
      Gosu.draw_rect(bx + prog - 5, by - 5, 10, bh + 10, Gosu::Color::WHITE, ZOrder::UI)
    end
    # Volume
    vx,vy,vw,vh=SCREEN_W-150,y0+60,100,5
    Gosu.draw_rect(vx,vy,vw,vh,Gosu::Color::GRAY,ZOrder::UI)
    Gosu.draw_rect(vx,vy,vw*@volume,vh,Gosu::Color::WHITE,ZOrder::UI)
    Gosu.draw_rect(vx+vw*@volume-5,vy-5,10,vh+10,Gosu::Color::WHITE,ZOrder::UI)
  end

  # Update fade and auto-advance
  def update
    @bg_alpha = [@bg_alpha + 5, 255].min if @bg_alpha < 255
    # Auto-advance when elapsed >= song_length
    if @playing && @start_time && @song_length
      elapsed = (Gosu.milliseconds / 1000.0) - @start_time
      next_track if elapsed >= @song_length
    end
  end

  # Handle clicks
  def button_down(id)
    return unless id==Gosu::MsLeft
    mx,my=mouse_x,mouse_y
    handle_sidebar_click(mx,my) || handle_main_content_click(mx,my) || handle_playback_controls(mx,my)
  end

  def handle_sidebar_click(mx, my)
    return false unless mx < SIDEBAR_WIDTH
    
    y = 50
    MENU_ITEMS.each_with_index do |item, i|
      if my.between?(y, y + 30)
        case item
        when 'Library'
          @current_view = :library
        when 'Playlists'
          @current_view = :playlists
          @creating_playlist = false
          @playlist_name_input = ""
          @selected_tracks_for_playlist = []
        end
        return true
      end
      y += 40
    end
    false
  end

  def handle_main_content_click(mx, my)
    case @current_view
    when :library
      handle_album_click(mx, my) || handle_track_click(mx, my)
    when :playlists
      handle_playlist_view_click(mx, my)
    when :playlist_detail
      handle_playlist_detail_click(mx, my)
    else
      false
    end
  end

  def handle_playlist_view_click(mx, my)
    x_start = SIDEBAR_WIDTH + 20
    
    # Create playlist button
    button_y = 70
    # Create playlist button
    if mx.between?(x_start, x_start + 150) && my.between?(button_y, button_y + 30)
      @creating_playlist = !@creating_playlist
      if @creating_playlist
        @text_input = Gosu::TextInput.new
        self.text_input = @text_input
      else
        self.text_input = nil
      end
      return true
    end

    # Handle playlist creation UI
    if @creating_playlist
      input_y = button_y + 40
      
      # Create button
      if mx.between?(x_start + 210, x_start + 270) && my.between?(input_y, input_y + 25)
        name = @text_input.text.strip
        if name.length > 0
          @playlists << Playlist.new(name)
          @creating_playlist = false
          self.text_input = nil
        end
        return true
      end

      # Cancel button
      if mx.between?(x_start + 275, x_start + 335) && my.between?(input_y, input_y + 25)
        @creating_playlist = false
        self.text_input = nil
        return true
      end
    end

    # Click on existing playlists
    @playlists.each_with_index do |playlist, i|
      next unless playlist.dim
      
      if mx.between?(playlist.dim.left, playlist.dim.right) && my.between?(playlist.dim.top, playlist.dim.bottom)
        # Check if clicking delete button
        if mx.between?(playlist.dim.left + 350, playlist.dim.left + 390)
          @playlists.delete_at(i)
          # If we're currently playing from the deleted playlist, switch back to library
          if @playing_from_playlist && @selected_playlist == playlist
            @playing_from_playlist = false
            @selected_playlist = nil
            play_current
          end
        else
          # Open playlist detail
          @selected_playlist = playlist
          @current_view = :playlist_detail
          @selected_tracks_for_playlist = []
        end
        return true
      end
    end

    false
  end

  def handle_playlist_detail_click(mx, my)
    return false unless @selected_playlist
    
    x_start = SIDEBAR_WIDTH + 20
    content_width = SCREEN_W - SIDEBAR_WIDTH - 40
    left_panel_width = (content_width * 0.6).to_i
    right_panel_width = (content_width * 0.35).to_i
    right_panel_x = x_start + left_panel_width + 20
    
    # Back button
    if mx.between?(x_start, x_start + 80) && my.between?(20, 50)
      @current_view = :playlists
      @selected_playlist = nil
      @selected_tracks_for_playlist = []
      return true
    end

    # Track selection checkboxes
    @albums.each do |album|
      album.tracks.each do |track|
        next unless track.dim
        
        if mx.between?(track.dim.left, track.dim.right) && my.between?(track.dim.top, track.dim.bottom)
          if @selected_tracks_for_playlist.include?(track)
            @selected_tracks_for_playlist.delete(track)
          else
            @selected_tracks_for_playlist << track
          end
          return true
        end
      end
    end

    # Add selected tracks button
    if !@selected_tracks_for_playlist.empty?
      add_button_y = SCREEN_H - BAR_HEIGHT - 50
      if mx.between?(x_start, x_start + 180) && my.between?(add_button_y, add_button_y + 25)
        @selected_tracks_for_playlist.each do |track|
          @selected_playlist.add_track(track)
        end
        @selected_tracks_for_playlist = []
        return true
      end
    end

    # Play playlist button
    if !@selected_playlist.tracks.empty?
      add_y = 90
      play_button_y = add_y + 25
      if mx.between?(right_panel_x, right_panel_x + 100) && my.between?(play_button_y, play_button_y + 25)
        @playing_from_playlist = true
        @current_playlist_track = 0
        play_current
        return true
      end
    end

    # Remove track from playlist (updated coordinates)
    add_y = 90
    playlist_start_y = !@selected_playlist.tracks.empty? ? add_y + 60 : add_y + 30
    
    @selected_playlist.tracks.each_with_index do |track, i|
      track_y = playlist_start_y + i * 22
      remove_x = right_panel_x + right_panel_width - 25
      
      if mx.between?(remove_x, remove_x + 20) && my.between?(track_y, track_y + 15)
        # If we're currently playing this track, stop the music
        if @playing_from_playlist && i == @current_playlist_track
          @song&.stop
          @playing = false
        end
        
        @selected_playlist.remove_track(i)
        
        # Adjust current playlist track index
        if @playing_from_playlist
          if @selected_playlist.tracks.empty?
            # If playlist is now empty, switch back to library mode
            @playing_from_playlist = false
            play_current
          elsif i <= @current_playlist_track
            # If we removed a track before or at current position, adjust index
            @current_playlist_track = [@current_playlist_track - 1, 0].max
            if @current_playlist_track < @selected_playlist.tracks.length
              play_current
            end
          end
        end
        return true
      end
    end

    false
  end

  def handle_album_click(mx,my)
    return false if @current_view != :library
    @album_positions.each_with_index{|d,i| if mx.between?(d.left,d.right)&&my.between?(d.top,d.bottom)
        @current_album,@current_track=i,0; @playing_from_playlist = false; play_current; return true; end}; false
  end

  def handle_track_click(mx,my)
    return false if @current_view != :library
    @albums[@current_album].tracks.each_with_index{|tr,i|
      if tr.dim&&mx.between?(tr.dim.left,tr.dim.right)&&my.between?(tr.dim.top,tr.dim.bottom)
        @current_track=i; @playing_from_playlist = false; play_current; return true; end}; false
  end

  # Handle clicks for prev, play/pause, next with explicit hitboxes
  def handle_playback_controls(mx, my)
    cy = SCREEN_H - BAR_HEIGHT + 30
    cx = SCREEN_W / 2

    # Icon centers and hit area
    prev_x = cx - 60
    mid_x  = cx - 20
    next_x = cx + 20
    half_w = CONTROL_SIZE + 10
    half_h = CONTROL_SIZE

    # Prev: click around prev icon
    if mx.between?(prev_x - half_w, prev_x + half_w) && my.between?(cy - half_h, cy + half_h)
      if @song.respond_to?(:position) && @song.position > 1.0
        play_current
      else
        previous_track
      end
      return true
    end

    # Play/Pause: click around mid icon
    if mx.between?(mid_x - half_w, mid_x + half_w) && my.between?(cy - half_h, cy + half_h)
      toggle_pause
      return true
    end

    # Next: click around next icon
    if mx.between?(next_x - half_w, next_x + half_w) && my.between?(cy - half_h, cy + half_h)
      next_track
      return true
    end

    # Seek bar
    sx, sy, sw, sh = cx - 200, SCREEN_H - BAR_HEIGHT + 70, 400, 10
    return true if mx.between?(sx, sx + sw) && my.between?(sy, sy + sh)

    # Volume slider
    vx, vy, vw, vh = SCREEN_W - 150, SCREEN_H - BAR_HEIGHT + 60, 100, 10
    if mx.between?(vx, vx + vw) && my.between?(vy, vy + vh)
      @volume = (mx - vx) / vw.to_f
      @song.volume = @volume if @song.respond_to?(:volume=)
      return true
    end

    false
  end

  def next_track
    if @playing_from_playlist && @selected_playlist
      if !@selected_playlist.tracks.empty?
        @current_playlist_track = (@current_playlist_track + 1) % @selected_playlist.tracks.size
        play_current
      end
    else
      @current_track = (@current_track + 1) % @albums[@current_album].tracks.size
      play_current
    end
  end

  def previous_track
    if @playing_from_playlist && @selected_playlist
      if !@selected_playlist.tracks.empty?
        @current_playlist_track = (@current_playlist_track - 1) % @selected_playlist.tracks.size
        play_current
      end
    else
      @current_track = (@current_track - 1) % @albums[@current_album].tracks.size
      play_current
    end
  end

  def toggle_pause
    return unless @song
    if @playing
      @song.pause
    else
      begin; @song.resume; rescue; @song.play(false); @song.volume=@volume if @song.respond_to?(:volume=); end
    end; @playing=!@playing
  end

  # Draw shapes for controls
  def draw_prev_icon(cx,y)
    size=10
    # two left-pointing triangles
    Gosu.draw_triangle(cx+size,y-size,Gosu::Color::WHITE,
                       cx+size,y+size,Gosu::Color::WHITE,
                       cx,y,Gosu::Color::WHITE,ZOrder::UI)
    offset=size+4
    Gosu.draw_triangle(cx+size-offset,y-size,Gosu::Color::WHITE,
                       cx+size-offset,y+size,Gosu::Color::WHITE,
                       cx-offset,y,Gosu::Color::WHITE,ZOrder::UI)
  end

  def draw_next_icon(cx,y)
    size=10
    # two right-pointing triangles
    Gosu.draw_triangle(cx-size,y-size,Gosu::Color::WHITE,
                       cx-size,y+size,Gosu::Color::WHITE,
                       cx,y,Gosu::Color::WHITE,ZOrder::UI)
    offset=size+4
    Gosu.draw_triangle(cx-size+offset,y-size,Gosu::Color::WHITE,
                       cx-size+offset,y+size,Gosu::Color::WHITE,
                       cx+offset,y,Gosu::Color::WHITE,ZOrder::UI)
  end

  def draw_play_icon(cx,y)
    size=10
    # single right-pointing triangle
    Gosu.draw_triangle(cx,y-size,Gosu::Color::WHITE,
                       cx,y+size,Gosu::Color::WHITE,
                       cx+size,y,Gosu::Color::WHITE,ZOrder::UI)
  end

  def draw_pause_icon(cx,y)
    bar_w=4; bar_h=20; gap=6
    Gosu.draw_rect(cx-gap-bar_w,y-bar_h/2,bar_w,bar_h,Gosu::Color::WHITE,ZOrder::UI)
    Gosu.draw_rect(cx+gap,y-bar_h/2,bar_w,bar_h,Gosu::Color::WHITE,ZOrder::UI)
  end

  # Main draw
  def draw
    draw_background
    draw_sidebar
    draw_main_content
    draw_now_playing_bar
  end

  def needs_cursor?; true; end
end

MusicPlayerMain.new.show if __FILE__==$0