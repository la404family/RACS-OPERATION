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

# Liste stricte des clés réellement utilisées en tant qu'audio radio/sfx dans les scripts SQF
ALLOWED_KEYS = {
    # Support Drone
    "STR_Drone_AlreadyActive", "STR_Drone_AlreadyActive_Wait", "STR_Drone_Approach",
    "STR_Drone_Available", "STR_Drone_ClickMap", "STR_Drone_EnRoute", "STR_Drone_RTB",
    
    # Leader & Squad Actions
    "STR_LL_AssignLeader_Changed", "STR_LL_HealAction_Healing", "STR_LL_HealAction_NoKits",
    "STR_LL_HealAction_NoWounded", "STR_LL_RoeAction_Changed",
    
    # Support Hélicoptère (CAS, Drops, Transport)
    "STR_LL_Heli_Action_CASCooldown", "STR_LL_Heli_Action_ClickMap", "STR_LL_Heli_Action_EnRoute",
    "STR_LL_Heli_Action_VehicleAlready", "STR_LL_Heli_Dispatch_Abort_CAS",
    "STR_LL_Heli_Dispatch_Abort_DEBARQUEMENT", "STR_LL_Heli_Dispatch_Abort_DEFAULT",
    "STR_LL_Heli_Dispatch_Abort_LIVRAISON", "STR_LL_Heli_Dispatch_Abort_VEHICULE",
    "STR_LL_Heli_Dispatch_Approve_CAS", "STR_LL_Heli_Dispatch_Approve_DEBARQUEMENT",
    "STR_LL_Heli_Dispatch_Approve_DEFAULT", "STR_LL_Heli_Dispatch_Approve_EMBARQUEMENT",
    "STR_LL_Heli_Dispatch_Approve_LIVRAISON", "STR_LL_Heli_Dispatch_Approve_VEHICULE",
    "STR_LL_Heli_Dispatch_Cooldown", "STR_LL_Heli_Dispatch_Deny_CAS", "STR_LL_Heli_Dispatch_Deny_DEBARQUEMENT",
    "STR_LL_Heli_Dispatch_Deny_DEFAULT", "STR_LL_Heli_Dispatch_Deny_EMBARQUEMENT",
    "STR_LL_Heli_Dispatch_Deny_LIVRAISON", "STR_LL_Heli_Dispatch_Deny_VEHICULE",
    "STR_LL_Heli_Dispatch_New_DEFAULT", "STR_LL_Heli_Dispatch_New_EMBARQUEMENT",
    "STR_LL_Heli_Dispatch_VehicleAlready", "STR_LL_Heli_Msg_Active", "STR_LL_Heli_Msg_CargoAborted",
    "STR_LL_Heli_Msg_Departing", "STR_LL_Heli_Msg_Extract_Players_Exit_Warning",
    "STR_LL_Heli_Msg_Killed", "STR_LL_Heli_Msg_Landed_Extract", "STR_LL_Heli_Msg_Landed_Reinforce",
    "STR_LL_Heli_Msg_Patrol_Started", "STR_LL_Heli_Msg_Squad_Joined",
    
    # Livraisons / Ravitaillement
    "STR_LL_Msg_Resupply_Done", "STR_LL_Msg_Resupply_NoAI", "STR_LL_Msg_Resupply_Start",
    "STR_TAG_Msg_Ammo_Dropped", "STR_TAG_Msg_CAS_RTB", "STR_TAG_Msg_Vehicle_Dropped",
    
    # Alertes de scénario & Tâches
    "STR_LL_Task_03_Warning", "STR_LL_Task_05_Alert", "STR_LL_Task_Assigned"
}

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
        if key_id not in ALLOWED_KEYS:
            continue
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
