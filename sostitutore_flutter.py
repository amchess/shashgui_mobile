import os
import re
import json
import shutil

def clean_key(text):
    """Crea una chiave camelCase pulita a partire dal testo italiano."""
    text = re.sub(r'[^a-zA-Z0-9\s]', '', text)
    words = text.strip().split()
    if not words: return "emptyKey"
    key = words[0].lower() + ''.join(w.capitalize() for w in words[1:])
    return key[:30]

def main():
    # Questa regex cattura: 1. Il prefisso (es. "const Text(") 2. Il testo 3. La virgoletta
    regex_str = r"((?:const\s+)?Text\(\s*|tooltip:\s*|label:\s*(?:const\s+)?Text\(\s*|label:\s*|hintText:\s*|title:\s*(?:const\s+)?Text\(\s*)['\"]([^'\"]+)['\"]"
    pattern = re.compile(regex_str)
    
    arb_it = {"@@locale": "it"}
    arb_en = {"@@locale": "en"}

    print("Inizio scansione e SOSTITUZIONE AUTOMATICA in 'lib/'...\n")

    for root, _, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()

                    matches = pattern.findall(content)
                    if not matches:
                        continue

                    modified_content = content
                    modifiche_fatte = False

                    for prefix, text in matches:
                        # Filtro anti-rumore
                        if not text.strip() or '$' in text or len(text.strip()) <= 1:
                            continue
                        if text.startswith('loc.') or text.startswith('AppLocalizations'):
                            continue

                        key = clean_key(text)

                        # Gestione collisioni
                        orig_key = key
                        counter = 1
                        while key in arb_it and arb_it[key] != text:
                            key = f"{orig_key}{counter}"
                            counter += 1

                        if key not in arb_it:
                            arb_it[key] = text
                            arb_en[key] = f"{text} (TODO)"

                        # SOSTITUZIONE NEL CODICE!
                        # Rimuove "const " dal prefisso (es: "const Text(" -> "Text(")
                        clean_prefix = prefix.replace('const ', '').replace('const\t', '')

                        # Costruisce la stringa vecchia e quella nuova
                        # Prova sia con l'apice singolo che con le virgolette doppie
                        old_str_single = f"{prefix}'{text}'"
                        old_str_double = f'{prefix}"{text}"'
                        new_str = f"{clean_prefix}loc.{key}"

                        modified_content = modified_content.replace(old_str_single, new_str)
                        modified_content = modified_content.replace(old_str_double, new_str)
                        
                        modifiche_fatte = True

                    if modifiche_fatte:
                        # CREA IL BACKUP PRIMA DI SOVRASCRIVERE
                        shutil.copy(filepath, f"{filepath}.bak")
                        
                        # Sovrascrive il file originale con i nuovi loc.chiave
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(modified_content)
                        print(f"✅ Modificato: {filepath} (Backup '.bak' creato)")

                except Exception as e:
                    print(f"❌ Errore in {filepath}: {e}")

    # Salva i file ARB generati
    with open('app_it_generato.arb', 'w', encoding='utf-8') as f:
        json.dump(arb_it, f, indent=2, ensure_ascii=False)
        
    with open('app_en_generato.arb', 'w', encoding='utf-8') as f:
        json.dump(arb_en, f, indent=2, ensure_ascii=False)

    print(f"\n🎉 Sostituzione massiva completata! ({len(arb_it)-1} stringhe processate)")
    print("1. Sposta i file 'app_it_generato.arb' e 'app_en_generato.arb' in lib/l10n/ (rinominandoli)")
    print("2. Lancia 'flutter gen-l10n'")

if __name__ == '__main__':
    main()