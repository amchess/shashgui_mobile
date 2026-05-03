import os

# Configurazione
NOME_FILE_OUTPUT = "codice_progetto_completo.txt"
ESTENSIONI_VALIDE = ('.dart', '.yaml', '.xml', '.gradle', '.kts', '.cpp', '.h', '.c')
CARTELLE_DA_IGNORARE = {
    'build', '.dart_tool', '.git', '.idea', 'gradle', 
    'appicon', 'outputs', 'debug', 'profile'
}

def unisci_sorgenti():
    percorso_progetto = os.path.dirname(os.path.abspath(__file__))
    
    with open(NOME_FILE_OUTPUT, 'w', encoding='utf-8') as outfile:
        outfile.write(f"PROGETTO: {os.path.basename(percorso_progetto)}\n")
        outfile.write("="*50 + "\n\n")

        for root, dirs, files in os.walk(percorso_progetto):
            # Filtra le cartelle da ignorare
            dirs[:] = [d for d in dirs if d not in CARTELLE_DA_IGNORARE]

            for file in files:
                if file.endswith(ESTENSIONI_VALIDE):
                    percorso_completo = os.path.join(root, file)
                    rel_path = os.path.relpath(percorso_completo, percorso_progetto)
                    
                    # Salta il file di output stesso se esiste già
                    if file == NOME_FILE_OUTPUT:
                        continue

                    try:
                        with open(percorso_completo, 'r', encoding='utf-8') as infile:
                            contenuto = infile.read()
                            
                            # Scrivi l'intestazione del file
                            outfile.write(f"\n\n{'='*80}\n")
                            outfile.write(f"FILE: {rel_path}\n")
                            outfile.write(f"{'='*80}\n\n")
                            
                            # Scrivi il contenuto
                            outfile.write(contenuto)
                            outfile.write("\n")
                            
                            print(f"Aggiunto: {rel_path}")
                    except Exception as e:
                        print(f"Errore nel leggere {rel_path}: {e}")

    print(f"\n✅ Fatto! Tutto il codice è stato salvato in: {NOME_FILE_OUTPUT}")

if __name__ == "__main__":
    unisci_sorgenti()