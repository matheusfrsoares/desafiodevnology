#!/bin/sh
# =============================================================================
# healthcheck.sh — Script de Healthcheck para a Trainee DevOps API
# Uso: ./healthcheck.sh [host] [port]
# Exemplo: ./healthcheck.sh localhost 5000
# =============================================================================

HOST="${1:-localhost}"
PORT="${2:-5000}"
URL="http://$HOST:$PORT/health"
MAX_RETRIES=5
RETRY_INTERVAL=3

echo "🔍 Verificando saúde da aplicação em $URL"
echo "   Tentativas: $MAX_RETRIES | Intervalo: ${RETRY_INTERVAL}s"
echo "--------------------------------------------"

attempt=1
while [ $attempt -le $MAX_RETRIES ]; do
    echo "⏳ Tentativa $attempt de $MAX_RETRIES..."

    # Faz a requisição e captura o código HTTP
    HTTP_CODE=$(wget --server-response --spider --quiet "$URL" 2>&1 | grep "HTTP/" | awk '{print $2}')

    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Aplicação está SAUDÁVEL! (HTTP $HTTP_CODE)"
        echo "   URL: $URL"
        echo "   Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        exit 0
    else
        echo "❌ Falhou (HTTP ${HTTP_CODE:-sem resposta})"
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo "   Aguardando ${RETRY_INTERVAL}s antes de tentar novamente..."
            sleep $RETRY_INTERVAL
        fi
    fi

    attempt=$((attempt + 1))
done

echo ""
echo "💀 Aplicação não está respondendo após $MAX_RETRIES tentativas."
echo "   Verifique se o serviço está rodando em $HOST:$PORT"
exit 1
