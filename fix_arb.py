import json
import os

def aggiungi_metadati_vuoti(filepath):
    # Verifica che il file esista
    if not os.path.exists(filepath):
        print(f"❌ File non trovato: {filepath}")
        return

    # Legge il file .arb
    with open(filepath, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"❌ Errore di sintassi nel JSON {filepath}: {e}")
            return

    new_data = {}

    for key, value in data.items():
        # 1. Ricopia la chiave originale e il suo valore
        new_data[key] = value
        
        # 2. Se è una chiave di testo (non inizia con @), controlliamo se manca il metadato
        if not key.startswith('@'):
            meta_key = f"@{key}"
            # Se il metadato non esiste nel file originale, lo creiamo vuoto
            if meta_key not in data:
                new_data[meta_key] = {}

    # Sovrascrive il file con i nuovi dati indentati e formattati bene
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(new_data, f, indent=2, ensure_ascii=False)

    print(f"✅ File {filepath} aggiornato e purificato con successo!")

# Esegue l'operazione sui nostri due file
if __name__ == "__main__":
    print("Inizio la pulizia dei file ARB...")
    
    file_it = os.path.join("lib", "l10n", "app_it.arb")
    file_en = os.path.join("lib", "l10n", "app_en.arb")
    
    aggiungi_metadati_vuoti(file_it)
    aggiungi_metadati_vuoti(file_en)
    
    print("Operazione completata! Nessun linter oserà più lamentarsi.")