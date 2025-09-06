# -*- coding: utf-8 -*-
"""
CDDDQN minimal example (PyTorch)
- Continuous states (normalized coords), discrete actions (U,R,D,L)
- Invalid Action Masking (IAM)
- Prioritized Experience Replay (PER, proportional)
- Dueling reward head + cost head
- Double DQN target
- Lagrangian constraint with lambda update
- Matplotlib plots: reward, cost, lambda & estimated cost

Usage:
  pip install torch matplotlib numpy
  python cdddqn_min.py
"""

import math, random, time
from dataclasses import dataclass
from typing import List, Optional
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
import matplotlib.pyplot as plt

# -------------------------
# Small GridWorld with hazards (cost) + walls + IAM
# -------------------------
class GridWorld:
    """
    2D grid (H x W).
    State: (row, col) normalized to [0,1] -> continuous
    Actions: 0=up, 1=right, 2=down, 3=left
    IAM: invalid actions (off-grid or into wall) are masked
    Reward: -1 per step, +10 at goal
    Cost: +1 on hazard tiles
    """
    def __init__(self, H=5, W=5, max_steps=35):
        self.H, self.W = H, W
        self.start = (0, 0)
        self.goal = (H-1, W-1)
        self.max_steps = max_steps
        # a few walls & hazards
        self.walls = {(1,1), (1,2), (2,1)}
        self.hazards = {(0,3), (2,2)}
        self.reset()

    def reset(self):
        self.pos = self.start
        self.t = 0
        return self._obs()

    def _obs(self):
        r, c = self.pos
        return np.array([r/(self.H-1), c/(self.W-1)], dtype=np.float32)

    def valid_actions(self, pos=None):
        if pos is None:
            pos = self.pos
        r, c = pos
        acts = []
        for a, (dr, dc) in enumerate([(-1,0),(0,1),(1,0),(0,-1)]):
            nr, nc = r+dr, c+dc
            if 0 <= nr < self.H and 0 <= nc < self.W and (nr, nc) not in self.walls:
                acts.append(a)
        return acts

    def step(self, a):
        self.t += 1
        r, c = self.pos
        dr, dc = [(-1,0),(0,1),(1,0),(0,-1)][a]
        nr, nc = r+dr, c+dc
        if not (0 <= nr < self.H and 0 <= nc < self.W) or (nr, nc) in self.walls:
            nr, nc = r, c  # invalid -> stay (IAM側で基本弾く)
        self.pos = (nr, nc)

        done = (self.pos == self.goal) or (self.t >= self.max_steps)
        reward = 10.0 if self.pos == self.goal else -1.0
        cost = 1.0 if self.pos in self.hazards else 0.0
        return self._obs(), reward, cost, done, {}

def valid_mask_from_env(env, n_actions=4):
    m = np.zeros(n_actions, dtype=np.float32)
    m[env.valid_actions()] = 1.0
    return m

# -------------------------
# PER (proportional)
# -------------------------
@dataclass
class Transition:
    s: np.ndarray
    a: int
    r: float
    c: float
    s2: np.ndarray
    done: float
    mask: np.ndarray
    mask2: np.ndarray

class PERBuffer:
    def __init__(self, capacity: int, alpha: float=0.6, beta: float=0.4, seed: int=0):
        self.capacity = capacity
        self.alpha = alpha
        self.beta = beta
        self.data: List[Optional[Transition]] = [None]*capacity
        self.priorities = np.zeros(capacity, dtype=np.float32)
        self.pos = 0
        self.size = 0
        self.rng = np.random.default_rng(seed)

    def add(self, tr: Transition, priority: float):
        i = self.pos
        self.data[i] = tr
        self.priorities[i] = max(priority, 1e-6)
        self.pos = (self.pos + 1) % self.capacity
        self.size = min(self.size + 1, self.capacity)

    def sample(self, batch_size: int):
        pr = self.priorities[:self.size] ** self.alpha
        probs = pr / pr.sum()
        idxs = self.rng.choice(self.size, size=batch_size, p=probs, replace=self.size < batch_size)
        N = self.size
        weights = (N * probs[idxs]) ** (-self.beta)
        weights = weights / weights.max()
        batch = [self.data[i] for i in idxs]
        return idxs, batch, weights.astype(np.float32)

    def update_priorities(self, idxs, new_p):
        for i, p in zip(idxs, new_p):
            self.priorities[i] = float(max(p, 1e-6))

