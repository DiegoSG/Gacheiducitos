#!/usr/bin/env python3
"""
Script to extract, clean, and crop generated RPG sprites to transparent PNGs.
Follows RPG-G standards: lives in rpg-g/tools/asset_tools/.
"""
from PIL import Image
import numpy as np
import os
from collections import deque

def clean_and_crop_sprite(input_path: str, output_path: str, bg_tolerance: int = 35) -> None:
    img = Image.open(input_path).convert("RGBA")
    arr = np.array(img)
    h, w, _ = arr.shape
    
    corners = np.array([
        arr[0, 0, :3],
        arr[0, -1, :3],
        arr[-1, 0, :3],
        arr[-1, -1, :3]
    ])
    bg_color = np.median(corners, axis=0).astype(np.float32)
    
    visited = np.zeros((h, w), dtype=bool)
    is_bg = np.zeros((h, w), dtype=bool)
    queue = deque()
    
    for x in range(w):
        queue.append((0, x))
        queue.append((h - 1, x))
        visited[0, x] = True
        visited[h - 1, x] = True
    for y in range(h):
        queue.append((y, 0))
        queue.append((y, w - 1))
        visited[y, 0] = True
        visited[y, w - 1] = True
        
    rgb = arr[:, :, :3].astype(np.float32)
    
    while queue:
        cy, cx = queue.popleft()
        
        diffs = [np.linalg.norm(rgb[cy, cx] - c) for c in corners]
        diffs.append(np.linalg.norm(rgb[cy, cx] - bg_color))
        min_diff = min(diffs)
        
        if min_diff <= bg_tolerance:
            is_bg[cy, cx] = True
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                    visited[ny, nx] = True
                    queue.append((ny, nx))

    arr[is_bg, 3] = 0
    result = Image.fromarray(arr, mode="RGBA")
    
    bbox = result.getbbox()
    if bbox:
        cropped = result.crop(bbox)
        pad = 4
        padded = Image.new("RGBA", (cropped.width + pad * 2, cropped.height + pad * 2), (0, 0, 0, 0))
        padded.paste(cropped, (pad, pad))
        result = padded
        
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    result.save(output_path, "PNG")
    print(f"Processed: {os.path.basename(input_path)} -> {output_path} ({result.width}x{result.height})")

def main():
    brain_dir = "/home/diego/.gemini/antigravity-cli/brain/ec3151f4-84ec-427d-a2df-648270e02900"
    assets_dir = "/home/diego/GameProjects/Gacheiducitos/rpg-g/assets/sprites"
    
    targets = [
        ("chest_closed_1789332236672.jpg", "chest_closed.png", 35),
        ("chest_open_1789332260122.jpg", "chest_open.png", 35),
        ("spider_enemy_1789332283692.jpg", "spider_enemy.png", 35),
        ("npc_kawaii_cat_1789332324591.jpg", "npc_kawaii_cat.png", 35),
        ("straw_dummy_1789332407976.jpg", "straw_dummy.png", 35),
        ("player_character_1789332620224.jpg", "player.png", 35),
        ("slash_effect_1789332713643.jpg", "slash_effect.png", 40)
    ]
    
    for in_name, out_name, tol in targets:
        in_path = os.path.join(brain_dir, in_name)
        out_path = os.path.join(assets_dir, out_name)
        if os.path.exists(in_path):
            clean_and_crop_sprite(in_path, out_path, tol)
        else:
            print(f"Warning: {in_path} not found!")

if __name__ == "__main__":
    main()
