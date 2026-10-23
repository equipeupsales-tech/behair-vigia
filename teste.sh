#!/usr/bin/env bash
# Testa o vigiar.sh sem tocar no Ben de verdade: um Ben falso local registra os avisos recebidos.
set -uo pipefail
cd "$(dirname "$0")"

PORTA=8765
REGISTRO=$(mktemp)
node -e '
  const fs = require("fs");
  require("http").createServer((req, res) => {
    let corpo = ""; req.on("data", (c) => (corpo += c));
    req.on("end", () => {
      if (req.headers["x-cron-secret"] !== "segredo-de-teste") { res.writeHead(401); return res.end("{}"); }
      fs.appendFileSync(process.argv[1], JSON.parse(corpo).message + "\n");
      res.writeHead(200, { "content-type": "application/json" }); res.end("{\"ok\":true,\"enviado\":true}");
    });
  }).listen(Number(process.argv[2]));
' "$REGISTRO" "$PORTA" &
BEN_FALSO=$!
trap 'kill $BEN_FALSO; wait $BEN_FALSO 2>/dev/null; rm -f "$REGISTRO"' EXIT
sleep 1

export BEN_URL="http://127.0.0.1:$PORTA" BENTUS_CRON_SECRET=segredo-de-teste ESPERA_SEGUNDOS=0
NO_AR="https://behair.bemedical.app/api/saude"
FORA="http://127.0.0.1:1/api/saude"
falhas=0

caso() { # nome, saída esperada (0 ou 1), avisos esperados (texto ou vazio), comando...
  local nome=$1 esperado=$2 aviso=$3; shift 3
  : >"$REGISTRO"
  "$@" >/dev/null; local saida=$?
  local recebido; recebido=$(cat "$REGISTRO")
  if [ "$saida" = "$esperado" ] && { [ -z "$aviso" ] && [ -z "$recebido" ] || grep -q "$aviso" <<<"$recebido"; }; then
    echo "ok    $nome"
  else
    echo "FALHA $nome (saída $saida, avisos: ${recebido:-nenhum})"; falhas=$((falhas + 1))
  fi
}

caso "no ar e continua: nada a avisar"      0 ""              env SAUDE_URL=$NO_AR ESTADO_ANTERIOR=no-ar ./vigiar.sh
caso "caiu: avisa uma vez e marca falha"     1 "FORA DO AR"    env SAUDE_URL=$FORA  ESTADO_ANTERIOR=no-ar ./vigiar.sh
caso "continua fora: não repete o aviso"     1 ""              env SAUDE_URL=$FORA  ESTADO_ANTERIOR=fora  ./vigiar.sh
caso "voltou: avisa que voltou"              0 "voltou ao ar"  env SAUDE_URL=$NO_AR ESTADO_ANTERIOR=fora  ./vigiar.sh
caso "modo teste: manda o aviso de teste"    0 "teste do vigia" env MODO=teste ./vigiar.sh
caso "chave errada: o teste falha"           1 ""              env MODO=teste BENTUS_CRON_SECRET=errada ./vigiar.sh
caso "sem chave: o teste falha"              1 ""              env MODO=teste BENTUS_CRON_SECRET= ./vigiar.sh

[ "$falhas" = 0 ] && echo "tudo certo" || { echo "$falhas falha(s)"; exit 1; }
