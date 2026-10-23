#!/usr/bin/env bash
# Confere se o behair está no ar e avisa no WhatsApp (pelo Ben, do Bentus) só quando ele cai e quando volta.
# Só considera "fora do ar" depois de 2 falhas seguidas, para uma falha isolada não virar alarme falso.
#
# Variáveis:
#   ESTADO_ANTERIOR     no-ar | fora (o resultado da checagem anterior; padrão no-ar)
#   BENTUS_CRON_SECRET  chave do Ben (segredo do GitHub; nunca é impressa)
#   MODO=teste          só manda um aviso de teste e sai
# Sai com erro quando o behair está fora do ar: o GitHub marca a execução como falha e manda e-mail (reserva).
set -uo pipefail

SAUDE="${SAUDE_URL:-https://behair.bemedical.app/api/saude}"
BEN="${BEN_URL:-https://app.bentuscrm.com.br/api/hooks/claude-aviso}"
ESPERA="${ESPERA_SEGUNDOS:-60}"
ANTES="${ESTADO_ANTERIOR:-no-ar}"

no_ar() { curl -fsS --max-time 20 "$SAUDE" 2>/dev/null | grep -q '"ok":true'; }

avisar() {
  if [ -z "${BENTUS_CRON_SECRET:-}" ]; then echo "::error::falta o segredo BENTUS_CRON_SECRET"; return 1; fi
  local corpo resposta codigo
  corpo=$(jq -nc --arg m "$1" '{message: $m, cwd: "/vigia/behair"}')
  resposta=$(curl -sS --max-time 20 -X POST "$BEN" -H 'Content-Type: application/json' \
    -H "x-cron-secret: $BENTUS_CRON_SECRET" -d "$corpo" -w '\n%{http_code}') || { echo "::error::Ben não respondeu"; return 1; }
  codigo=$(tail -n1 <<<"$resposta")
  echo "Ben respondeu $codigo: $(sed '$d' <<<"$resposta")"
  [ "$codigo" = 200 ] && grep -q '"enviado":true' <<<"$resposta"
}

if [ "${MODO:-}" = teste ]; then
  avisar "teste do vigia do behair: os avisos estão funcionando."
  exit $?
fi

if no_ar; then
  agora=no-ar
else
  sleep "$ESPERA"
  if no_ar; then agora=no-ar; else agora=fora; fi
fi
echo "behair: antes $ANTES, agora $agora"

if [ "$agora" != "$ANTES" ]; then
  if [ "$agora" = fora ]; then
    avisar "o behair está FORA DO AR (https://behair.bemedical.app não respondeu 2 vezes seguidas)." || true
  else
    avisar "o behair voltou ao ar." || true
  fi
fi

[ "$agora" = no-ar ]
