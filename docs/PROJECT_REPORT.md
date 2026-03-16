# Fog-Assisted Anomaly Detection Model for Identifying False Data Injection Attacks in Smart Grid Substations

**Author:** Vanshit Ahuja  
**Date:** March 2026

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Objectives](#2-objectives)
3. [System Architecture](#3-system-architecture)
4. [Methodology](#4-methodology)
5. [Mathematical Model — State Estimation & FDIA](#5-mathematical-model--state-estimation--fdia)
6. [Algorithms & Models](#6-algorithms--models)
7. [Implementation Plan (MATLAB)](#7-implementation-plan-matlab)
8. [Evaluation Metrics](#8-evaluation-metrics)
9. [Expected Results](#9-expected-results)
10. [Future Enhancements](#10-future-enhancements)

---

## 1. Problem Statement

Modern smart grids rely heavily on digital communication and real-time monitoring systems such as SCADA (Supervisory Control and Data Acquisition) and PMUs (Phasor Measurement Units). While this improves efficiency and automation, it also introduces cyber vulnerabilities.

One of the most dangerous attacks is the **False Data Injection Attack (FDIA)**, where an attacker manipulates measurement data sent from substations to control centers.

If successful, these attacks can:

- **Bypass traditional bad-data detectors** — the attack vector is crafted to be invisible to residual-based detection
- **Mislead grid state estimation** — operators see a false picture of the grid
- **Trigger incorrect control decisions** — wrong dispatch, unnecessary load shedding
- **Cause power outages or equipment damage** — cascading failures from false alarms or hidden faults

To mitigate this threat, this project proposes a **fog-assisted anomaly detection framework** deployed near substations to detect suspicious measurements before they propagate through the grid control network.

The detection model is developed in MATLAB and tested using standard power-system datasets such as **IEEE Bus Test Systems** via MATPOWER.

---

## 2. Objectives

The main objectives of this project are:

1. **Develop a secure anomaly detection model** capable of identifying False Data Injection Attacks in smart grid measurements
2. **Implement fog computing architecture** to enable low-latency local detection near substations
3. **Use multiple machine learning algorithms** (SVM, Autoencoder, Random Forest, KNN, PCA) and compare their detection performance
4. **Simulate realistic attack scenarios** on IEEE bus test systems, including stealthy attacks that bypass traditional BDD
5. **Evaluate detection performance** using standard metrics (Accuracy, Precision, Recall, F1, FAR, AUC-ROC)

---

## 3. System Architecture

The proposed architecture consists of three layers.

### 3.1 Data Acquisition Layer

This layer collects measurement data from the smart grid infrastructure.

**Components:**
- Phasor Measurement Units (PMUs)
- SCADA sensors
- Intelligent Electronic Devices (IEDs)

**Measured parameters:**

| Parameter | Symbol | Unit |
|-----------|--------|------|
| Voltage magnitude | V | p.u. |
| Voltage angle | θ | degrees |
| Active power | P | MW |
| Reactive power | Q | MVAr |
| Frequency | f | Hz |
| Line power flows | Pf, Qf | MW, MVAr |

### 3.2 Fog Computing Layer

Fog nodes are deployed near substations to process data locally.

**Functions:**
- Data preprocessing and buffering
- Feature extraction (statistical, temporal, residual)
- Anomaly detection using trained ML models
- Alert generation and severity classification

**Benefits:**
- Reduced detection latency (<100 ms target)
- Early attack detection before data reaches control center
- Lower network congestion — only alerts are forwarded

### 3.3 Cloud / Control Center Layer

The central control center performs:
- Grid state estimation
- Long-term analytics and model retraining
- Storage of monitoring data and alert history
- System-wide control decisions

Fog nodes communicate alerts to the control center only when anomalies are detected.

```
┌─────────────────────────────────────────────────────────┐
│                   CLOUD LAYER                           │
│   State Estimation │ Analytics │ Storage │ Control      │
└───────────────────────────┬─────────────────────────────┘
                            │ Alerts Only
┌───────────────────────────┴─────────────────────────────┐
│                   FOG LAYER                             │
│   Buffer → Feature Extraction → ML Detection → Alert   │
│                    (<100ms latency)                     │
└───────────────────────────┬─────────────────────────────┘
                            │ Raw Measurements
┌───────────────────────────┴─────────────────────────────┐
│              DATA ACQUISITION LAYER                     │
│          PMU │ SCADA │ IED Sensors                      │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Methodology

The proposed detection framework follows these stages.

### Step 1: Power System Dataset Preparation

Standard IEEE bus test systems are used for simulation via MATPOWER.

| System | Buses | Branches | States | Measurements |
|--------|-------|----------|--------|--------------|
| IEEE-14 | 14 | 20 | 13 | 33 |
| IEEE-30 | 30 | 41 | 29 | 70 |
| IEEE-118 | 118 | 186 | 117 | 303 |

The dataset includes time-series measurements with realistic load variation:
- Daily sinusoidal load pattern
- Random Gaussian fluctuations (2% noise)
- Occasional load spikes (5% probability)

Each sample contains: `[V₁...Vₙ, θ₁...θₙ, P₁...Pₙ, Q₁...Qₙ, Pf₁...Pfₘ, Qf₁...Qfₘ]`

### Step 2: Attack Simulation

False Data Injection Attacks are simulated by manipulating measurement vectors using the mathematical model `a = Hc`.

**Attack types implemented:**

| Attack Type | Description | Difficulty |
|-------------|-------------|------------|
| Bias | Constant offset on target buses | Easy |
| Ramp | Gradually increasing deviation | Medium |
| Coordinated | Multi-sensor correlated attack | Hard |
| Random Stealthy | Low-magnitude within noise envelope | Very Hard |
| Targeted | Specific state estimation error | Medium |
| Scaling | Proportional measurement change | Easy |
| Replay | Historical data injection | Medium |

**Advanced scenario categories:**
- **Economic attacks** — manipulate LMP, cause uneconomic dispatch
- **Physical attacks** — trigger voltage collapse, line overload
- **Stealth attacks** — noise-masked, intermittent, slow ramp
- **Cascading attacks** — N-1 violation hiding, protection miscoordination

### Step 3: Data Preprocessing

Collected measurements undergo preprocessing:
- Z-score normalization per feature
- NaN/Inf value handling
- Missing value imputation

### Step 4: Feature Extraction

Features are extracted using sliding windows of configurable size.

**Statistical features** (per variable, per window):
- Mean, Standard deviation, Max, Min
- Skewness, Kurtosis, Range

**Temporal features** (per variable, per window):
- Mean absolute first difference
- First difference standard deviation
- Linear trend (regression slope)
- Autocorrelation (lag-1)
- Rate of change (end − start)

**Residual features** (per window, requires H matrix):
- Residual norm ‖r‖
- Maximum absolute residual
- Normalized residual ‖r‖/‖z‖
- State vector norm ‖x̂‖

### Step 5: Machine Learning Detection

Five ML models are trained and compared:

| Model | Type | Approach |
|-------|------|----------|
| Support Vector Machine | Supervised/One-class | Kernel-based classification boundary |
| Autoencoder | Unsupervised | Reconstruction error anomaly detection |
| Random Forest | Supervised | Ensemble of decision trees with voting |
| K-Nearest Neighbors | Supervised | Distance-based classification |
| PCA | Unsupervised | Hotelling's T² + Q-statistic (SPE) |

The best performing model (by F1-Score) is deployed in fog nodes.

### Step 6: Fog Deployment Simulation

```
Sensor Data
     ↓
Fog Node Buffer
     ↓
Feature Extraction (window)
     ↓
ML Detection Model
     ↓
┌────┴────┐
│ Normal  │ → Log only
│ Attack  │ → Alert + Cloud sync
└─────────┘
```

Fog nodes process measurements locally. Detection latency is tracked per sample and must stay below 100ms budget.

---

## 5. Mathematical Model — State Estimation & FDIA

This section presents the formal mathematical foundation of state estimation in power systems and proves how FDIA bypasses traditional bad data detection. **This is the core theoretical contribution.**

### 5.1 DC State Estimation

In a power system with _n_ buses and _m_ measurements, the measurement model is:

```
z = Hx + e
```

Where:
- **z** ∈ ℝᵐ — measurement vector (voltages, power flows, injections)
- **H** ∈ ℝᵐˣⁿ — Jacobian matrix encoding system topology
- **x** ∈ ℝⁿ — state vector (voltage angles at non-reference buses)
- **e** ∈ ℝᵐ — measurement noise, assumed Gaussian with covariance **W⁻¹**

The **Weighted Least Squares (WLS)** state estimator minimizes:

```
J(x) = (z - Hx)ᵀ W (z - Hx)
```

Setting ∂J/∂x = 0 gives the optimal state estimate:

```
x̂ = (HᵀWH)⁻¹ HᵀW z
```

### 5.2 Residual-Based Bad Data Detection

The measurement residual is:

```
r = z - Hx̂
```

Traditional Bad Data Detection (BDD) uses the **χ² test**:

```
J(x̂) = rᵀWr
```

If J(x̂) > χ²(m−n, α), the measurement set fails the test and is flagged as containing bad data.

The **Largest Normalized Residual (LNR)** test additionally identifies which specific measurement is suspicious:

```
rₙ = r / √diag(S)
```

where **S = W − WH(HᵀWH)⁻¹HᵀW** is the residual sensitivity matrix.

### 5.3 FDIA Attack Model

An attacker injects a false data vector **a** into the measurements:

```
z_a = z + a
```

If the attacker chooses **a = Hc** for some arbitrary vector **c** ∈ ℝⁿ, then:

### 5.4 Proof: FDIA Bypasses BDD

**Claim:** If a = Hc, the residual r is unchanged, and BDD cannot detect the attack.

**Proof:**

The state estimate under attack:

```
x̂_a = (HᵀWH)⁻¹ HᵀW z_a
     = (HᵀWH)⁻¹ HᵀW (z + Hc)
     = (HᵀWH)⁻¹ HᵀW z + (HᵀWH)⁻¹ HᵀW Hc
     = x̂ + c
```

The residual under attack:

```
r_a = z_a − H x̂_a
    = (z + Hc) − H(x̂ + c)
    = z + Hc − Hx̂ − Hc
    = z − Hx̂
    = r
```

**Therefore r_a = r.** The residual is identical to the normal case.

Since J(x̂_a) = r_aᵀ W r_a = rᵀ W r = J(x̂), the χ² test produces the same statistic. **The attack is completely invisible to traditional BDD.** ∎

### 5.5 Constructing the Attack

The Jacobian matrix **H** is constructed from the DC power flow model:

For branch (i,j) with reactance xᵢⱼ:
```
P_ij = (θ_i − θ_j) / x_ij
```

**H** consists of:
- **Bus injection rows:** H_bus = B(non-ref, non-ref) where B = Im(Y_bus)
- **Branch flow rows:** H_branch(k, i) = 1/x_ij, H_branch(k, j) = −1/x_ij

The attacker needs knowledge of H (network topology) to construct a = Hc. The vector **c** controls which states are corrupted and by how much.

### 5.6 Why ML-Based Detection Works

Since r_a = r, **any detection method that relies only on the residual will fail.** However, ML-based detection uses features beyond the residual:

1. **Statistical features** — FDIA changes the distribution of measurements (mean, variance, skewness) across time windows, even though individual residuals are unchanged
2. **Temporal features** — attack onset creates temporal discontinuities (changes in trend, autocorrelation) that don't match natural load variation patterns
3. **Multi-dimensional patterns** — ML models learn the joint distribution of all features. Even if each measurement individually passes BDD, the combination may violate learned normal patterns

This is why this project uses a **feature engineering + ML** approach instead of relying on traditional BDD.

---

## 6. Algorithms & Models

### 6.1 Support Vector Machine (SVM)

**One-Class SVM** — trained on normal data only. Learns a boundary enclosing normal data in feature space. Points outside the boundary are flagged as anomalies.

**Binary SVM** — trained on labeled normal + attack data. Uses RBF kernel with configurable kernel scale and box constraint. Handles class imbalance via cost-sensitive weighting.

```
Decision: f(x) = sign(Σ αᵢ yᵢ K(xᵢ, x) + b)
Kernel:   K(xᵢ, xⱼ) = exp(-‖xᵢ − xⱼ‖² / (2σ²))
```

### 6.2 Autoencoder

Neural network trained to reconstruct normal data. Architecture: encoder → bottleneck → decoder.

```
Architecture: input → 64 → 32 → 16 → 32 → 64 → input
Loss: L = ‖x − x̂‖²  (Mean Squared Error)
Anomaly threshold: μ_error + 3σ_error
```

High reconstruction error indicates the input deviates from learned normal patterns → attack detected.

**Fallback:** If Deep Learning Toolbox is unavailable, uses PCA-based linear autoencoder.

### 6.3 Random Forest

Ensemble of 100 decision trees using bagging (TreeBagger). Each tree is trained on a bootstrap sample with √p random features at each split.

- Cost-sensitive learning for class imbalance
- Out-of-bag (OOB) error estimation
- Feature importance ranking via OOB permutation

### 6.4 K-Nearest Neighbors (KNN)

Distance-based classification using k=5 nearest neighbors with Euclidean distance.

- Squared-inverse distance weighting — closer neighbors have more influence
- Empirical prior probabilities
- 5-fold cross-validation error estimate

### 6.5 PCA Anomaly Detection

Linear projection onto principal subspace retaining 95% variance.

**Hotelling's T² statistic** — measures variation within the principal subspace:
```
T² = Σ (scoreᵢ / √λᵢ)²
```

**Q-statistic (SPE)** — measures variation outside the principal subspace:
```
Q = ‖x − x̂‖² = ‖x − PP'x‖²
```

Combined score with threshold at mean + 3σ from training data.

---

## 7. Implementation Plan (MATLAB)

### 7.1 Required Toolboxes

| Toolbox | Purpose | Required |
|---------|---------|----------|
| MATPOWER | Power flow simulation, bus cases | Yes |
| Statistics and Machine Learning | SVM, KNN, RF, PCA, metrics | Yes |
| Deep Learning | Autoencoder neural network | Optional |

### 7.2 Project Structure

```
FOG_PROJECT/
├── main.m                          # Entry point — 5-model pipeline
├── quickStart.m                    # Quick demo with reduced dataset
├── config.m                        # Global configuration
├── setupMatpower.m                 # MATPOWER installation helper
├── data/
│   ├── generateNormalData.m        # IEEE bus time-series generation
│   └── loadDataset.m              # Data loading utilities
├── attacks/
│   ├── computeJacobian.m          # H matrix (system topology)
│   ├── injectFDIA.m               # Attack injection (a = Hc)
│   ├── attackScenarios.m          # Basic attack scenarios
│   └── advancedAttackScenarios.m  # 10 advanced scenarios
├── features/
│   ├── extractFeatures.m          # Statistical + temporal + residual
│   └── computeResiduals.m        # State estimation residuals
├── models/
│   ├── trainSVM.m                 # One-class & binary SVM
│   ├── trainAutoencoder.m         # Reconstruction-based detection
│   ├── trainRandomForest.m        # TreeBagger ensemble
│   ├── trainKNN.m                 # K-nearest neighbors
│   ├── trainPCA.m                 # PCA anomaly detection (T² + Q)
│   └── detectAnomaly.m            # Unified detection interface
├── fog/
│   ├── FogNode.m                  # Fog layer simulation class
│   └── CloudLayer.m               # Cloud logging & alerts
├── evaluation/
│   ├── computeMetrics.m           # All evaluation metrics
│   └── plotResults.m              # Visualization & comparison plots
├── docs/
│   ├── PROJECT_REPORT.md          # This document
│   └── ARCHITECTURE.md            # System architecture diagrams
└── results/                        # Output plots and logs
```

### 7.3 Typical Workflow

```matlab
% 1. Install MATPOWER
addpath('/path/to/matpower');
install_matpower;

% 2. Navigate to project
cd('/path/to/FOG_PROJECT');

% 3. Run full 5-model pipeline
main

% 4. Or quick demo
quickStart

% 5. Run specific attack scenarios
scenarios = advancedAttackScenarios();
[data, labels] = executeScenario(scenarios.slowRamp, normalData, H, cfg);
```

---

## 8. Evaluation Metrics

Model performance is evaluated using:

| Metric | Formula | Meaning |
|--------|---------|---------|
| Accuracy | (TP+TN) / N | Overall detection correctness |
| Precision | TP / (TP+FP) | Attack detection reliability |
| Recall | TP / (TP+FN) | Ability to detect all attacks |
| F1-Score | 2·Prec·Rec / (Prec+Rec) | Balance of precision and recall |
| False Alarm Rate | FP / (FP+TN) | False alarms generated |
| AUC-ROC | Area under ROC curve | Discrimination ability |
| MCC | (TP·TN−FP·FN) / √denom | Balanced measure for imbalanced data |

**Detection latency** is measured per-sample at the fog node to verify <100ms budget compliance.

---

## 9. Expected Results

### 9.1 Target Performance

| Metric | Target | Typical Range |
|--------|--------|---------------|
| Accuracy | >90% | 88–95% |
| Precision | >85% | 85–92% |
| Recall | >85% | 82–90% |
| F1-Score | >0.85 | 0.84–0.91 |
| False Alarm Rate | <12% | 5–12% |
| Detection Latency | <100ms | 15–50ms |

### 9.2 Expected Model Comparison

| Model | Strength | Expected Ranking |
|-------|----------|-----------------|
| Random Forest | Best overall generalization | 1st–2nd |
| SVM (Binary) | Strong boundary learning | 1st–2nd |
| Autoencoder | Best on unseen attack types | 2nd–3rd |
| KNN | Baseline, interpretable | 3rd–4th |
| PCA | Fast, linear, good for subtle anomalies | 4th–5th |

### 9.3 Attack Detection Difficulty

| Category | Expected Recall |
|----------|----------------|
| Bias attacks | >95% |
| Ramp attacks | 80–90% |
| Coordinated attacks | 75–85% |
| Stealthy attacks | 65–80% |

---

## 10. Future Enhancements

Possible improvements include:

1. **Deep learning models** — LSTM/GRU for temporal sequence modeling, Transformers for attention-based detection
2. **Graph Neural Networks** — model power grid topology directly using GCN/GAT for topology-aware detection
3. **Federated Learning** — multiple fog nodes train models locally and share weights without sharing raw data
4. **Blockchain-based secure data validation** — tamper-proof measurement logging
5. **Explainable AI** — SHAP/LIME for identifying which buses triggered the alarm
6. **Active defense response** — automatic sensor isolation and robust state estimation fallback
7. **Real-time streaming simulation** — live detection visualization with updating ROC curves
8. **Larger bus systems** — scalability testing on IEEE-118 and IEEE-300

---

## References

1. Liu, Y., Ning, P., & Reiter, M. K. (2011). *False data injection attacks against state estimation in electric power grids.* ACM Transactions on Information and System Security, 14(1), 1–33.
2. MATPOWER: https://matpower.org/
3. IEEE Bus Test Systems — Power Systems Test Case Archive
4. Deng, R., Xiao, G., Lu, R., Liang, H., & Vasilakos, A. V. (2017). *False data injection on state estimation in power systems — Attacks, impacts, and defense: A survey.* IEEE Transactions on Industrial Informatics.
5. Esmalifalak, M., Liu, L., Nguyen, N., Zheng, R., & Han, Z. (2014). *Detecting stealthy false data injection using machine learning in smart grid.* IEEE Systems Journal.

---

**Vanshit Ahuja** — March 2026
