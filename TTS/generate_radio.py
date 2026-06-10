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

def apply_radio_effect(audio, intensity=1.0, background=None):
    # Filtrage radio militaire plus agressif
    radio = audio.high_pass_filter(280).low_pass_filter(3100)
    
    # Distorsion + saturation plus réaliste
    radio = radio + (8 * intensity)
    radio = radio.compress_dynamic_range(threshold=-20, ratio=6, attack=5, release=50)
    
    # Bruit de fond + crépitement
    noise = WhiteNoise().to_audio_segment(duration=len(radio)).high_pass_filter(1800) - (18 * intensity)
    crackle = (WhiteNoise().to_audio_segment(duration=len(radio))
               .high_pass_filter(2500)
               .low_pass_filter(8000) - 12)
    
    final = radio.overlay(noise).overlay(crackle)
    
    # Squelch plus "militaire"
    squelch_in = (WhiteNoise().to_audio_segment(45).apply_gain(-6) +
                  Sine(1800).to_audio_segment(60).apply_gain(-9))
    squelch_out = (Sine(1200).to_audio_segment(110).apply_gain(-10) +
                   WhiteNoise().to_audio_segment(40).apply_gain(-7))
    
    final = squelch_in + final + squelch_out
    
    # Ajout de bruit de fond contextuel (hélico, vent, moteur, etc.)
    if background:
        bg = background[:len(final)].apply_gain(-25)
        final = final.overlay(bg)
    
    # Clipping léger (très caractéristique des vieilles radios militaires)
    # pydub n'a pas de méthode .clip, on se contente du gain qui forcera le clip à l'export
    final = final.apply_gain(3)
    
    return final

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
