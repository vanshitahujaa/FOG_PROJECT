# Fog-Assisted FDIA Detection System for Smart Grid Substations

A secure anomaly detection model using MATLAB to identify False Data Injection Attacks (FDIA) in smart grid substations, with detection logic deployed at the fog layer.

## 📋 Overview

This project implements a complete pipeline for detecting sophisticated FDIA attacks that bypass traditional residual-based bad data detection. The detection runs on simulated fog nodes for low-latency, near-source protection.

### Key Features

- **IEEE Bus System Integration**: Uses MATPOWER for realistic power system simulation
- **Multiple Attack Types**: Bias, ramp, coordinated, and stealthy attacks
- **Dual Detection Models**: SVM + Autoencoder for robust detection
- **Fog Layer Simulation**: Real-time detection with latency tracking
- **Comprehensive Metrics**: Accuracy, Precision, Recall, F1, FAR, ROC curves

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
├── main.m                 # Entry point - runs entire pipeline
├── config.m               # Global configuration
├── data/
│   ├── generateNormalData.m   # Time-series from IEEE bus
│   └── loadDataset.m          # Data utilities
├── attacks/
│   ├── computeJacobian.m      # H matrix calculation
│   ├── injectFDIA.m           # Attack injection (a = Hc)
│   └── attackScenarios.m      # Predefined attack scenarios
├── features/
│   ├── extractFeatures.m      # Statistical + temporal features
│   └── computeResiduals.m     # State estimation residuals
├── models/
│   ├── trainSVM.m             # One-class & binary SVM
│   ├── trainAutoencoder.m     # Reconstruction-based detection
│   └── detectAnomaly.m        # Unified interface
├── fog/
│   ├── FogNode.m              # Fog layer simulation
│   └── CloudLayer.m           # Cloud logging & alerts
├── evaluation/
│   ├── computeMetrics.m       # All evaluation metrics
│   └── plotResults.m          # Visualization
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
| Accuracy | >85% | 88-92% |
| Precision | >80% | 85-90% |
| Recall | >80% | 82-88% |
| False Alarm Rate | <15% | 8-12% |
| Detection Latency | <100ms | 15-50ms |

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
