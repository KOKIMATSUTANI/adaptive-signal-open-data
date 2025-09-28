
# CDDDQN: Constrained Deep Double Dueling Q-Network

A PyTorch implementation of CDDDQN for constrained reinforcement learning in grid environments.

## 🎯 Overview

This project implements a **Constrained Deep Double Dueling Q-Network (CDDDQN)** that learns to navigate a 5×5 grid world while avoiding hazards and maximizing rewards.

## 🏗️ Architecture

- **Environment**: 5×5 GridWorld with walls and hazards
- **Actions**: 4-directional movement (Up, Right, Down, Left)
- **State**: Normalized coordinates [0,1]
- **Reward**: +10 for goal, -1 per step
- **Cost**: +1 for hazard tiles

## 🧠 Key Features

- ✅ **Invalid Action Masking (IAM)** - Prevents invalid moves
- ✅ **Prioritized Experience Replay (PER)** - Efficient learning
- ✅ **Dueling Architecture** - Separate value and advantage streams
- ✅ **Double DQN** - Stable target network updates
- ✅ **Lagrangian Constraint** - Balances reward vs. cost optimization
- ✅ **EMA Cost Estimation** - Adaptive constraint handling

## 🚀 Quick Start

```bash
# Install dependencies
pip install torch matplotlib numpy

# Run training
python cdddqn_min.py
```

## 📊 Results

The algorithm learns to:
- Navigate from start (0,0) to goal (4,4)
- Avoid hazard tiles while minimizing path length
- Balance exploration vs. exploitation

## 🎮 Environment Layout

```
┌─────┬─────┬─────┬─────┬─────┐
│  S  │     │     │  H  │     │
├─────┼─────┼─────┼─────┼─────┤
│     │  W  │  W  │     │     │
├─────┼─────┼─────┼─────┼─────┤
│     │  W  │  H  │     │     │
├─────┼─────┼─────┼─────┼─────┤
│     │     │     │     │     │
├─────┼─────┼─────┼─────┼─────┤
│     │     │     │     │  G  │
└─────┴─────┴─────┴─────┴─────┘

S = Start, G = Goal, W = Wall, H = Hazard
```

## 📈 Training Output

- Episode Reward Plot
- Episode Cost Plot  
- Lambda & Cost Estimation Plot

## 🔧 Parameters

- **Training Steps**: 4,000
- **Batch Size**: 32
- **Learning Rate**: 1e-3
- **Gamma**: 0.99
- **Epsilon**: 0.9 → 0.05
- **Lambda LR**: 3e-3
- **Cost Budget**: 0.10

## 📚 References

- [Double DQN](https://arxiv.org/abs/1509.06461)
- [Dueling DQN](https://arxiv.org/abs/1511.06581)
- [Prioritized Experience Replay](https://arxiv.org/abs/1511.05952)

## 📄 License

MIT License - see LICENSE file for details.