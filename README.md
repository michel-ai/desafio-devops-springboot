# Desafio DevOps — Spring Boot, Docker, Kubernetes e CI

Projeto desenvolvido para demonstrar a conteinerização e a implantação de uma aplicação Spring Boot com PostgreSQL, incluindo automação de testes e construção de imagem Docker por meio do GitHub Actions.

## Tecnologias

- Java 21
- Spring Boot 4.1.2
- Maven Wrapper
- PostgreSQL 17
- Docker e Docker Compose
- Kubernetes com kind
- Kustomize
- GitHub Actions

## Arquitetura

A aplicação Spring Boot utiliza Spring Data JPA para conectar-se ao PostgreSQL.

No Docker Compose, os serviços compartilham uma rede interna e o banco utiliza um volume persistente.

No Kubernetes, a aplicação é executada em um Deployment e exposta por um Service ClusterIP. O PostgreSQL utiliza um StatefulSet, um Service interno e um PersistentVolumeClaim.

As configurações não sensíveis são fornecidas por variáveis de ambiente e ConfigMap. A senha do banco é fornecida por um arquivo .env local ou por um Kubernetes Secret.

## Pré-requisitos

- JDK 21
- Docker com Docker Compose
- kubectl
- kind
- Git

O Maven pode ser executado pelo wrapper incluído neste repositório.

## Configuração local

Copie o arquivo de exemplo:

```bash
cp .env.example .env
```

Edite o arquivo `.env` e defina uma senha de desenvolvimento para `DB_PASSWORD`.

O arquivo `.env` não deve ser adicionado ao Git.

## Executar com Docker Compose

Primeiro, compile a aplicação:

```bash
./mvnw clean package -DskipTests
```

Depois, construa a imagem e inicie os serviços:

```bash
docker compose up -d --build
```

Consulte o estado dos containers:

```bash
docker compose ps
```

Teste o endpoint de saúde:

```bash
curl http://localhost:18080/actuator/health
```

Para encerrar os containers:

```bash
docker compose down
```

O comando acima preserva o volume do PostgreSQL.

## Executar os testes Maven

Os testes de inicialização do Spring Boot precisam acessar uma instância PostgreSQL.

Uma alternativa para testar localmente é utilizar o PostgreSQL do cluster kind por meio de port-forward:

```bash
kubectl -n desafio-devops port-forward svc/postgres 15432:5432
```

Em outro terminal, com o arquivo `.env` configurado:

```bash
DB_URL="jdbc:postgresql://localhost:15432/desafio" \
DB_USERNAME="desafio" \
DB_PASSWORD="$(sed -n 's/^DB_PASSWORD=//p' .env | head -n 1)" \
./mvnw clean verify
```

O resultado esperado é BUILD SUCCESS.

## Kubernetes com kind

Crie um cluster local:

```bash
kind create cluster --name desafio-devops
```

Compile a aplicação e construa a imagem:

```bash
./mvnw clean package -DskipTests
docker build -t desafio-app:local .
```

Carregue a imagem no kind:

```bash
kind load docker-image desafio-app:local --name desafio-devops
```

Garanta que a imagem PostgreSQL 17 esteja disponível:

```bash
docker pull --platform linux/amd64 postgres:17
docker image save --platform linux/amd64 \
  --output /tmp/postgres-amd64.tar postgres:17
kind load image-archive /tmp/postgres-amd64.tar \
  --name desafio-devops
```

Crie o namespace:

```bash
kubectl apply -f k8s/namespace.yaml
```

Crie o Secret a partir do arquivo local `.env`:

```bash
kubectl -n desafio-devops create secret generic desafio-db-secret \
  --from-env-file=.env
```

Aplique os manifestos com Kustomize:

```bash
kubectl apply -k k8s/
```

Verifique o rollout:

```bash
kubectl -n desafio-devops rollout status \
  statefulset/postgres --timeout=180s

kubectl -n desafio-devops rollout status \
  deployment/desafio-app --timeout=180s
```

Inspecione os recursos:

```bash
kubectl -n desafio-devops get pods,svc,pvc
```

## Validar a aplicação no Kubernetes

Encaminhe a porta do Service:

```bash
kubectl -n desafio-devops port-forward svc/desafio-app 18081:8080
```

Em outro terminal:

```bash
curl -i http://localhost:18081/actuator/health
curl -i http://localhost:18081/actuator/health/liveness
curl -i http://localhost:18081/actuator/health/readiness
```

Os três endpoints devem retornar HTTP 200 e status UP.

## Segurança e persistência

- Aplicação executada sem privilégios de root, com UID/GID 10001.
- Escalada de privilégios desabilitada.
- Linux capabilities removidas do container.
- Perfil seccomp RuntimeDefault.
- Credenciais fornecidas por Kubernetes Secret.
- Configurações externas fornecidas por ConfigMap.
- PostgreSQL com PersistentVolumeClaim.
- Startup, readiness e liveness probes na aplicação.
- Limites e requisições de recursos nos workloads.

Os Secrets do Kubernetes não são criptografados automaticamente em repouso em todas as configurações de cluster. Este projeto utiliza Secrets para demonstrar separação de configuração e credenciais, sem representar uma solução completa de gerenciamento de segredos em produção.

## Integração contínua

O workflow `.github/workflows/ci.yml` foi configurado para:

1. Executar checkout do repositório.
2. Configurar Java 21.
3. Inicializar PostgreSQL 17 como serviço de CI.
4. Executar testes e empacotamento com Maven.
5. Construir a imagem Docker.
6. Validar a imagem resultante.

A execução deve ser verificada na aba Actions do repositório GitHub.

## Observações

O Dockerfile utiliza o JAR previamente gerado pelo Maven. Por isso, execute o build Maven antes de construir a imagem Docker.

O ambiente kind é destinado à demonstração local da implantação Kubernetes. Para produção, seriam necessários controles adicionais, como gerenciamento de segredos, políticas de rede, TLS, backups e uma estratégia adequada de armazenamento persistente.
