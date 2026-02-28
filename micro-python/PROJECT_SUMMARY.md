# Project Completion Report: IoT Temperature Monitor

**Date:** 2026-02-28
**Status:** Software Stack Complete

## Project Overview
We have successfully built and deployed a robust, full-stack IoT temperature monitoring system. The system captures real-time data from a Raspberry Pi Pico 2 W, transmits it wirelessly, stores it in a time-series database, and visualizes it with automated alerting.

## System Architecture

### 1. Firmware (Edge)
*   **Device:** Raspberry Pi Pico 2 W
*   **Language:** MicroPython
*   **Key Features:**
    *   **Resilience:** Robust MQTT reconnection logic (`mqtt_as`).
    *   **Configuration:** Settings decoupled into `config.json`.
    *   **Sensors:** Modular support for DS18B20 and DHT22.
*   **Location:** Project Root (`/`)

### 2. Backend (Infrastructure)
*   **Containerization:** Fully Dockerized stack defined in `backend/docker-compose.yml`.
*   **Broker:** Eclipse Mosquitto (MQTT).
*   **Ingestion:** Telegraf (translates MQTT JSON -> InfluxDB Line Protocol).
*   **Database:** InfluxDB v2 (Time-series storage).
*   **Location:** `/backend`

### 3. Visualization & Alerting
*   **Platform:** Grafana v10
*   **Automation:**
    *   **Datasources:** Automatically connected to InfluxDB.
    *   **Dashboards:** "Temperature Monitor" pre-loaded via JSON provisioning.
    *   **Alerting:** Automated rules for High Temperature (>30°C), configurable via `.env`.
*   **Access:** [http://localhost:3000](http://localhost:3000) (User/Pass: admin/admin)

## How to Run
1.  **Start Backend:**
    ```bash
    cd backend
    docker-compose up -d
    ```
2.  **Deploy Firmware:**
    *   Upload `main.py`, `config.json`, `zour-dough-*.py`, and `lib/` to the Pico.
    *   Reset the Pico.

## Handover Notes
*   **Hardware:** You are handling the casing/enclosure.
*   **Secrets:** `mqtt_local.py` was removed from git history for security. Use `config.json` or environment variables for secrets.
*   **Future Expansion:** The stack is ready for more sensors (Humidity, Pressure) by simply adding new fields to the JSON payload in the firmware; Telegraf will automatically pick them up.

**Great work on this project! The system is now yours to maintain and expand.**
