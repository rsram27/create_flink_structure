#!/bin/bash

# --- Variáveis de Configuração ---
FLINK_PROJECT_DIR="/home/ramires/flink-project"
PG_JDBC_URL="https://jdbc.postgresql.org/download/postgresql-42.7.3.jar" # URL do driver JDBC PostgreSQL
FLINK_VERSION="1.18" # Versão do Flink a ser utilizada
PG_DB_URL="jdbc:postgresql://ep-withered-union-a8byi1q8-pooler.eastus2.azure.neon.tech/neondb?sslmode=require&channel_binding=require"
PG_USERNAME="neondb_owner"
PG_PASSWORD="_______________"

# --- 1. Criação da Estrutura de Diretórios ---
echo "1. Criando a estrutura de diretórios em $FLINK_PROJECT_DIR..."
mkdir -p "${FLINK_PROJECT_DIR}/"{libs,drivers,config,jobs}
if [ $? -eq 0 ]; then
    echo "   Estrutura de diretórios criada com sucesso."
else
    echo "   Erro ao criar a estrutura de diretórios. Verifique as permissões ou o caminho."
    exit 1
fi

# --- 2. Configuração das Permissões ---
echo "2. Definindo permissões de escrita para os diretórios do projeto..."
sudo chmod -R 775 "$FLINK_PROJECT_DIR"
if [ $? -eq 0 ]; then
    echo "   Permissões configuradas com sucesso."
else
    echo "   Erro ao definir permissões. Certifique-se de ter permissões de sudo."
    exit 1
fi

# --- 3. Baixar o Driver JDBC do PostgreSQL ---
echo "3. Baixando o driver JDBC do PostgreSQL..."
wget -q -O "${FLINK_PROJECT_DIR}/drivers/postgresql.jar" "$PG_JDBC_URL"
if [ $? -eq 0 ]; then
    echo "   Driver JDBC baixado em ${FLINK_PROJECT_DIR}/drivers/postgresql.jar"
else
    echo "   Erro ao baixar o driver JDBC. Verifique a URL ou sua conexão com a internet."
    exit 1
fi

# --- 4. Criar o arquivo docker-compose.yml ---
echo "4. Criando o arquivo docker-compose.yml..."
cat <<EOF > "${FLINK_PROJECT_DIR}/docker-compose.yml"
services:
  jobmanager:
    image: apache/flink:${FLINK_VERSION}
    container_name: flink-jobmanager
    hostname: jobmanager
    ports:
      - "8081:8081"
    # Copia os JARs de drivers para /opt/flink/lib antes de iniciar
    command: ["/bin/sh","-lc","cp -n /opt/flink/drivers/*.jar /opt/flink/lib/ 2>/dev/null || true; exec jobmanager"]
    restart: unless-stopped
    environment:
      FLINK_PROPERTIES: |
        jobmanager.rpc.address: jobmanager
        jobmanager.memory.process.size: 1024m
        taskmanager.memory.process.size: 1024m
        taskmanager.numberOfTaskSlots: 1
    volumes:
      - ./config:/opt/flink/conf
      - ./jobs:/opt/flink/jobs
      - ./libs:/opt/flink/lib
      - ./drivers:/opt/flink/drivers

  taskmanager:
    image: apache/flink:${FLINK_VERSION}
    container_name: flink-taskmanager
    hostname: taskmanager
    depends_on:
      - jobmanager
    # Garante que os drivers também estejam no classpath do TaskManager
    command: ["/bin/sh","-lc","cp -n /opt/flink/drivers/*.jar /opt/flink/lib/ 2>/dev/null || true; exec taskmanager"]
    restart: unless-stopped
    environment:
      FLINK_PROPERTIES: |
        jobmanager.rpc.address: jobmanager
        taskmanager.memory.process.size: 1024m
        taskmanager.numberOfTaskSlots: 1
    volumes:
      - ./config:/opt/flink/conf
      - ./jobs:/opt/flink/jobs
      - ./libs:/opt/flink/lib
      - ./drivers:/opt/flink/drivers
