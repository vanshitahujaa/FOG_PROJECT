# System Architecture Documentation

Detailed architecture diagrams for the Fog-Assisted FDIA Detection System.

---

## 1. High-Level System Architecture

```mermaid
flowchart TB
    subgraph Physical["Physical Layer - Smart Grid Substation"]
        direction LR
        PMU["PMU/RTU Sensors"]
        SCADA["SCADA System"]
        Breakers["Circuit Breakers"]
    end
    
    subgraph Fog["Fog Layer - Edge Computing Node"]
        direction TB
        Buffer["Data Buffer"]
        FE["Feature Extractor"]
        SVM["SVM Detector"]
        AE["Autoencoder"]
        Alert["Alert Manager"]
        
        Buffer --> FE
        FE --> SVM
        FE --> AE
        SVM --> Alert
        AE --> Alert
    end
    
    subgraph Cloud["Cloud Layer - Central Control"]
        direction LR
        Storage["Long-term Storage"]
        Dashboard["Monitoring Dashboard"]
        ModelMgr["Model Manager"]
        Analytics["Advanced Analytics"]
    end
    
    Physical -->|"Raw Measurements\n(< 1 sec)"| Fog
    Fog -->|"Alerts Only\n(when attack detected)"| Cloud
    Cloud -.->|"Model Updates\n(periodic)"| Fog
    Fog -->|"Local Response\n(< 100ms)"| Physical
    
    style Fog fill:#e1f5fe
    style Physical fill:#fff3e0
    style Cloud fill:#f3e5f5
```

---

## 2. FDIA Attack Model

```mermaid
flowchart LR
    subgraph Normal["Normal Operation"]
        Z1["z = Hx + e"]
        SE1["State Estimation"]
        R1["r = z - Hx̂"]
        BDD1["BDD Check\n‖r‖ < τ"]
        
        Z1 --> SE1 --> R1 --> BDD1
        BDD1 -->|"Pass"| OK1["✓ Accept"]
    end
    
    subgraph Attack["FDIA Attack"]
        Z2["z_a = z + a\nwhere a = Hc"]
        SE2["State Estimation"]
        R2["r_a = z_a - Hx̂_a"]
        BDD2["BDD Check\n‖r_a‖ ≈ ‖r‖"]
        
        Z2 --> SE2 --> R2 --> BDD2
        BDD2 -->|"Pass!"| BAD["✗ Undetected!"]
    end
    
    style BAD fill:#ffcdd2
    style OK1 fill:#c8e6c9
```

**Key Insight**: Attack `a = Hc` ensures residual unchanged, bypassing traditional detection.

---

## 3. Detection Pipeline

```mermaid
flowchart TD
    subgraph Input["Data Input"]
        Raw["Raw Measurements\n(V, θ, P, Q)"]
    end
    
    subgraph Features["Feature Extraction"]
        direction LR
        Stat["Statistical\n• Mean\n• Std\n• Skewness\n• Kurtosis"]
        Temp["Temporal\n• Diff\n• Trend\n• Autocorr"]
        Res["Residual\n• ‖r‖\n• Max|r|\n• Normalized"]
    end
    
    subgraph Models["Detection Models"]
        direction TB
        SVM["One-Class SVM\n(Boundary Learning)"]
        AE["Autoencoder\n(Reconstruction Error)"]
        Ensemble["Ensemble\n(Majority Vote)"]
        
        SVM --> Ensemble
        AE --> Ensemble
    end
    
    subgraph Output["Decision"]
        Dec{{"Attack\nDetected?"}}
        Normal["Normal\n(Log only)"]
        Attack["ATTACK!\n(Alert + Response)"]
    end
    
    Raw --> Features
    Stat --> Models
    Temp --> Models
    Res --> Models
    Models --> Dec
    Dec -->|"No"| Normal
    Dec -->|"Yes"| Attack
    
    style Attack fill:#ffcdd2
    style Normal fill:#c8e6c9
```

---

## 4. Fog Node Architecture

```mermaid
classDiagram
    class FogNode {
        -model: DetectionModel
        -buffer: DataBuffer
        -alertQueue: Alert[]
        -latencyLog: float[]
        +processReading(reading, timestamp)
        +processBatch(readings, timestamps)
        +flushAlerts() Alert[]
        +getStats() Statistics
        +reset()
    }
    
    class DetectionModel {
        <<interface>>
        +predict(features) bool
        +getScore(features) float
    }
    
    class SVMModel {
        -svm: fitcsvm
        -normParams: struct
        -threshold: float
        +predict(features) bool
    }
    
    class AutoencoderModel {
        -net: network
        -threshold: float
        +predict(features) bool
        +getReconstructionError(features) float
    }
    
    class CloudLayer {
        -alertLog: Alert[]
        -aggregatedStats: struct
        +receiveAlerts(alerts, nodeId)
        +generateDashboard() DashboardData
    }
    
    FogNode --> DetectionModel
    SVMModel ..|> DetectionModel
    AutoencoderModel ..|> DetectionModel
    FogNode --> CloudLayer : sends alerts
```

