![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Symfony](https://img.shields.io/badge/Symfony-000000?style=for-the-badge&logo=symfony&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![TensorFlow](https://img.shields.io/badge/TensorFlow-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)
![OpenCV](https://img.shields.io/badge/OpenCV-5C3EE8?style=for-the-badge&logo=opencv&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Metabase](https://img.shields.io/badge/Metabase-509EE3?style=for-the-badge&logo=metabase&logoColor=white)
![Mistral AI](https://img.shields.io/badge/Mistral_AI-000000?style=for-the-badge&logo=mistral&logoColor=white)
![Google Cloud](https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![Ngrok](https://img.shields.io/badge/Ngrok-1F1E37?style=for-the-badge&logo=ngrok&logoColor=white)
![Jira](https://img.shields.io/badge/Jira-0052CC?style=for-the-badge&logo=jira&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-1.0.0-blue?style=for-the-badge)

<p align="center">
  <img src="assets/logo.png" alt="Smart Resto IA Logo" width="200">
</p>

<h1 align="center">🍽️ Smart Resto IA</h1>

<p align="center">
  <b>Application intelligente de gestion de restaurants avec IA, analyse de données et expérience mobile premium</b>
</p>

<p align="center">
  <a href="#-aperçu">Aperçu</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-technologies">Technologies</a> •
  <a href="#-intelligence-artificielle">IA</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-api">API</a> •
  <a href="#-metabase">Metabase</a> •
  <a href="#-documentation">Documentation</a>
</p>

---

## 📌 Aperçu

**Smart Resto IA** est une solution complète de gestion de restaurants qui intègre :

| Fonctionnalité | Description |
|----------------|-------------|
| 🧠 **Détection d'humeur** | Analyse des expressions faciales des clients via OpenCV + TensorFlow |
| 📊 **Recommandations IA** | Suggestions personnalisées de plats basées sur l'historique et l'humeur |
| 💬 **Chatbot intelligent** | Assistance conversationnelle avec Mistral AI |
| 📱 **Application mobile** | Interface Flutter multiplateforme (iOS & Android) |
| 🔧 **API REST** | Backend Symfony robuste et sécurisé |
| 📈 **Tableaux de bord** | Visualisation des données avec Metabase |
| 🗄️ **Base de données** | MySQL pour le stockage relationnel |
| ☁️ **Services Cloud** | Google Cloud API pour les fonctionnalités avancées |

---

## 🏗️ Architecture

### Vue d'ensemble

```mermaid
graph TB
    subgraph "Frontend Mobile"
        A[Flutter App]
    end
    
    subgraph "Backend"
        B[Symfony API REST]
        C[MySQL Database]
        D[Metabase Analytics]
    end
    
    subgraph "Services IA"
        E[Python Services]
        F[OpenCV - Emotion Detection]
        G[TensorFlow - Classification]
        H[Mistral AI - Chatbot]
        I[Google Cloud API]
    end
    
    subgraph "Infrastructure"
        J[Ngrok - API Exposition]
        K[Git - Version Control]
        L[Jira - Project Management]
    end
    
    A -->|HTTP/HTTPS| B
    B -->|ORM| C
    B -->|API Calls| E
    E --> F
    E --> G
    E --> H
    E --> I
    C --> D
    B --> J
    K --> A
    K --> B
    K --> E
    L --> A
    L --> B
    L --> E
