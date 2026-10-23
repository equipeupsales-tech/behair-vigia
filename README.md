# behair-vigia

Confere a cada 5 minutos se o behair (https://behair.bemedical.app) está no ar e avisa no WhatsApp da equipe,
pelo Ben do Bentus CRM, **uma vez quando cai e uma vez quando volta**. Só considera fora do ar depois de 2 falhas
seguidas (1 minuto entre elas).

- `vigiar.sh`: a checagem e o aviso.
- `.github/workflows/vigia.yml`: roda a checagem a cada 5 minutos (o GitHub pode atrasar alguns minutos).
- `.github/workflows/manter-ligado.yml`: religa os robôs toda semana (o GitHub desliga depois de 60 dias parado).
- `teste.sh`: testa tudo com um Ben falso, sem mandar WhatsApp de verdade.

O repositório é público porque assim o GitHub Actions não cobra minutos. Não há nada secreto aqui: a chave do Ben
fica só no segredo `BENTUS_CRON_SECRET` (Settings → Secrets and variables → Actions) e nunca é impressa.

**Reservas:** se o Bentus também estiver fora, o WhatsApp não sai. Continuam avisando o UptimeRobot (e-mail) e o
próprio GitHub, que manda e-mail quando a execução do vigia fica vermelha.

**Testar o WhatsApp:** Actions → vigia → Run workflow (com "teste" marcado).
