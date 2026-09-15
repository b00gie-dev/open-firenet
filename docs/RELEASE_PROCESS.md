# Processus d'Intégration Continue (CI) et de Release

Ce document décrit le pipeline d'intégration continue, le mécanisme de signature cryptographique Minisign, et la procédure de release automatisée d'**Open-Firenet**.

---

## 1. Pipeline CI (sur chaque commit & PR)

Le workflow [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) est déclenché automatiquement sur :
- Tout `push` sur les branches `main`, `feat/**`, `test/**`
- Toute `pull_request` vers `main`

### Étapes exécutées :
1. **Tests unitaires protocolaires natifs** (`./test/build_and_test.sh`) :
   - Exécution immédiate sur runner Linux (C++ natif sans émulation).
   - Valide le tokeniseur de trames, les codecs hexadécimaux, la parité protocolaire et les tables de libellés.
2. **Compilation du firmware ESP32-S3** (`arduino-cli`) :
   - Vérifie que le code Arduino compile sans erreur avec le core `esp32:esp32@3.3.8` et le schéma de partition `min_spiffs`.
   - Utilise un cache des packages Arduino pour des temps de build réduits (< 1 min).
   - **Vérification d'intégrité SHA256 du cache** : Le workflow calcule le hash SHA256 combiné de tous les binaires et bibliothèques du toolchain ESP32 pour garantir qu'aucune corruption ou altération (cache poisoning) n'a eu lieu avant la compilation. Si un fichier `.github/integrity/esp32-core-3.3.8.sha256` est présent, une vérification Zero-Trust stricte est imposée.

---

## 2. Processus de Release Sécurisé (Tag-driven)

Le workflow [`.github/workflows/release.yml`](../.github/workflows/release.yml) est déclenché lors du push d'un tag au format `v*` (ex. `v2.0.0`).

### Artefacts produits :
* `open-firenet-factory.bin` : image flash complète (bootloader + partitions + application) pour premier flash USB via l'installeur.
* `open-firenet-ota.bin` : binaire de l'application seule pour mise à jour sans fil (OTA).
* `open-firenet-bootloader.bin` & `open-firenet-partitions.bin` : composants individuels de bas niveau.
* `SHA256SUMS` : condensats cryptographiques de tous les binaires ci-dessus.
* `SHA256SUMS.minisig` : signature cryptographique Minisign Ed25519.

### Sécurité & Traçabilité (Supply Chain Security) :
1. **Signature Minisign (Ed25519)** :
   - `SHA256SUMS` est signé avec la clé privée `MINISIGN_SECRET_KEY` stockée dans les secrets GitHub du dépôt.
   - La clé publique est stockée dans [`minisign.pub`](../minisign.pub) et intégrée dans `open-firenet-installer`.
   - L'installeur valide la signature avant d'autoriser tout flash sur le microcontrôleur du client.
2. **Attestation SLSA Level 3 (GitHub Artifact Attestations)** :
   - Attestation cryptographique native émise par GitHub via OIDC et Sigstore.
   - Vérifiable publiquement avec :
     ```bash
     gh attestation verify open-firenet-factory.bin -R openfirenet/open-firenet
     ```

---

## 3. Déclencher une Release (Assistant local)

Pour créer et publier une release, lancez simplement le script depuis votre terminal local :

```bash
# Incrément patch automatique (ex: v2.0.0 -> v2.0.1)
./scripts/release.sh

# Incrément minor (ex: v2.0.0 -> v2.1.0)
./scripts/release.sh minor

# Incrément major (ex: v2.0.0 -> v3.0.0)
./scripts/release.sh major

# Version spécifique
./scripts/release.sh v2.0.0
```

### Ce que fait le script :
1. Vérifie que l'arbre git est propre et que vous êtes sur `main`.
2. Vérifie que vous êtes synchronisé avec `origin/main`.
3. Lance les tests unitaires locaux en amont (bloque si un test échoue).
4. Affiche l'historique des commits depuis la précédente version.
5. Vous demande confirmation avant de créer le tag annoté et de le pousser.

---

## 4. Configuration du Secret Minisign sur GitHub

Pour activer la signature automatique des releases :
1. Rendez-vous sur le dépôt GitHub : **Settings > Secrets and variables > Actions**.
2. Cliquez sur **New repository secret**.
3. Nom : `MINISIGN_SECRET_KEY`
4. Valeur : collez la clé secrète générée (voir instructions fournies).
