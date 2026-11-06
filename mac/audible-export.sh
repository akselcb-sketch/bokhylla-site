#!/usr/bin/env bash
# Bokhylla – automatisk Audible-eksport
#
# Kjøres IKKE for hånd i Terminal – dette scriptet startes av launchd hver
# morgen kl. 06 (se no.bokhylla.audible-export.plist og oppskriften på
# https://akselcb-sketch.github.io/bokhylla-site/mac.html). Fordi det kjører
# uten en interaktiv terminal, kan det ikke stole på at PATH, HOME eller noe
# annet miljø er satt opp slik det pleier å være når du selv skriver
# kommandoer.
#
# Eksporterer:
#   audible-library.tsv    audible library export
#   audible-wishlist.tsv   audible wishlist export
# til iCloud Drive, slik at Bokhylla-appen på iPhone finner dem automatisk.
#
# All logging havner i LOG_FILE (aldri i en terminal noen ser på), og
# scriptet avslutter med en tydelig SUCCESS/FAILURE-linje slik at et enkelt
# blikk i loggen – eller overvåkning av exit-koden – viser om det gikk bra.
set -euo pipefail

LOG_FILE="${HOME}/Library/Logs/bokhylla-audible-export.log"
EXPORT_DIR="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/Bokhylla"

mkdir -p "$(dirname "${LOG_FILE}")"

log() {
  echo "$1" >>"${LOG_FILE}"
}

# --- Bygg en robust PATH ------------------------------------------------
# launchd gir prosessen et svært minimalt miljø (ofte bare
# /usr/bin:/bin:/usr/sbin:/sbin), så audible-cli finnes typisk ikke i
# standard-PATH-en. Vi legger til de vanligste installasjonsstedene:
# pipx/pip --user (~/.local/bin), Homebrew (/opt/homebrew/bin på Apple
# Silicon, /usr/local/bin på Intel), og en Homebrew-Pythons «user base»-bin.
#
# «python3 -m site --user-base» kan feile, eller python3 kan mangle helt –
# det skal ikke stoppe scriptet før PATH-en i det hele tatt er bygget, så
# dette er beskyttet med sitt eget feilhåndterings-fallback.
PYTHON_USER_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_USER_BASE="$(python3 -m site --user-base 2>/dev/null || true)"
  if [ -n "${PYTHON_USER_BASE}" ]; then
    PYTHON_USER_BIN="${PYTHON_USER_BASE}/bin"
  fi
fi

NEW_PATH_DIRS="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin"
if [ -n "${PYTHON_USER_BIN}" ]; then
  NEW_PATH_DIRS="${NEW_PATH_DIRS}:${PYTHON_USER_BIN}"
fi
export PATH="${NEW_PATH_DIRS}:${PATH}"

# --- Start ---------------------------------------------------------------
log ""
log "==== Bokhylla audible-export startet $(date '+%Y-%m-%d %H:%M:%S') ===="

mkdir -p "${EXPORT_DIR}"

if ! command -v audible >/dev/null 2>&1; then
  log "FEIL: fant ikke «audible»-kommandoen selv etter utvidet PATH (${PATH})."
  log "Sjekk at audible-cli er installert – se https://akselcb-sketch.github.io/bokhylla-site/mac.html"
  log "==== Bokhylla audible-export FEILET $(date '+%Y-%m-%d %H:%M:%S') ===="
  exit 1
fi

# De to eksport-kommandoene er de eneste stegene som skal kunne feile på en
# forventet måte (f.eks. utløpt innlogging). set -e ville avsluttet scriptet
# stille i så fall, så begge er derfor pakket inn i en if-sjekk som logger en
# tydelig, spesifikk feilmelding før scriptet gir seg med exit-kode 1.
log "==> Eksporterer Audible-biblioteket …"
if ! audible library export --format tsv --output "${EXPORT_DIR}/audible-library.tsv" >>"${LOG_FILE}" 2>&1; then
  log "FEIL: klarte ikke å eksportere Audible-biblioteket."
  log "Vanligste årsak: innloggingen har utløpt. Kjør «audible quickstart» på nytt i Terminal."
  log "==== Bokhylla audible-export FEILET $(date '+%Y-%m-%d %H:%M:%S') ===="
  exit 1
fi

log "==> Eksporterer ønskelisten …"
if ! audible wishlist export --format tsv --output "${EXPORT_DIR}/audible-wishlist.tsv" >>"${LOG_FILE}" 2>&1; then
  log "FEIL: klarte ikke å eksportere ønskelisten."
  log "Vanligste årsak: innloggingen har utløpt. Kjør «audible quickstart» på nytt i Terminal."
  log "==== Bokhylla audible-export FEILET $(date '+%Y-%m-%d %H:%M:%S') ===="
  exit 1
fi

log "==== Bokhylla audible-export FERDIG (SUCCESS) $(date '+%Y-%m-%d %H:%M:%S') ===="
