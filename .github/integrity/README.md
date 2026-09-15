# Cache Integrity Pinning (Zero-Trust)

Ce répertoire permet de verrouiller cryptographiquement la chaîne d'outils ESP32 (`arduino-esp32` toolchain + SDK IDF) utilisée par la CI et la Release.

## Fonctionnement

Lors de chaque exécution de la CI et de la Release :
1. Le cache de `~/.arduino15/packages` est restauré.
2. Le runner calcule le SHA256 déterministe de tous les fichiers :
   ```bash
   find ~/.arduino15/packages -type f -exec sha256sum {} + | sort -k2 | sha256sum
   ```
3. Si un fichier nommé `esp32-core-<version>.sha256` est présent dans ce dossier (ex. `esp32-core-3.3.11.sha256`), la CI vérifie que le hash correspond **strictement**.
4. En cas de non-concordance (fichier altéré, outil modifié ou corrompu), le job échoue immédiatement avant toute compilation.

## Comment épingler ou mettre à jour un hash

Lors du premier build GitHub Actions après une montée de version du core :
1. Consultez les logs de l'étape **"Install ESP32 Platform Core"** ou **"Verify Cache Integrity"**.
2. Récupérez la ligne : `Installed ESP32 core SHA256: <hash>`
3. Créez ou mettez à jour le fichier `esp32-core-<version>.sha256` avec ce hash.
4. Committez et poussez sur `main`.
