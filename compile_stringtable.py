import os
import xml.etree.ElementTree as ET

def indent(elem, level=0):
    i = "\n" + level*"    "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "    "
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
        for child in elem:
            indent(child, level+1)
        if not child.tail or not child.tail.strip():
            child.tail = i
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = i

def main():
    root_dir = os.path.dirname(os.path.abspath(__file__))
    functions_dir = os.path.join(root_dir, 'Functions')
    stringtable_path = os.path.join(root_dir, 'stringtable.xml')
    
    # Load existing stringtable to preserve root or create new
    try:
        tree = ET.parse(stringtable_path)
        project = tree.getroot()
    except Exception:
        project = ET.Element('Project', name="Mission")
        
    # Remove existing packages to replace them with fresh ones
    for pkg in list(project):
        if pkg.tag == 'Package':
            project.remove(pkg)
            
    # Parse fn_*.xml from Functions/ folders
    for folder in sorted(os.listdir(functions_dir)):
        folder_path = os.path.join(functions_dir, folder)
        if os.path.isdir(folder_path):
            package = ET.Element('Package', name=folder)
            keys_added = False
            
            for file in sorted(os.listdir(folder_path)):
                if file.endswith('.xml') and (file.startswith('fn_') or file.startswith('task')):
                    xml_path = os.path.join(folder_path, file)
                    try:
                        key_tree = ET.parse(xml_path)
                        root = key_tree.getroot()
                        keys = root.findall('.//Key') if root.tag == 'Keys' else [root] if root.tag == 'Key' else []
                        for key in keys:
                            package.append(key)
                            keys_added = True
                    except Exception as e:
                        print(f"Error parsing {xml_path}: {e}")
                        
            if keys_added:
                project.append(package)

    indent(project)
    
    xml_str = ET.tostring(project, encoding='utf-8', xml_declaration=True).decode('utf-8')

    with open(stringtable_path, 'w', encoding='utf-8') as f:
        f.write(xml_str)
        
    print("stringtable.xml generated successfully!")

if __name__ == "__main__":
    main()
