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
        
    # Le texte %1 et tout ce qu'il y a après ne doit pas être récupéré
    text = re.split(r"%\d+", text)[0]
    
    text = re.sub(r"<[^>]+>", "", text)
    
    return text.strip()

def apply_radio_effect(audio, intensity=1.5):
    # 1. Bandpass filter
    # On laisse passer un peu plus de fréquences pour que la voix reste compréhensible
    radio = audio.high_pass_filter(400).low_pass_filter(2500)
    
    # 2. Plus de voix et énorme saturation
    # On monte très fort le gain pour saturer le signal de base
    radio = radio.apply_gain(15)
    
    # 3. Saturation et compression extrêmes pour écraser le son (effet radio cassée)
    radio = radio + (25 * intensity)
    radio = radio.compress_dynamic_range(threshold=-30, ratio=20, attack=1, release=20)
    
    # 4. Bruit de fond (statique)
    noise_dur = len(radio)
    noise1 = WhiteNoise().to_audio_segment(duration=noise_dur).apply_gain(-15 * intensity)
    noise2 = WhiteNoise().to_audio_segment(duration=noise_dur).high_pass_filter(2000).apply_gain(-12 * intensity)
    
    final = radio.overlay(noise1).overlay(noise2)
    
    # 5. Squelch d'entrée et de sortie
    squelch_in = (WhiteNoise().to_audio_segment(80).apply_gain(-2) +
                  Sine(1500).to_audio_segment(50).apply_gain(-5))
    squelch_out = (Sine(1000).to_audio_segment(100).apply_gain(-6) +
                   WhiteNoise().to_audio_segment(150).apply_gain(-3))
    
    final = squelch_in + final + squelch_out
    
    # 6. Écrêtage (clipping) final en forçant le gain
    final = final.apply_gain(5)
    
    return final

def generate_tts(text, output_path):
    # Utilisation de edge-tts avec voix masculine normale
    voice = "en-US-GuyNeural"
    cmd = ["edge-tts", "--voice", voice, "--rate=+0%", "--text", text, "--write-media", output_path]
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
                
                import time
                time.sleep(1) # Pause d'une seconde pour éviter le rate-limit de Microsoft Edge TTS
                
            except Exception as e:
                print(f"Erreur sur {key_id} : {e}")
                
    if os.path.exists(temp_file):
        try:
            os.remove(temp_file)
        except:
            pass
        
    print(f"\nTerminé ! {count} fichiers audio générés dans {OUTPUT_DIR}")

if __name__ == "__main__":
    main()
