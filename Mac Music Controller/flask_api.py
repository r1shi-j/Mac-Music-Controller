import io
import os
import subprocess
from flask import Flask, jsonify, send_file, request

ARTWORK_CACHE_PATH = os.path.expanduser("~/tmp_mac_artwork_cache.jpg")

app = Flask(__name__)

def run_applescript(script):
  return subprocess.run(['osascript', '-e', script], capture_output=True, text=True).stdout.strip()

@app.route('/music/play', methods=['POST'])
def play_music():
    run_applescript('tell application "Music" to play')
    return jsonify({'status': 'success', 'message': 'Music played'})

@app.route('/music/pause', methods=['POST'])
def pause_music():
    run_applescript('tell application "Music" to pause')
    return jsonify({'status': 'success', 'message': 'Music paused'})

@app.route("/music/previous", methods=["POST"])
def previous_track():
  run_applescript('tell application "Music" to previous track')
  return jsonify({"status": "success", "message": "Backwards a track"})

@app.route("/music/next", methods=["POST"])
def next_track():
  run_applescript('tell application "Music" to next track')
  return jsonify({"status": "success", "message": "Skipped track"})

@app.route("/music/favorite", methods=["POST"])
def toggle_favorite():
  script = """
    tell application "Music"
        try
            set currentFav to favorited of current track
            set favorited of current track to not currentFav
            return not currentFav
        on error
            set currentLove to loved of current track
            set loved of current track to not currentLove
            return not currentLove
        end try
    end tell
    """
  res = run_applescript(script)
  return jsonify({"status": "success", "is_favorite": res == "true"})

@app.route("/system/volume", methods=["GET"])
def get_system_volume():
  res = run_applescript("output volume of (get volume settings)")
  vol = int(res) if res.isdigit() else 10
  return jsonify({"status": "success", "volume": vol})


@app.route("/system/volume", methods=["POST"])
def set_system_volume():
  data = request.get_json() or {}
  vol = data.get("volume", 10)
  run_applescript(f"set volume output volume {vol}")
  return jsonify({"status": "success", "system_volume": vol})


@app.route("/music/volume", methods=["GET"])
def get_music_volume():
  res = run_applescript('tell application "Music" to get sound volume')
  vol = int(res) if res.isdigit() else 10
  return jsonify({"status": "success", "volume": vol})


@app.route("/music/volume", methods=["POST"])
def set_music_volume():
  data = request.get_json() or {}
  vol = data.get("volume", 10)
  run_applescript(f'tell application "Music" to set sound volume to {vol}')
  return jsonify({"status": "success", "music_volume": vol})


@app.route('/music/status', methods=['GET'])
def get_status():
  # Run individual safe queries via single-line osascript calls
  def get_as(cmd):
    res = subprocess.run(
        ['osascript', '-e', f'tell application "Music" to {cmd}'],
        capture_output=True,
        text=True,
    )
    return res.stdout.strip() if res.returncode == 0 else ''

  # Check if music is running first
  running = get_as('ilé (it is running)')  # or check process
  # Simpler check:
  is_running = (
      subprocess.run(
          [
              'osascript',
              '-e',
              'application "Music" is running',
          ],
          capture_output=True,
          text=True,
      )
      .stdout.strip()
      == 'true'
  )

  if not is_running:
    return jsonify({
        'status': 'error',
        'title': 'Music Not Running',
        'artist': '',
        'duration': 0.0,
        'position': 0.0,
        'is_playing': False,
        'is_favorite': False,
    })

  track_name = get_as('get name of current track')
  track_artist = get_as('get artist of current track')
  track_duration = get_as('get duration of current track')
  track_position = get_as('get player position')
  player_state = get_as('get player state as string')

  # Favorite handling
  fav_res = subprocess.run(
      [
          'osascript',
          '-e',
          'tell application "Music" to get favorited of current track',
      ],
      capture_output=True,
      text=True,
  )
  is_fav = fav_res.stdout.strip().lower() == 'true'

  return jsonify({
      'status': 'success',
      'title': track_name if track_name else 'Unknown Track',
      'artist': track_artist if track_artist else 'Unknown Artist',
      'duration': float(track_duration) if track_duration.replace('.', '', 1).isdigit() else 0.0,
      'position': float(track_position) if track_position.replace('.', '', 1).isdigit() else 0.0,
      'is_playing': player_state == 'playing',
      'is_favorite': is_fav,
  })

@app.route("/music/artwork", methods=["GET"])
def get_artwork():
  script = f"""
    tell application "Music"
        if it is running then
            try
                set theTrack to current track
                tell artwork 1 of theTrack
                    set rawData to raw data
                end tell
                
                set targetPath to POSIX file "{ARTWORK_CACHE_PATH}"
                set fileRef to open for access targetPath with write permission
                set eof fileRef to 0
                write rawData to fileRef starting at 0
                close access fileRef
                return "Success"
            on error errStr
                try
                    close access targetPath
                end try
                return "Error: " & errStr
            end try
        end if
        return "Not Running"
    end tell
    """
  result = subprocess.run(
      ["osascript", "-e", script], capture_output=True, text=True
  ).stdout.strip()

  if result != "Success" or not os.path.exists(ARTWORK_CACHE_PATH):
    return jsonify({"error": "No artwork found"}), 404

  return send_file(ARTWORK_CACHE_PATH, mimetype="image/jpeg")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
