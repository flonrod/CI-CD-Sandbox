#!/bin/bash

set -euo pipefail

validate_retcode() {
  local retcode="$1"

  # Validar que solo contenga dígitos
  if ! [[ "$retcode" =~ ^[0-9]+$ ]]; then
    echo "::error::Código de retorno inválido: $retcode"
    exit 1
  fi

  # Convertir a número entero forzando base 10
  local RC_NUM=$((10#$retcode))

  # Validar que es positivo o cero
  if [[ $RC_NUM -lt 0 ]]; then
    echo "::error::Código de retorno debe ser positivo o cero: $RC_NUM"
    exit 1
  fi

  # Devolver el código validado
  echo "$RC_NUM"
}

# Variables
RETCODE="$1"
CONFIG_FILE="$2"

readonly RETCODE CONFIG_FILE

# Validar código de retorno
RC_NUM=$(validate_retcode "$RETCODE")
readonly RC_NUM

# Validar archivo de configuración usando script externo
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
"$SCRIPT_DIR/validate-config.sh" "$CONFIG_FILE"

in_range() {
  local num=$1
  local range=$2

  [[ -z "$range" ]] && return 1

  case "$range" in
    (*-*)
      local start="${range%-*}"
      local end="${range#*-}"
      [[ $num -ge $start && $num -le $end ]]
      return $? ;;
    ([0-9]*)
      [[ $num -eq $range ]]
      return $? ;;
    (*)
      return 1 ;;
  esac
}

set_result() {
  local status="$1"
  local message="$2"
  local title="$3"

  # Expandir placeholders en el mensaje
  message="${message//\{code\}/$RC_NUM}"

  # Mostrar en consola
  echo "------------------------------------"
  echo "  Resultado encontrado:"
  echo "  Status : $status"
  echo "  Title  : $title"
  echo "  Message: $message"
  echo "------------------------------------"

  {
    printf "status=%s\n" "$status"
    printf "message=%s\n" "$message"
    printf "title=%s\n" "$title"
  } >> "$GITHUB_OUTPUT"
}

find_matching_code() {
  local rc_num="$1"
  local config_file="$2"

  exit_based_on_status() {
    local status="$1"
    if [[ "$status" == "success" || "$status" == "warning" ]]; then
      return 0
    else
      return 1
    fi
  }

  # Buscar coincidencia en codes[]
  while IFS= read -r config_line; do
    local range status title message
    range=$(jq -r '.range' <<<"$config_line")
    status=$(jq -r '.status' <<<"$config_line")
    title=$(jq -r '.title' <<<"$config_line")
    message=$(jq -r '.message' <<<"$config_line")

    if in_range "$rc_num" "$range"; then
      set_result "$status" "$message" "$title"
      if exit_based_on_status "$status"; then
        return 0
      else
        return 1
      fi
    fi

  done < <(jq -c '.codes[]' "$config_file")

  # Si no hubo coincidencia, usar fallback (siempre falla)
  local fb_status fb_title fb_message
  fb_status=$(jq -r '.fallback.status' "$config_file")
  fb_title=$(jq -r '.fallback.title' "$config_file")
  fb_message=$(jq -r '.fallback.message' "$config_file")

  set_result "$fb_status" "$fb_message" "$fb_title"

  return 1
}

# Buscar código coincidente y procesar resultado
if find_matching_code "$RC_NUM" "$CONFIG_FILE"; then
  exit 0
else
  exit 1
fi