# -------------------------
# Network: Dueling Q for reward + cost head
# -------------------------
class CDDDQN(nn.Module):
    def __init__(self, obs_dim: int, n_actions: int):
        super().__init__()
        self.feat = nn.Sequential(
            nn.Linear(obs_dim, 64), nn.ReLU(),
            nn.Linear(64, 64), nn.ReLU(),
        )
        # Reward head (Dueling)
        self.val_r = nn.Linear(64, 1)
        self.adv_r = nn.Linear(64, n_actions)
        # Cost head
        self.q_c = nn.Linear(64, n_actions)

    def forward(self, x):
        z = self.feat(x)
        adv_r = self.adv_r(z)
        q_r = self.val_r(z) + adv_r - adv_r.mean(dim=1, keepdim=True)
        q_c = self.q_c(z)
        return q_r, q_c

def mask_argmax(q_values: torch.Tensor, mask: torch.Tensor):
    q = q_values.clone()
    q[mask < 0.5] = -1e9
    return q.argmax(dim=-1)

# -------------------------
# Main training
# -------------------------
def train():
    device = "cuda" if torch.cuda.is_available() else "cpu"
    rng = np.random.default_rng(42)
    torch.manual_seed(42); random.seed(42); np.random.seed(42)

    env = GridWorld(H=5, W=5, max_steps=35)
    obs_dim, n_actions = 2, 4

    net = CDDDQN(obs_dim, n_actions).to(device)
    tgt = CDDDQN(obs_dim, n_actions).to(device)
    tgt.load_state_dict(net.state_dict())

    optim = torch.optim.Adam(net.parameters(), lr=1e-3)
    huber = nn.SmoothL1Loss(reduction="none")

    buffer = PERBuffer(capacity=4000, alpha=0.6, beta=0.4, seed=123)

    gamma = 0.99
    batch_size = 32
    start_steps = 300
    train_steps = 4000        # CPUで数十秒〜1分台
    target_update_interval = 250
    eps_start, eps_end, eps_decay = 0.9, 0.05, 3000

    # Lagrangian parameters
    lambda_coef = torch.tensor(0.1, device=device)
    lambda_lr = 3e-3
    cost_budget = 0.10
    ema_cost = 0.0
    ema_alpha = 0.03

    def epsilon_by_step(t):
        return eps_end + (eps_start - eps_end) * math.exp(-1.0 * t / eps_decay)

    def obs_to_t(o):  # [1,obs_dim]
        return torch.tensor(o, dtype=torch.float32, device=device).unsqueeze(0)

    # Logging
    ep_rewards, ep_costs = [], []
    lambda_hist, cost_est_hist = [], []

    s = env.reset()
    mask = valid_mask_from_env(env, n_actions)
    ep_r, ep_c, episodes = 0.0, 0.0, 0

    t0 = time.time()
    for t in range(1, train_steps+1):
        eps = epsilon_by_step(t)
        # ε-greedy with IAM
        if random.random() < eps or t < start_steps:
            valid_actions = np.where(mask > 0.5)[0]
            a = int(random.choice(valid_actions))
        else:
            with torch.no_grad():
                q_r, q_c = net(obs_to_t(s))
                q_L = q_r - lambda_coef * q_c
                m_t = torch.tensor(mask, device=device).unsqueeze(0)
                a = int(mask_argmax(q_L, m_t).item())

        s2, r, c, done, _ = env.step(a)
        mask2 = valid_mask_from_env(env, n_actions)

        buffer.add(Transition(s, a, r, c, s2, float(done), mask, mask2), priority=1.0)
        s, mask = s2, mask2
        ep_r += r; ep_c += c

        # learn
        if t > start_steps and buffer.size >= batch_size:
            idxs, batch, weights = buffer.sample(batch_size)
            s_b  = torch.tensor(np.stack([b.s for b in batch]), dtype=torch.float32, device=device)
            a_b  = torch.tensor([b.a for b in batch], dtype=torch.long, device=device).unsqueeze(1)
            r_b  = torch.tensor([b.r for b in batch], dtype=torch.float32, device=device).unsqueeze(1)
            c_b  = torch.tensor([b.c for b in batch], dtype=torch.float32, device=device).unsqueeze(1)
            s2_b = torch.tensor(np.stack([b.s2 for b in batch]), dtype=torch.float32, device=device)
            d_b  = torch.tensor([b.done for b in batch], dtype=torch.float32, device=device).unsqueeze(1)
            m2_b = torch.tensor(np.stack([b.mask2 for b in batch]), dtype=torch.float32, device=device)
            w_b  = torch.tensor(weights, dtype=torch.float32, device=device).unsqueeze(1)

            q_r, q_c = net(s_b)
            q_r_sa = q_r.gather(1, a_b)
            q_c_sa = q_c.gather(1, a_b)

            with torch.no_grad():
                # selection with IAM on online net
                q_r2_online, q_c2_online = net(s2_b)
                qL2 = q_r2_online - lambda_coef * q_c2_online
                qL2[m2_b < 0.5] = -1e9
                a2 = qL2.argmax(dim=1, keepdim=True)

                # evaluation on target net
                q_r2_tgt, q_c2_tgt = tgt(s2_b)
                q_r_next = q_r2_tgt.gather(1, a2)
                q_c_next = q_c2_tgt.gather(1, a2)

                y_r = r_b + (1 - d_b) * gamma * q_r_next
                y_c = c_b + (1 - d_b) * gamma * q_c_next

            loss_r = (huber(q_r_sa, y_r) * w_b).mean()
            loss_c = (huber(q_c_sa, y_c) * w_b).mean()
            loss = loss_r + lambda_coef * loss_c

            optim.zero_grad()
            loss.backward()
            nn.utils.clip_grad_norm_(net.parameters(), 5.0)
            optim.step()

            # update PER priorities
            with torch.no_grad():
                td_r = (q_r_sa - y_r).abs().squeeze(1).detach().cpu().numpy()
                td_c = (q_c_sa - y_c).abs().squeeze(1).detach().cpu().numpy()
                new_p = td_r + td_c + 1e-5
                buffer.update_priorities(idxs, new_p)

                # lambda update (EMA-based cost estimate)
                ema_cost = (1 - ema_alpha) * ema_cost + ema_alpha * float(c_b.mean().item())
                new_lambda = max(0.0, float(lambda_coef.item()) + lambda_lr * (ema_cost - cost_budget))
                lambda_coef = torch.tensor(new_lambda, device=device)

                lambda_hist.append(lambda_coef.item())
                cost_est_hist.append(ema_cost)

        if done:
            ep_rewards.append(ep_r)
            ep_costs.append(ep_c)
            s = env.reset()
            mask = valid_mask_from_env(env, n_actions)
            ep_r, ep_c = 0.0, 0.0
            episodes += 1

        if t % target_update_interval == 0:
            tgt.load_state_dict(net.state_dict())

    dt = time.time() - t0
    print(f"Finished {train_steps} steps, {episodes} episodes in {dt:.1f}s")

    # ---- Plots (1 chart per figure, no explicit colors) ----
    plt.figure()
    plt.title("Episode Reward")
    plt.plot(ep_rewards)
    plt.xlabel("Episode")
    plt.ylabel("Total Reward")
    plt.show()

    plt.figure()
    plt.title("Episode Cost")
    plt.plot(ep_costs)
    plt.xlabel("Episode")
    plt.ylabel("Total Cost")
    plt.show()

    plt.figure()
    plt.title("Lambda and Estimated Cost (EMA)")
    plt.plot(lambda_hist, label="lambda")
    plt.plot(cost_est_hist, label="estimated cost")
    plt.xlabel("Training updates")
    plt.ylabel("Value")
    plt.legend()
    plt.show()

if __name__ == "__main__":
    train()
