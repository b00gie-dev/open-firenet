#!/usr/bin/env bash
# ==============================================================================
# Open-Firenet Release Script
#
# Automatise le processus de release avec garde-fous stricts :
# 1. Vérification de la propreté du git tree
# 2. Vérification de la branche (main) et synchronisation remote
# 3. Exécution obligatoire des tests unitaires
# 4. Calcul automatique SemVer (patch / minor / major)
# 5. Mise à jour et commit de OPENFIRENET_VERSION dans le firmware
# 6. Création et push du tag annoté pour déclencher la CI Release
# ==============================================================================

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}ℹ${NC} $*"; }
ok()    { echo -e "${GREEN}✔${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
err()   { echo -e "${RED}✖${NC} $*" >&2; }
fatal() { err "$*"; exit 1; }

# Trouver la racine du dépôt git
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  fatal "Ce script doit être exécuté dans un dépôt Git."
fi
cd "$REPO_ROOT"

echo -e "\n${BOLD}${CYAN}=== Open-Firenet Release Assistant ===${NC}\n"

# 1. Vérification de la propreté de l'arbre de travail
info "Vérification de l'état de l'arbre de travail Git..."
if [[ -n "$(git status --porcelain)" ]]; then
  fatal "L'arbre de travail n'est pas propre. Veuillez commiter ou remiser vos modifications avant de releaser."
fi
ok "Arbre de travail propre."

# 2. Vérification de la branche
CURRENT_BRANCH="$(git branch --show-current)"
info "Branche actuelle : ${BOLD}${CURRENT_BRANCH}${NC}"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  warn "Vous n'êtes pas sur la branche 'main' (branche actuelle: $CURRENT_BRANCH)."
  read -rp "Voulez-vous vraiment créer une release depuis '$CURRENT_BRANCH' ? [o/N] " confirm_branch
  if [[ ! "$confirm_branch" =~ ^[oOyY]$ ]]; then
    fatal "Release annulée. Basculez sur 'main' avec : git checkout main"
  fi
fi

# 3. Synchronisation avec origin
info "Vérification de la synchronisation avec origin..."
git fetch origin "$CURRENT_BRANCH" --quiet
LOCAL_COMMIT="$(git rev-parse HEAD)"
REMOTE_COMMIT="$(git rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null || true)"

if [[ -n "$REMOTE_COMMIT" && "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
  BEHIND="$(git rev-list --count HEAD..origin/"$CURRENT_BRANCH")"
  if [[ "$BEHIND" -gt 0 ]]; then
    fatal "Votre branche locale a $BEHIND commit(s) de retard par rapport à origin. Faites un 'git pull' d'abord."
  fi
fi
ok "Synchronisation remote vérifiée."

# 4. Exécution obligatoire des tests unitaires
info "Exécution de la suite de tests unitaires..."
if [[ -f "test/build_and_test.sh" ]]; then
  if ./test/build_and_test.sh >/dev/null 2>&1; then
    ok "Tous les tests unitaires sont passés avec succès."
  else
    ./test/build_and_test.sh
    fatal "Les tests unitaires ont échoué ! Release interrompue."
  fi
else
  warn "Script test/build_and_test.sh non trouvé, passage outre."
fi

# 5. Détection du dernier tag et calcul SemVer
LATEST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"

if [[ -z "$LATEST_TAG" ]]; then
  warn "Aucun tag existant trouvé dans ce dépôt."
  DEFAULT_NEXT="v2.0.0"
  LATEST_TAG="aucun"
else
  info "Dernier tag détecté : ${BOLD}${LATEST_TAG}${NC}"
  # Extraire major, minor, patch (supporte 'vX.Y.Z' ou 'X.Y.Z')
  RAW_VER="${LATEST_TAG#v}"
  IFS='.' read -r MAJOR MINOR PATCH <<< "$RAW_VER"
  
  NEXT_PATCH="v${MAJOR}.${MINOR}.$((PATCH + 1))"
  NEXT_MINOR="v${MAJOR}.$((MINOR + 1)).0"
  NEXT_MAJOR="v$((MAJOR + 1)).0.0"
  DEFAULT_NEXT="$NEXT_PATCH"
fi

# Traitement de l'argument utilisateur (patch, minor, major ou version explicite)
TARGET_TYPE="${1:-patch}"
case "$TARGET_TYPE" in
  patch)
    NEW_TAG="${NEXT_PATCH:-v2.0.0}"
    ;;
  minor)
    NEW_TAG="${NEXT_MINOR:-v2.1.0}"
    ;;
  major)
    NEW_TAG="${NEXT_MAJOR:-v3.0.0}"
    ;;
  v*.*.*)
    NEW_TAG="$TARGET_TYPE"
    ;;
  [0-9]*.*.*)
    NEW_TAG="v$TARGET_TYPE"
    ;;
  *)
    fatal "Type d'incrémentation inconnu : '$TARGET_TYPE'. Utilisation : $0 [patch|minor|major|vX.Y.Z]"
    ;;
