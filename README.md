# 🚀 Trainee DevOps API

API simples em Python/Flask com pipeline CI/CD completo usando GitLab CI e AWS ECS.

## 📋 Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Rodando Localmente](#rodando-localmente)
- [Como o Pipeline Funciona](#como-o-pipeline-funciona)
- [Decisões Técnicas](#decisões-técnicas)
- [O que Faria com Mais Tempo](#o-que-faria-com-mais-tempo)
- [Como Usei IA no Desafio](#como-usei-ia-no-desafio)
- [Estrutura do Repositório](#estrutura-do-repositório)

---

## Sobre o Projeto

API de healthcheck construída com Flask. Expõe dois endpoints:

| Endpoint  | Método | Resposta |
|-----------|--------|----------|
| `/`       | GET    | `{"message": "Trainee DevOps API"}` |
| `/health` | GET    | `{"status": "healthy", "timestamp": "...", "version": "1.0.0"}` |

---

## Rodando Localmente

### Opção 1 — Docker (recomendado)

```bash
# Build e start da aplicação
docker compose up --build

# Verificar se está rodando
curl http://localhost:5000/health

# Rodar os testes dentro do container
docker compose --profile test up test
```

### Opção 2 — Python puro

```bash
# Criar ambiente virtual
python -m venv venv
source venv/bin/activate  # Linux/macOS
# venv\Scripts\activate   # Windows

# Instalar dependências
pip install -r requirements.txt

# Rodar a aplicação
python app.py

# Rodar os testes
pytest test_app.py -v

# Rodar o linter
flake8 app.py test_app.py
```

### Verificar saúde da aplicação

```bash
# Com o script de healthcheck incluído
chmod +x healthcheck.sh
./healthcheck.sh localhost 5000
```

---

## Como o Pipeline Funciona

O pipeline é definido no `.gitlab-ci.yml` e possui **5 stages** que rodam em sequência:

```
lint → test → build → security → deploy
```

### 🔍 Stage: `lint`

Roda o **flake8** para verificar estilo e qualidade do código Python.

- Falha automaticamente se houver erros de sintaxe ou estilo
- Configurado para aceitar linhas de até 88 caracteres (padrão Black)
- Roda em qualquer branch/MR para pegar problemas cedo

### 🧪 Stage: `test`

Executa os **testes unitários com pytest**.

- Falha se qualquer teste não passar
- Gera relatório JUnit XML (visível no GitLab como badge de testes)
- O artefato de relatório fica disponível por 1 semana

### 🐳 Stage: `build`

Constrói a **imagem Docker** e faz push para o **GitLab Container Registry**.

- Usa `docker:24-dind` (Docker-in-Docker) para buildar dentro do CI
- Taggeia a imagem com o SHA curto do commit (`$CI_COMMIT_SHORT_SHA`) e `latest`
- Usa `--cache-from` para reaproveitar layers anteriores e acelerar o build
- Adiciona labels com metadados do commit para rastreabilidade

### 🔒 Stage: `security` *(bônus)*

Roda análise estática de segurança (**SAST**) com **Bandit**.

- Detecta vulnerabilidades comuns em Python (SQL injection, uso de `exec`, etc.)
- Configurado com `allow_failure: true` para não bloquear o deploy em falhas de baixo nível
- Gera relatório de segurança compatível com o formato GitLab SAST

### 🚀 Stage: `deploy`

Simula o deploy no **AWS ECS** imprimindo os comandos AWS CLI que seriam executados.

- **Roda APENAS na branch `main`** (controlado por `rules`)
- Imprime os passos reais de um deploy: register-task-definition, update-service, wait
- Em produção, bastaria descomentar os comandos AWS CLI reais e configurar as credenciais via variáveis de ambiente do GitLab

#### Cache do Pipeline

O pipeline usa cache das dependências pip baseado no hash do `requirements.txt`. Isso significa que enquanto as dependências não mudarem, o pip não precisa baixar nada — reduzindo o tempo de build consideravelmente.

---

## Decisões Técnicas

### Multi-stage build no Dockerfile

**Por quê?** Para separar o ambiente de build do ambiente de runtime. O stage `builder` instala gcc e outras ferramentas de compilação. O stage `runtime` usa apenas o Python mínimo + as dependências instaladas, resultando em uma imagem final muito menor e sem ferramentas desnecessárias que poderiam ser vetores de ataque.

### Python 3.12-alpine como base

**Por quê?** Alpine é significativamente menor que a imagem `slim` (~5MB vs ~25MB). A desvantagem é que pode exigir compilação de algumas dependências (por isso o gcc no builder), mas o resultado final é mais enxuto e seguro.

### Usuário não-root

**Por quê?** Rodar como root dentro de um container é um risco de segurança. Se um atacante explorar uma vulnerabilidade na aplicação, ele ganha acesso de root dentro do container. Com um usuário dedicado (`appuser`), o impacto fica limitado.

### Tag com SHA do commit

**Por quê?** Usar `latest` sozinho dificulta rastrear qual versão está rodando em produção. Taggear com `$CI_COMMIT_SHORT_SHA` permite saber exatamente qual commit está deployado e facilita rollbacks.

### Cache no pipeline com chave baseada em `requirements.txt`

**Por quê?** As dependências só mudam quando o `requirements.txt` muda. Usar o hash desse arquivo como chave de cache significa que o cache é invalidado automaticamente quando necessário, e reaproveitado em todos os outros casos.

### `allow_failure: true` no security scan

**Por quê?** Em um projeto pequeno, parar o deploy por causa de um aviso de nível baixo seria contraprodutivo. A abordagem adotada é reportar sem bloquear, deixando a decisão para o time. Em produção, configuraria thresholds mais precisos.

### Terraform com Fargate

**Por quê?** O AWS Fargate elimina a necessidade de gerenciar instâncias EC2. Para um trainee ou equipe pequena, isso reduz drasticamente a carga operacional — você só paga pelo tempo de execução das tasks.

---

## O que Faria com Mais Tempo

1. **ALB (Application Load Balancer)**: Adicionar um load balancer na frente do ECS para ter um endpoint estável, HTTPS e health checks gerenciados.

2. **Secrets Manager**: Mover qualquer configuração sensível para o AWS Secrets Manager em vez de variáveis de ambiente em texto claro.

3. **Ambiente de staging**: Adicionar um deploy automático para staging em qualquer push para `develop`, e deploy para produção apenas com aprovação manual.

4. **Métricas e alertas**: Configurar CloudWatch Alarms para CPU, memória e erros 5xx, com notificações via SNS.

5. **Terraform remoto**: Usar S3 + DynamoDB como backend do Terraform para compartilhar o state entre o CI e o time.

6. **Rate limiting**: Adicionar Flask-Limiter para proteger a API de abuso.

7. **Testes de integração**: Adicionar uma stage de teste que sobe a aplicação real em Docker e faz requisições HTTP reais (não apenas testes unitários com mock do Flask).

---

## Como Usei IA no Desafio

Usei o Claude como principal ferramenta durante todo o desafio. Meu processo foi: primeiro li o PDF completo e pedi pra IA 
me explicar cada tecnologia que eu não conhecia bem (Docker multi-stage build, variáveis do GitLab CI, como o ECS 
funciona). Depois fui pedindo a geração de cada arquivo e revisando o que foi gerado — comparei com a documentação oficial 
do Docker e do GitLab pra entender se as decisões faziam sentido. O que mais aprendi foi a lógica do pipeline: por que a 
ordem das stages importa, e por que o deploy só roda na main.

### Prompts utilizados e para quê

**1. Leitura e planejamento inicial**
> *"Leia esse arquivo e me entregue tudo que ele está pedindo"*

Resultado: A IA leu o PDF do desafio e planejou a entrega completa de todos os artefatos (obrigatórios + bônus), gerando os arquivos em sequência.

**2. Geração dos arquivos**
A IA gerou diretamente: `Dockerfile`, `.gitlab-ci.yml`, `docker-compose.yml`, `terraform/main.tf`, `healthcheck.sh`, `README.md` e os arquivos de configuração (`.flake8`, `.gitignore`).

### O que funcionou bem

- A IA conhece muito bem as boas práticas de Docker (multi-stage, non-root, healthcheck) e as aplicou corretamente sem precisar ser pedido explicitamente
- A estrutura do `.gitlab-ci.yml` ficou correta de primeira, incluindo o uso correto das variáveis de CI do GitLab
- O Terraform ficou bem estruturado com uso de `data sources`, `outputs` e comentários explicativos

### O que exigiu verificação

- As versões das imagens Docker precisam ser verificadas periodicamente (usei `python:3.12-alpine` e `docker:24-alpine` que eram recentes no momento)
- O Terraform foi gerado como base simplificada conforme pedido — em produção precisaria de revisão para o caso de uso específico (VPC customizada, ALB, etc.)

### Aprendizado demonstrado

A IA foi usada como ferramenta de aceleração, não como substituição do raciocínio. As decisões técnicas documentadas acima refletem entendimento real do porquê de cada escolha, não apenas copiar e colar código gerado.

---

## Estrutura do Repositório

```
trainee-devops-api/
├── app.py                  # Aplicação Flask
├── test_app.py             # Testes unitários (pytest)
├── requirements.txt        # Dependências Python
├── Dockerfile              # Multi-stage build com Alpine e non-root user
├── .gitlab-ci.yml          # Pipeline CI/CD completo
├── docker-compose.yml      # Para rodar localmente (bônus)
├── healthcheck.sh          # Script de healthcheck (bônus)
├── .flake8                 # Configuração do linter
├── .gitignore
├── README.md
└── terraform/
    └── main.tf             # Infraestrutura AWS ECS com Terraform (bônus)
```
