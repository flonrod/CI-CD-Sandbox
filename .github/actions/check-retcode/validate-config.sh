#!/bin/bash

set -euo pipefail

validate_config_and_structure() {
  local config_file="$1"
  
  # Validar archivo de configuración
  if [[ ! -f "$config_file" ]]; then
    echo "::error::Archivo de configuración no encontrado: $config_file"
    exit 1
  fi

  if ! jq empty "$config_file" 2>/dev/null; then
    echo "::error::Archivo JSON inválido: $config_file"
    exit 1
  fi

  echo "::group::Validando estructura del JSON"

  # Verificar que existe el array 'codes'
  if ! jq -e '.codes' "$config_file" >/dev/null 2>&1; then
    echo "::error::El archivo JSON no contiene el array 'codes' requerido"
    exit 1
  fi

  # Verificar que existe la configuración 'fallback'
  if ! jq -e '.fallback' "$config_file" >/dev/null 2>&1; then
    echo "::error::El archivo JSON no contiene la configuración 'fallback' requerida"
    exit 1
  fi
  
  echo "Estructura JSON validada correctamente"
  echo "::endgroup::"
}

# Ejecutar validación
validate_config_and_structure "$1"