# =============================================================================
# Stage 1: Builder
# Usamos python:3.12-alpine como base para um build enxuto.
# Nesta etapa instalamos as dependências e preparamos o ambiente.
# =============================================================================
FROM python:3.12-alpine AS builder

# Instala dependências de sistema necessárias para compilar pacotes Python
RUN apk add --no-cache gcc musl-dev libffi-dev

# Define o diretório de trabalho dentro do container
WORKDIR /app

# Copia apenas o arquivo de dependências primeiro (aproveita o cache do Docker)
COPY requirements.txt .

# Instala as dependências em um diretório isolado para copiar depois
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# =============================================================================
# Stage 2: Runtime
# Imagem final mínima — apenas o necessário para rodar a aplicação.
# Não inclui gcc, pip, ou arquivos temporários de build.
# =============================================================================
FROM python:3.12-alpine AS runtime

# Cria um usuário não-root para maior segurança
# (evita que um atacante tenha privilégios de root dentro do container)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Define o diretório de trabalho
WORKDIR /app

# Copia as dependências instaladas na etapa de build
COPY --from=builder /install /usr/local

# Copia o código da aplicação
COPY app.py .

# Define que o usuário não-root será o dono do diretório e rodará a aplicação
RUN chown -R appuser:appgroup /app
USER appuser

# Expõe a porta que a aplicação Flask usa
EXPOSE 5000

# Healthcheck nativo do Docker — verifica se a API está respondendo
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5000/health || exit 1

# Comando padrão para iniciar a aplicação
CMD ["python", "app.py"]
