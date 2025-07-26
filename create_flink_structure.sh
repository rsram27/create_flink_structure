#!/bin/bash

# Script para criar a estrutura completa (diretórios e arquivos) para o projeto Flink.

# 1. Define o caminho base do projeto, conforme solicitado originalmente.
FLINK_PROJECT_PATH="/home/ramires/flink-project"

# 2. Informa ao usuário o que será feito
echo "-----------------------------------------------------"
echo "Criando a estrutura completa do projeto em: $FLINK_PROJECT_PATH"
echo "-----------------------------------------------------"

# 3. Cria a estrutura de diretórios
echo "[1/4] Criando diretórios: libs, drivers, config, jobs..."
mkdir -p "$FLINK_PROJECT_PATH"/{libs,drivers,config,jobs}
echo "Diretórios criados."
echo ""

# 4. Cria o arquivo docker-compose.yml com o conteúdo necessário
echo "[2/4] Criando o arquivo docker-compose.yml..."
cat <<EOF > "$FLINK_PROJECT_PATH/docker-compose.yml"
services:
  jobmanager:
    image: flink:1.18-scala_2.12-java11
    container_name: flink_jobmanager
    ports:
      - "8081:8081" # UI do Flink
    command: jobmanager
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
    volumes:
      - ./jobs:/opt/flink/jobs
      - ./libs:/opt/flink/usrlib
      - ./drivers:/opt/flink/lib
      - ./config/flink-conf.yaml:/opt/flink/conf/flink-conf.yaml
    networks:
      - flink-network

  taskmanager:
    image: flink:1.18-scala_2.12-java11
    container_name: flink_taskmanager
    command: taskmanager
    depends_on:
      - jobmanager
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        taskmanager.numberOfTaskSlots: 2
    volumes:
      - ./jobs:/opt/flink/jobs
      - ./libs:/opt/flink/usrlib
      - ./drivers:/opt/flink/lib
      - ./config/flink-conf.yaml:/opt/flink/conf/flink-conf.yaml
    networks:
      - flink-network

networks:
  flink-network:
    driver: bridge
EOF
echo "docker-compose.yml criado."
echo ""

# 5. Cria o arquivo do job SQL
echo "[3/4] Criando o arquivo jobs/aggregate_weather.sql..."
cat <<EOF > "$FLINK_PROJECT_PATH/jobs/aggregate_weather.sql"
-- #############################################################################
-- ## Tabela de Origem (Source): Leitura dos dados brutos do PostgreSQL
-- #############################################################################
CREATE TABLE weather_data_source (
    id SERIAL,
    timestamp_utc3 TIMESTAMPTZ(3),
    temperature_celsius DECIMAL(5, 2),
    humidity INT,
    WATERMARK FOR timestamp_utc3 AS timestamp_utc3 - INTERVAL '5' SECOND
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://ep-withered-union-a8byi1q8-pooler.eastus2.azure.neon.tech:5432/neondb?sslmode=require&channel_binding=require',
    'table-name' = 'public.weather_data',
    'username' = 'neondb_owner',
    'password' = 'npg_DlAO1qkuUn7j',
    'scan.partition.column' = 'id',
    'scan.partition.num' = '1',
    'scan.fetch-size' = '1000'
);

-- #############################################################################
-- ## Tabela de Destino (Sink): Onde os dados agregados serão salvos
-- #############################################################################
CREATE TABLE weather_data_silver (
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    min_temp DECIMAL(5, 2),
    max_temp DECIMAL(5, 2),
    avg_temp DECIMAL(5, 2),
    min_humidity INT,
    max_humidity INT,
    avg_humidity INT,
    PRIMARY KEY (window_start) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://ep-withered-union-a8byi1q8-pooler.eastus2.azure.neon.tech:5432/neondb?sslmode=require&channel_binding=require',
    'table-name' = 'public.weather_data_silver',
    'username' = 'neondb_owner',
    'password' = 'npg_DlAO1qkuUn7j'
);

-- #############################################################################
-- ## Job de Agregação: Lê da origem, agrega e insere no destino
-- #############################################################################
INSERT INTO weather_data_silver
SELECT
    TUMBLE_START(timestamp_utc3, INTERVAL '1' HOUR) AS window_start,
    TUMBLE_END(timestamp_utc3, INTERVAL '1' HOUR) AS window_end,
    MIN(temperature_celsius) AS min_temp,
    MAX(temperature_celsius) AS max_temp,
    AVG(temperature_celsius) AS avg_temp,
    MIN(humidity) AS min_humidity,
    MAX(humidity) AS max_humidity,
    CAST(AVG(humidity) AS INT) AS avg_humidity
FROM weather_data_source
GROUP BY TUMBLE(timestamp_utc3, INTERVAL '1' HOUR);
EOF
echo "jobs/aggregate_weather.sql criado."
echo ""

# 6. Cria um arquivo de configuração vazio para o Flink (opcional, mas boa prática)
echo "[4/4] Criando o arquivo de configuração config/flink-conf.yaml..."
touch "$FLINK_PROJECT_PATH/config/flink-conf.yaml"
echo "config/flink-conf.yaml criado."
echo ""

# 7. Confirma a conclusão e lista a estrutura criada
echo "-----------------------------------------------------"
echo "Projeto Flink configurado com sucesso!"
echo "-----------------------------------------------------"
echo "Estrutura final:"
ls -lR "$FLINK_PROJECT_PATH"
