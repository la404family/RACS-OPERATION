import os

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
TTS_OUTPUT_DIR = os.path.join(ROOT_DIR, "TTS", "output")
CFG_SOUNDS_PATH = os.path.join(ROOT_DIR, "CfgSounds.hpp")

def main():
    if not os.path.exists(TTS_OUTPUT_DIR):
        print(f"Directory not found: {TTS_OUTPUT_DIR}")
        return

    with open(CFG_SOUNDS_PATH, "w", encoding="utf-8") as f:
        f.write("// Fichier généré automatiquement par update_sounds.py\n\n")
        
        count = 0
        for filename in os.listdir(TTS_OUTPUT_DIR):
            if filename.endswith(".ogg"):
                class_name = filename[:-4] # enlever .ogg
                # Le chemin doit utiliser des anti-slash ou slash, Arma préfère les anti-slash mais les deux marchent
                # CfgSounds s'attend à un chemin relatif à la racine de la mission
                path = f"TTS\\output\\{filename}"
                
                f.write(f"class {class_name} {{\n")
                f.write(f'    name = "{class_name}";\n')
                f.write(f'    sound[] = {{"{path}", 2, 1, 100}};\n')
                f.write(f"    titles[] = {{}};\n")
                f.write(f"}};\n\n")
                count += 1
                
    print(f"Généré {count} sons dans {CFG_SOUNDS_PATH}")

if __name__ == "__main__":
    main()
