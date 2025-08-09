# Apache Flink Project Setup (Docker + WSL2)

**Autor:** Ronaldo Ramires  
**Data:** 09/08/2025

Este repositório contém a infraestrutura básica para executar o **Apache Flink 2.0.0** em containers Docker sobre **WSL2 (Ubuntu 24.04)**, com suporte a Flink SQL e conectividade com **PostgreSQL** (via JDBC).

## 📂 Estrutura de Arquivos

- **`create_flink_structure.sh`**  
  Script para criar a estrutura de diretórios (`libs/`, `drivers/`, `config/`, `jobs/`), baixar o driver JDBC do PostgreSQL e gerar automaticamente o `docker-compose.yml` e arquivos de configuração.

- **`docker-compose.yml`**  
  Define os serviços **JobManager** e **TaskManager** do Flink.  
  Monta volumes para configuração, jobs, bibliotecas e drivers, copiando automaticamente os JARs de `drivers` para o classpath (`/opt/flink/lib`) na inicialização.

## 🚀 Como Usar

1. **Executar o script de criação da infraestrutura**  
   ```bash
   chmod +x create_flink_structure.sh
   ./create_flink_structure.sh