esac

if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
  fatal "Le tag $NEW_TAG existe déjà dans le dépôt."
fi

# 6. Affichage des commits depuis le dernier tag
echo ""
echo -e "${BOLD}Historique depuis ${LATEST_TAG} :${NC}"
if [[ "$LATEST_TAG" != "aucun" ]]; then
  git log --oneline "${LATEST_TAG}..HEAD" | sed 's/^/  • /' || echo "  (aucun nouveau commit)"
else
  git log -n 5 --oneline | sed 's/^/  • /'
fi
echo ""

# 7. Confirmation utilisateur
echo -e "${BOLD}Tag à créer : ${GREEN}${NEW_TAG}${NC}"
read -rp "Confirmer la création et le déploiement de la release ${NEW_TAG} ? [o/N] " CONFIRM

if [[ ! "$CONFIRM" =~ ^[oOyY]$ ]]; then
  echo -e "\nRelease annulée."
  exit 0
fi

# 8. Mise à jour automatique de la version dans le firmware
CLEAN_VER="${NEW_TAG#v}"
info "Mise à jour de OPENFIRENET_VERSION vers ${CLEAN_VER}..."
sed -i -E "s/(#define OPENFIRENET_VERSION )\"[^\"]+\"/\1\"$CLEAN_VER\"/" open-firenet/open-firenet.ino
if ! grep -q "#define OPENFIRENET_VERSION \"$CLEAN_VER\"" open-firenet/open-firenet.ino; then
  fatal "Échec de la mise à jour de OPENFIRENET_VERSION dans open-firenet.ino !"
fi
ok "OPENFIRENET_VERSION synchronisé (${CLEAN_VER})."

info "Commit automatique de la version ${NEW_TAG}..."
git add open-firenet/open-firenet.ino
if ! git diff --cached --quiet; then
  git commit -m "chore(release): bump firmware version to ${NEW_TAG}"
  info "Push du commit sur origin/${CURRENT_BRANCH}..."
  git push origin "$CURRENT_BRANCH"
  ok "Commit de version poussé sur origin."
else
  ok "OPENFIRENET_VERSION déjà à jour, aucun commit nécessaire."
fi

# 9. Création du tag annoté
info "Création du tag Git ${NEW_TAG}..."
git tag -a "$NEW_TAG" -m "Release $NEW_TAG"
ok "Tag local $NEW_TAG créé."

# 10. Push du tag vers le dépôt distant
info "Push du tag sur origin..."
git push origin "$NEW_TAG"

echo ""
ok "${BOLD}${GREEN}Tag ${NEW_TAG} poussé avec succès sur GitHub !${NC}"
echo -e "${CYAN}Le workflow GitHub Actions est déclenché :${NC}"
echo -e "  1. Compilation des binaires factory & ota"
echo -e "  2. Calcul des checksums SHA256"
echo -e "  3. Signature cryptographique Minisign (si MINISIGN_SECRET_KEY configuré)"
echo -e "  4. Attestation de provenance SLSA Level 3"
echo -e "  5. Mise en ligne de la Release sur GitHub"
echo ""