EOF
echo "   docker-compose.yml criado com sucesso em ${FLINK_PROJECT_DIR}/docker-compose.yml"

# --- 5. Criar o arquivo sql-client-defaults.yaml ---
echo "5. Criando o arquivo sql-client-defaults.yaml..."
cat <<EOF > "${FLINK_PROJECT_DIR}/config/sql-client-defaults.yaml"
# /home/ramires/flink-project/config/sql-client-defaults.yaml

execution:
  current-database: default
  planner: flink
  type: streaming
  max-idle-state-retention: 0
  state.ttl-time: 0
  checkpointing:
    interval: 10s
    mode: EXACTLY_ONCE
tables:
  - name: weather_data
    type: source
    connector:
      type: jdbc
      url: "${PG_DB_URL}"
      table-name: weather_data
      username: "${PG_USERNAME}"
      password: "${PG_PASSWORD}"
      driver: org.postgresql.Driver
    format:
      type: raw
    schema:
      - name: id
        type: BIGINT
      - name: timestamp_utc3
        type: TIMESTAMP(3)
      - name: temperature_celsius
        type: DOUBLE
      - name: humidity
        type: INT

  - name: weather_data_silver
    type: sink
    connector:
      type: jdbc
      url: "${PG_DB_URL}"
      table-name: weather_data_silver
      username: "${PG_USERNAME}"
      password: "${PG_PASSWORD}"
      driver: org.postgresql.Driver
    format:
      type: raw
    schema:
      - name: hour_start
        type: TIMESTAMP(3)
      - name: min_temp
        type: DOUBLE
      - name: max_temp
        type: DOUBLE
      - name: avg_temp
        type: DOUBLE
      - name: min_humidity
        type: INT
      - name: max_humidity
        type: INT
      - name: avg_humidity
        type: DOUBLE
      - name: last_id
        type: BIGINT
EOF
echo "   sql-client-defaults.yaml criado com sucesso em ${FLINK_PROJECT_DIR}/config/sql-client-defaults.yaml"

# --- 6. Criar o script SQL do Flink Job ---
echo "6. Criando o script SQL para o job Flink..."
cat <<EOF > "${FLINK_PROJECT_DIR}/jobs/weather_data_processing.sql"
-- /home/ramires/flink-project/jobs/weather_data_processing.sql

INSERT INTO weather_data_silver
SELECT
    TUMBLE_START(timestamp_utc3, INTERVAL '1' HOUR) AS hour_start,
    MIN(temperature_celsius) AS min_temp,
    MAX(temperature_celsius) AS max_temp,
    AVG(temperature_celsius) AS avg_temp,
    MIN(humidity) AS min_humidity,
    MAX(humidity) AS max_humidity,
    AVG(humidity) AS avg_humidity,
    MAX(id) AS last_id
FROM weather_data
GROUP BY TUMBLE(timestamp_utc3, INTERVAL '1' HOUR);
EOF
echo "   weather_data_processing.sql criado com sucesso em ${FLINK_PROJECT_DIR}/jobs/weather_data_processing.sql"

echo -e "\n--- Configuração Completa! ---"
echo "Todos os arquivos necessários foram criados em ${FLINK_PROJECT_DIR}."

echo -e "\n--- Próximos Passos ---"
echo "1. cd ${FLINK_PROJECT_DIR}"
echo "2. docker compose up -d"
echo "   (UI do Flink: http://localhost:8081)"
echo "3. Para rodar o job no SQL Client:"
echo "   docker exec -it flink-jobmanager bash"
echo "   ./bin/sql-client.sh -f /opt/flink/jobs/weather_data_processing.sql -defaults /opt/flink/conf/sql-client-defaults.yaml"
echo "4. Parar: docker compose down"
echo "5. Reiniciar: docker compose restart"
echo "6. Limpeza (cautela): docker compose down -v && docker rmi apache/flink:${FLINK_VERSION} && docker image prune -a"
echo "7. Novos JARs: copie para 'drivers/' ou 'libs/' e reinicie."