---

## 5. Data Flow Diagram

```mermaid
sequenceDiagram
    participant S as Sensors
    participant F as Fog Node
    participant M as Detection Model
    participant C as Cloud
    
    loop Every Sampling Period
        S->>F: Raw Measurement (V, P, Q)
        F->>F: Add to Buffer
        
        alt Buffer Full (window size)
            F->>F: Extract Features
            F->>M: Request Prediction
            M->>F: Attack Score
            
            alt Score > Threshold
                F->>F: Generate Alert
                F->>S: Local Response (optional)
                F-->>C: Queue Alert
            else Score <= Threshold
                F->>F: Log as Normal
            end
            
            F->>F: Slide Window
        end
    end
    
    loop Every Sync Period
        F->>C: Flush Alert Queue
        C->>C: Store & Analyze
        C-->>F: Model Update (if any)
    end
```

---

## 6. Attack Types Visualization

```mermaid
flowchart TB
    subgraph Attacks["FDIA Attack Types"]
        direction TB
        
        subgraph Simple["Simple Attacks"]
            Bias["Bias Attack\n━━━━━━━━\nConstant offset\non target buses"]
            Scaling["Scaling Attack\n━━━━━━━━\nProportional\nmeasurement change"]
        end
        
        subgraph Advanced["Advanced Attacks"]
            Ramp["Ramp Attack\n━━━━━━━━\nGradual increase\nover time"]
            Coord["Coordinated Attack\n━━━━━━━━\nMulti-sensor\ncorrelated changes"]
        end
        
        subgraph Stealthy["Stealthy Attacks"]
            Random["Random Stealthy\n━━━━━━━━\nLow magnitude\nwithin threshold"]
            Replay["Replay Attack\n━━━━━━━━\nHistorical data\ninjection"]
        end
    end
    
    style Simple fill:#fff3e0
    style Advanced fill:#e3f2fd
    style Stealthy fill:#fce4ec
```

---

## 7. Metrics Dashboard Layout

```mermaid
graph TB
    subgraph Dashboard["Detection Metrics Dashboard"]
        direction TB
        
        subgraph Row1["Performance Metrics"]
            Acc["Accuracy\n92.5%"]
            Prec["Precision\n89.3%"]
            Rec["Recall\n87.1%"]
            F1["F1-Score\n0.882"]
        end
        
        subgraph Row2["Error Metrics"]
            FAR["False Alarm Rate\n8.2%"]
            MDR["Miss Detection\n12.9%"]
        end
        
        subgraph Row3["Latency"]
            AvgLat["Avg Latency\n23ms"]
            P95["P95 Latency\n45ms"]
            MaxLat["Max Latency\n89ms"]
        end
    end
    
    style Row1 fill:#c8e6c9
    style Row2 fill:#ffcdd2
    style Row3 fill:#e1f5fe
```

---

## 8. IEEE 14-Bus Topology

```mermaid
graph TD
    B1((1<br/>Slack)) --- B2((2))
    B1 --- B5((5))
    B2 --- B3((3))
    B2 --- B4((4))
    B2 --- B5
    B3 --- B4
    B4 --- B5
    B4 --- B7((7))
    B4 --- B9((9))
    B5 --- B6((6))
    B6 --- B11((11))
    B6 --- B12((12))
    B6 --- B13((13))
    B7 --- B8((8))
    B7 --- B9
    B9 --- B10((10))
    B9 --- B14((14))
    B10 --- B11
    B12 --- B13
    B13 --- B14
    
    style B1 fill:#4caf50,color:white
    style B2 fill:#2196f3,color:white
    style B3 fill:#2196f3,color:white
```

**Legend**: 
- 🟢 Slack Bus (Reference)
- 🔵 PQ/PV Buses

---

## Summary

| Layer | Function | Latency Target |
|-------|----------|----------------|
| Physical | Data collection | Real-time |
| Fog | Detection + Local response | < 100ms |
| Cloud | Storage + Analytics | Non-critical |

**Key Principle**: Detection happens at the edge (fog), not the cloud, enabling fast response and reduced bandwidth.
