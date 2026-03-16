# Fog-Assisted FDIA Detection System for Smart Grid Substations

A secure anomaly detection model using MATLAB to identify False Data Injection Attacks (FDIA) in smart grid substations, with detection logic deployed at the fog layer.

## 📋 Overview

This project implements a complete pipeline for detecting sophisticated FDIA attacks that bypass traditional residual-based bad data detection. The detection runs on simulated fog nodes for low-latency, near-source protection.

### Key Features

- **IEEE Bus System Integration**: Uses MATPOWER for realistic power system simulation
- **Multiple Attack Types**: Bias, ramp, coordinated, stealthy, targeted, scaling, replay
- **5-Model Comparison**: SVM, Autoencoder, Random Forest, KNN, PCA
- **Fog Layer Simulation**: Real-time detection with latency tracking
- **Comprehensive Metrics**: Accuracy, Precision, Recall, F1, FAR, AUC-ROC
- **Mathematical Foundation**: Full state estimation model with FDIA bypass proof

## 🚀 Quick Start

### Prerequisites

1. **MATLAB R2020a or later**
2. **MATPOWER** - Download from [matpower.org](https://matpower.org/)
3. **Statistics and Machine Learning Toolbox**
4. (Optional) Deep Learning Toolbox for Autoencoder

### Installation

```matlab
% 1. Install MATPOWER
addpath('/path/to/matpower');
install_matpower;

% 2. Navigate to project
cd('/Users/vanshitahuja/Documents/FOG_PROJECT');

% 3. Run the pipeline
main
```

## 📁 Project Structure

```
FOG_PROJECT/
├── main.m                 # Entry point — 5-model comparison pipeline
├── quickStart.m           # Quick demo with reduced dataset
├── config.m               # Global configuration
├── setupMatpower.m        # MATPOWER installation helper
├── data/
│   ├── generateNormalData.m   # Time-series from IEEE bus
│   └── loadDataset.m          # Data utilities
├── attacks/
│   ├── computeJacobian.m      # H matrix calculation
│   ├── injectFDIA.m           # Attack injection (a = Hc)
│   ├── attackScenarios.m      # Basic attack scenarios
│   └── advancedAttackScenarios.m  # 10 advanced scenarios
├── features/
│   ├── extractFeatures.m      # Statistical + temporal features
│   └── computeResiduals.m     # State estimation residuals
├── models/
│   ├── trainSVM.m             # One-class & binary SVM
│   ├── trainAutoencoder.m     # Reconstruction-based detection
│   ├── trainRandomForest.m    # TreeBagger ensemble
│   ├── trainKNN.m             # K-nearest neighbors
│   ├── trainPCA.m             # PCA anomaly detection (T² + Q)
│   └── detectAnomaly.m        # Unified detection interface
├── fog/
│   ├── FogNode.m              # Fog layer simulation
│   └── CloudLayer.m           # Cloud logging & alerts
├── evaluation/
│   ├── computeMetrics.m       # All evaluation metrics
│   └── plotResults.m          # Visualization & comparison
├── docs/
│   ├── PROJECT_REPORT.md      # Full project report
│   └── ARCHITECTURE.md        # System architecture diagrams
└── results/                   # Output plots and logs
```

## 🔬 How It Works

### FDIA Attack Model

For a power system with measurements `z = Hx + e`:

- **H**: Jacobian matrix (system topology)
- **x**: State vector (voltage angles)
- **e**: Measurement noise

A stealthy FDIA attack `a = Hc` modifies measurements such that:
- The residual `r = z - Hx̂` remains unchanged
- Traditional bad data detection fails

### Detection Approach

1. **Feature Extraction**: Statistical, temporal, and residual-based features
2. **SVM**: One-class learning on normal data, identifies outliers
3. **Autoencoder**: Learns to reconstruct normal patterns, high error = attack
4. **Fog Node**: Real-time detection with <100ms latency target

## 📊 Expected Results

| Metric | Target | Typical Result |
|--------|--------|----------------|
| Accuracy | >90% | 88-95% |
| Precision | >85% | 85-92% |
| Recall | >85% | 82-90% |
| F1-Score | >0.85 | 0.84-0.91 |
| False Alarm Rate | <12% | 5-12% |
| Detection Latency | <100ms | 15-50ms |

> 📚 **Full project report with mathematical model and FDIA bypass proof:** [docs/PROJECT_REPORT.md](docs/PROJECT_REPORT.md)

## 🏃 Running Experiments

```matlab
% Full pipeline
main

% Skip data generation (if already done)
main('skipDataGen')

% Only evaluate saved models
main('evalOnly')

% Run specific attack scenario
scenarios = attackScenarios();
[attackedData, labels, info] = runScenario('slowRamp', normalData, H, cfg);
```

## 📈 Output Visualizations

After running, check `results/` folder for:
- `confusion_matrix.png` - Classification results
- `roc_curve.png` - ROC with AUC
- `detection_timeline.png` - Predictions over time
- `latency_distribution.png` - Fog node latency stats
- `attack_comparison.png` - Normal vs attacked data

## 🔧 Configuration

Edit `config.m` to customize:

```matlab
cfg.busCase = 'case14';      % IEEE bus system
cfg.nSamples = 2000;         % Dataset size
cfg.attackRatio = 0.3;       % Attack percentage
cfg.windowSize = 20;         % Feature window
cfg.svm.nu = 0.05;           % SVM outlier fraction
cfg.ae.hiddenSize = [64, 32, 16, 32, 64];  % Autoencoder architecture
```

## 📚 References

1. Liu, Y., Ning, P., & Reiter, M. K. (2011). False data injection attacks against state estimation in electric power grids.
2. MATPOWER: https://matpower.org/
3. IEEE Bus Test Systems

## 👤 Author

**Vanshit Ahuja**  
February 2026

---

*"We detect intelligent false data injection attacks at the fog layer using anomaly detection on substation measurement data, reducing latency and improving grid security before data reaches the cloud."*
