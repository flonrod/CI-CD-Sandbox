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

  # Verificar que el JSON es un array
  if ! jq -e '. | type == "array"' "$config_file" >/dev/null 2>&1; then
    echo "::error::El archivo JSON debe ser un array en la raíz"
    exit 1
  fi

  # Verificar que el array no está vacío
  local array_length
  array_length=$(jq '. | length' "$config_file")
  if [[ "$array_length" -eq 0 ]]; then
    echo "::error::El array de códigos no puede estar vacío"
    exit 1
  fi

  # Validar que cada elemento tenga los campos requeridos
  local validation_errors=0
  local index=0

  while IFS= read -r item; do
    # Verificar campo 'range'
    if ! jq -e '.range' <<<"$item" >/dev/null 2>&1; then
      echo "::error::El elemento en índice $index no contiene el campo 'range'"
      ((validation_errors++))
    fi

    # Verificar campo 'status'
    if ! jq -e '.status' <<<"$item" >/dev/null 2>&1; then
      echo "::error::El elemento en índice $index no contiene el campo 'status'"
      ((validation_errors++))
    fi

    # Verificar campo 'message'
    if ! jq -e '.message' <<<"$item" >/dev/null 2>&1; then
      echo "::error::El elemento en índice $index no contiene el campo 'message'"
      ((validation_errors++))
    fi

    # Verificar campo 'should-fail'
    if ! jq -e '."should-fail"' <<<"$item" >/dev/null 2>&1; then
      echo "::error::El elemento en índice $index no contiene el campo 'should-fail'"
      ((validation_errors++))
    else
      # Verificar que 'should-fail' sea booleano
      local should_fail_type
      should_fail_type=$(jq -r '."should-fail" | type' <<<"$item")
      if [[ "$should_fail_type" != "boolean" ]]; then
        echo "::error::El campo 'should-fail' en índice $index debe ser booleano (true/false), encontrado: $should_fail_type"
        ((validation_errors++))
      fi
    fi

    ((index++))
  done < <(jq -c '.[]' "$config_file")

  if [[ "$validation_errors" -gt 0 ]]; then
    echo "::error::Se encontraron $validation_errors errores de validación en la estructura del JSON"
    exit 1
  fi
  
  echo "Estructura JSON validada correctamente"
  echo "::endgroup::"
}

# Ejecutar validación
validate_config_and_structure "$1"