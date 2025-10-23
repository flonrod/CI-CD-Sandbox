#!/bin/bash

set -euo pipefail

validate_retcode() {
  local retcode="$1"

  # Validar que solo contenga dígitos
  if ! [[ "$retcode" =~ ^[0-9]+$ ]]; then
    >&2 echo "::error::Código de retorno inválido: $retcode. Solo se permiten valor numérico, mayor o igual a 0."
    exit 1
  fi

  # Convertir a número entero forzando base 10
  local RC_NUM=$((10#$retcode))

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

  # Expandir placeholders en el mensaje
  message="${message//\{code\}/$RC_NUM}"

  # Mostrar en consola
  echo "------------------------------------"
  echo "  Resultado encontrado:"
  echo "  Status : $status"
  echo "  Message: $message"
  echo "------------------------------------"

  {
    printf "status=%s\n" "$status"
    printf "message=%s\n" "$message"
  } >> "$GITHUB_OUTPUT"
}

find_matching_code() {
  local rc_num="$1"
  local config_file="$2"

  # Buscar coincidencia en el array
  while IFS= read -r config_line; do
    local range status message should_fail
    range=$(jq -r '.range' <<<"$config_line")
    status=$(jq -r '.status' <<<"$config_line")
    message=$(jq -r '.message' <<<"$config_line")
    should_fail=$(jq -r '."should-fail"' <<<"$config_line")

    if in_range "$rc_num" "$range"; then
      set_result "$status" "$message"
      
      # Usar should-fail para determinar el exit code
      if [[ "$should_fail" == "false" ]]; then
        return 0
      else
        return 1
      fi
    fi

  done < <(jq -c '.[]' "$config_file")

  # Si no hubo coincidencia, código inesperado
  echo "::error::Código de retorno inesperado: $rc_num. No se encontró en los rangos configurados."
  set_result "critical" "Código de retorno inesperado ($rc_num). Revisar configuración de rangos."
  
  return 1
}

# Buscar código coincidente y procesar resultado
if find_matching_code "$RC_NUM" "$CONFIG_FILE"; then
  exit 0
else
  exit 1
fi