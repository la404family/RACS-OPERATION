import os
import re
import xml.etree.ElementTree as ET
import subprocess
from pydub import AudioSegment
from pydub.generators import Sine, WhiteNoise

# Chemin vers la racine du projet
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XML_PATH = os.path.join(ROOT_DIR, "stringtable.xml")
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")

def clean_text(text):
    if not text:
        return ""
    
    # Ignorer complètement les actions
    if "<t color" in text or text.startswith("["):
        return ""
        
    text = re.sub(r"%\d+", "something", text)
    text = re.sub(r"<[^>]+>", "", text)
    
    return text.strip()

def apply_radio_effect(audio):
    """
    Applique un effet de radio militaire intense.
    """
    # 1. Filtre passe-haut (300Hz) et passe-bas (3000Hz)
    radio = audio.high_pass_filter(300).low_pass_filter(3000)
    
    # 2. Saturation (Overdrive) : On adoucit un peu pour éviter l'effet trop "criard"
    radio = radio + 10 # Boost modéré
    radio = radio - 10 # On rebaisse
    
    # 3. Bruit statique (Grésillement réduit)
    noise = WhiteNoise().to_audio_segment(duration=len(radio)) - 22 # Bruit de fond plus doux
    # Crépitement moins fort
    crackle = WhiteNoise().to_audio_segment(duration=len(radio)).high_pass_filter(2000) - 15

    
    radio_with_noise = radio.overlay(noise).overlay(crackle)
    
    # 4. Squelch (clic radio / bip)
    beep_start = Sine(1500).to_audio_segment(duration=80).apply_gain(-8)
    beep_end = Sine(1500).to_audio_segment(duration=120).apply_gain(-8)
    click = WhiteNoise().to_audio_segment(duration=60).apply_gain(-5)
    
    squelch_in = click + beep_start
    squelch_out = beep_end + click
    
    final_audio = squelch_in + radio_with_noise + squelch_out
    
    return final_audio

def generate_tts(text, output_path):
    # Utilisation de edge-tts avec une voix d'homme sérieuse et réaliste
    voice = "en-US-GuyNeural" # Voix masculine US très naturelle
    # edge-tts est appelé en ligne de commande
    cmd = ["edge-tts", "--voice", voice, "--rate", "+0%", "--text", text, "--write-media", output_path]
    subprocess.run(cmd, check=True)

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        
    tree = ET.parse(XML_PATH)
    root = tree.getroot()
    
    count = 0
    temp_file = os.path.join(OUTPUT_DIR, "temp.mp3")
    
    for key in root.findall(".//Key"):
        key_id = key.get("ID")
        english_node = key.find("English")
        
        if english_node is not None and english_node.text:
            text = clean_text(english_node.text)
            
            if not text:
                continue
                
            out_file = os.path.join(OUTPUT_DIR, f"{key_id}.ogg")
            print(f"[TTS] Génération pour {key_id} : '{text}'")
            
            try:
                # 1. Générer le TTS avec la voix d'homme Microsoft Azure
                generate_tts(text, temp_file)
                
                # 2. Appliquer les gros effets radio
                audio = AudioSegment.from_mp3(temp_file)
                radio_audio = apply_radio_effect(audio)
                
                # 3. Sauvegarder (écrase l'ancien)
                radio_audio.export(out_file, format="ogg")
                count += 1
                
            except Exception as e:
                print(f"Erreur sur {key_id} : {e}")
                
    if os.path.exists(temp_file):
        os.remove(temp_file)
        
    print(f"\nTerminé ! {count} fichiers audio générés dans {OUTPUT_DIR}")

if __name__ == "__main__":
    main()
