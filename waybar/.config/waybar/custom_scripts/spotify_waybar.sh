#!/bin/bash

# Get the list of clients from Hyprland
clients=$(hyprctl clients)

# Search for the Spotify window and extract the song and artist
song_info=$(echo "$clients" | grep "title: Spotify - " | awk -F 'Spotify - ' '{print $2}' | sed -E 's/ • /,/' | head -n 1)

# Check if song_info is empty this means no spotify window is open
if [[ -z "$song_info" ]]; then
  echo "{\"text\": \" \"}"
fi

# Extract song and artist
song=$(echo "$song_info" | awk -F ',' '{print $1}')
artist=$(echo "$song_info" | awk -F ',' '{print $2}')

# Check if the title contains "Spotify" this means no song is playing
if [[ "$song" == *"Spotify"* ]]; then
  echo "{\"text\": \" \"}"
else
  # Output JSON in one line
  echo "{\"text\": \"  ${song} | ${artist}\"}"
fi
