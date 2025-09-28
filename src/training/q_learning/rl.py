import random
from typing import Dict, List, Tuple


class GridWorld:
    """
    極小のGridWorld環境。
    - 状態: (row, col)
    - 行動: 0=上, 1=右, 2=下, 3=左
    - 壁: 進入不可
    - ゴール/穴: 終端状態
    """

    ACTIONS = [0, 1, 2, 3]
    DELTA = {0: (-1, 0), 1: (0, 1), 2: (1, 0), 3: (0, -1)}

    def __init__(
        self,
        h: int = 4,
        w: int = 4,
        start: Tuple[int, int] = (0, 0),
        goal: Tuple[int, int] = (3, 3),
        walls: List[Tuple[int, int]] = None,
        pits: Dict[Tuple[int, int], float] = None,
        step_reward: float = -0.01,
        goal_reward: float = 1.0,
    ) -> None:
        self.h = h
        self.w = w
        self.start = start
        self.goal = goal
        self.walls = set(walls or [(1, 1)])
        self.pits = pits or {(2, 2): -0.7}
        self.step_reward = step_reward
        self.goal_reward = goal_reward
        self.state = start

    def reset(self) -> Tuple[int, int]:
        self.state = self.start
        return self.state

    def is_terminal(self, s: Tuple[int, int]) -> bool:
        return s == self.goal or s in self.pits

    def step(self, a: int) -> Tuple[Tuple[int, int], float, bool]:
        if self.is_terminal(self.state):
            return self.state, 0.0, True
        dr, dc = self.DELTA[a]
        nr = min(max(self.state[0] + dr, 0), self.h - 1)
        nc = min(max(self.state[1] + dc, 0), self.w - 1)
        ns = (nr, nc)
        if ns in self.walls:
            ns = self.state
        r = self.step_reward
        done = False
        if ns == self.goal:
            r = self.goal_reward
            done = True
        elif ns in self.pits:
            r = self.pits[ns]
            done = True
        self.state = ns
        return ns, r, done


def epsilon_greedy(q: Dict[Tuple[int, int], List[float]], s: Tuple[int, int], eps: float) -> int:
    if random.random() < eps:
        return random.choice(GridWorld.ACTIONS)
    vals = q.get(s)
    if vals is None:
        return random.choice(GridWorld.ACTIONS)
    m = max(vals)
    best = [a for a, v in enumerate(vals) if v == m]
    return random.choice(best)


def train(
    env: GridWorld,
    episodes: int = 600,
    max_steps: int = 100,
    alpha: float = 0.3,
    gamma: float = 0.98,
    eps_start: float = 1.0,
    eps_end: float = 0.05,
    eps_decay_steps: int = 400,
) -> Dict[Tuple[int, int], List[float]]:
    q: Dict[Tuple[int, int], List[float]] = {}

    def get_qs(s: Tuple[int, int]) -> List[float]:
        if s not in q:
            q[s] = [0.0, 0.0, 0.0, 0.0]
        return q[s]

    for ep in range(episodes):
        eps = max(eps_end, eps_start - (eps_start - eps_end) * (ep / max(1, eps_decay_steps)))
        s = env.reset()
        for _ in range(max_steps):
            a = epsilon_greedy(q, s, eps)
            ns, r, done = env.step(a)
            cur = get_qs(s)
            nxt = get_qs(ns)
            target = r + (0.0 if env.is_terminal(ns) else gamma * max(nxt))
            cur[a] += alpha * (target - cur[a])
            s = ns
            if done:
                break
    return q


def greedy_policy_action(q: Dict[Tuple[int, int], List[float]], s: Tuple[int, int]) -> int:
    vals = q.get(s, [0.0, 0.0, 0.0, 0.0])
    return int(max(range(4), key=lambda a: vals[a]))


def render_policy(env: GridWorld, q: Dict[Tuple[int, int], List[float]]) -> str:
    arrows = {0: "^", 1: ">", 2: "v", 3: "<"}
    lines: List[str] = []
    for r in range(env.h):
        row: List[str] = []
        for c in range(env.w):
            s = (r, c)
            if s in env.walls:
                row.append("#")
            elif s == env.goal:
                row.append("G")
            elif s in env.pits:
                row.append("X")
            else:
                a = greedy_policy_action(q, s)
                row.append(arrows[a])
        lines.append(" ".join(row))
    return "\n".join(lines)


def greedy_rollout(env: GridWorld, q: Dict[Tuple[int, int], List[float]], max_steps: int = 50) -> List[Tuple[int, int]]:
    s = env.reset()
    tr: List[Tuple[int, int]] = [s]
    for _ in range(max_steps):
        a = greedy_policy_action(q, s)
        ns, _, done = env.step(a)
        tr.append(ns)
        s = ns
        if done:
            break
    return tr


def main() -> None:
    random.seed(0)
    env = GridWorld()
    q = train(env)
    print("Policy (greedy):")
    print(render_policy(env, q))
    traj = greedy_rollout(env, q)
    print("\nGreedy trajectory:")
    print(traj)


if __name__ == "__main__":
    main()


