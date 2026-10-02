#!/usr/bin/env bash
# handy-smart-toggle: toggle de Handy a prueba de confusiones de binding.
#
# Uso: handy-smart-toggle.sh [transcribe|transcribe_with_post_process]
#
#   - Si NO hay grabación activa: inicia el modo pasado como argumento.
#   - Si HAY grabación activa: la para usando la señal del binding que la
#     inició (stop + transcribe), sin importar con qué atajo se empezó.
#
# Motivo: Handy ignora silenciosamente las pulsaciones de un binding distinto
# al que está grabando ("Ignoring press ... pipeline busy"), lo que dejaba la
# grabación colgada si se mezclaban los atajos.
#
# El estado se infiere del último evento relevante del log de debug de Handy.

set -euo pipefail

mode="${1:-transcribe}"
log="${HANDY_LOG:-$HOME/.local/share/com.pais.handy/logs/handy.log}"

flag_for() {
    case "$1" in
        transcribe_with_post_process) printf '%s\n' "--toggle-post-process" ;;
        *)                            printf '%s\n' "--toggle-transcription" ;;
    esac
}

active=""
if [[ -r "$log" ]]; then
    # "Microphone stream initialized" marca un reinicio de la app (con
    # always-on solo ocurre al arrancar): evita estados fantasma.
    last_event="$(
        tail -n 400 "$log" \
        | grep -E "Recording started for binding|Recording stopped and samples retrieved|cancellation|Microphone stream initialized" \
        | tail -n 1 || true
    )"
    case "$last_event" in
        *"Recording started for binding transcribe_with_post_process"*) active="transcribe_with_post_process" ;;
        *"Recording started for binding transcribe"*)                   active="transcribe" ;;
        *)                                                              active="" ;;
    esac
fi

if [[ -n "$active" ]]; then
    # Hay grabación activa: pararla con SU señal (para y transcribe).
    exec handy "$(flag_for "$active")"
else
    # Idle: iniciar el modo pedido.
    exec handy "$(flag_for "$mode")"
fi
