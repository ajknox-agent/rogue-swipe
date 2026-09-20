#!/usr/bin/env python3
"""
Rogue Swipe — Combinatorics & Optimal Game Theory Calculator
============================================================
Calculates every possible game path, outcome distributions, turn length stats,
and the exact Minimax / Nash Equilibrium optimal strategy for any game state.

Completely reusable with configurable parameters, standalone pure-Python LP solver,
and both CLI and programmatic interfaces.
"""

import sys
import json
import time
import argparse
from typing import Dict, Tuple, List, Optional, Any


class SimplexZeroSumSolver:
    """Pure Python 2-phase Simplex solver for zero-sum matrix games."""

    @staticmethod
    def solve(matrix: List[List[float]]) -> Tuple[float, List[float], List[float]]:
        """
        Solves zero-sum matrix game for row player (max) and col player (min).
        Returns: (game_value, row_strategy_p, col_strategy_q)
        """
        m = len(matrix)
        n = len(matrix[0])
        min_val = min(min(row) for row in matrix)
        shift = abs(min_val) + 1.0 if min_val <= 0 else 0.0
        A = [[cell + shift for cell in row] for row in matrix]

        tableau = []
        for j in range(n):
            row = [A[i][j] for i in range(m)] + [1.0 if j == k else 0.0 for k in range(n)] + [1.0]
            tableau.append(row)
        obj = [-1.0] * m + [0.0] * n + [0.0]
        tableau.append(obj)

        while True:
            pivot_col = -1
            min_c = -1e-9
            for j in range(m + n):
                if tableau[n][j] < min_c:
                    min_c = tableau[n][j]
                    pivot_col = j
            if pivot_col == -1:
                break

            pivot_row = -1
            min_ratio = float('inf')
            for i in range(n):
                if tableau[i][pivot_col] > 1e-9:
                    ratio = tableau[i][m + n] / tableau[i][pivot_col]
                    if ratio < min_ratio:
                        min_ratio = ratio
                        pivot_row = i
            if pivot_row == -1:
                raise ValueError("Unbounded problem in linear program")

            p_val = tableau[pivot_row][pivot_col]
            tableau[pivot_row] = [x / p_val for x in tableau[pivot_row]]
            for i in range(n + 1):
                if i != pivot_row:
                    factor = tableau[i][pivot_col]
                    tableau[i] = [tableau[i][k] - factor * tableau[pivot_row][k] for k in range(m + n + 1)]

        x = [0.0] * m
        for j in range(m):
            col = [tableau[i][j] for i in range(n)]
            if abs(sum(col) - 1.0) < 1e-7 and max(col) < 1.0 + 1e-7 and min(col) > -1e-7:
                for i in range(n):
                    if abs(col[i] - 1.0) < 1e-7:
                        x[j] = tableau[i][m + n]

        sum_x = sum(x)
        if sum_x <= 1e-9:
            v = 0.0
            p = [1.0 / m] * m
        else:
            v = 1.0 / sum_x
            p = [xi * v for xi in x]

        # Extract dual variables (col player strategy)
        y = [tableau[n][m + j] for j in range(n)]
        q = [yj * v for yj in y]
        actual_value = v - shift
        return actual_value, p, q


class RogueSwipeGame:
    """Configurable rules and combat dynamics for Rogue Swipe."""

    def __init__(
        self,
        max_hp: int = 50,
        cannon_dmg: int = 15,
        cannon_vs_sail_dmg: int = 8,
        cannon_vs_board_cannon_loss: int = 25,
        cannon_vs_board_board_loss: int = 15,
        sail_ram_dmg: int = 15,
        board_clash_dmg: int = 10,
        max_sail_streak: int = 2,
        cannon_cooldown_turns: int = 2,  # 2 turns cooldown after fire (3 turns reload cycle)
    ):
        self.max_hp = max_hp
        self.cannon_dmg = cannon_dmg
        self.cannon_vs_sail_dmg = cannon_vs_sail_dmg
        self.cannon_vs_board_cannon_loss = cannon_vs_board_cannon_loss
        self.cannon_vs_board_board_loss = cannon_vs_board_board_loss
        self.sail_ram_dmg = sail_ram_dmg
        self.board_clash_dmg = board_clash_dmg
        self.max_sail_streak = max_sail_streak
        self.cannon_cooldown_turns = cannon_cooldown_turns

        # Combat outcome damage map: (p_act, e_act) -> (p_hp_loss, e_hp_loss)
        self.dmg_map: Dict[Tuple[str, str], Tuple[int, int]] = {
            ('C', 'C'): (self.cannon_dmg, self.cannon_dmg),
            ('C', 'S'): (0, self.cannon_vs_sail_dmg),
            ('C', 'B'): (self.cannon_vs_board_cannon_loss, self.cannon_vs_board_board_loss),
            ('S', 'C'): (self.cannon_vs_sail_dmg, 0),
            ('S', 'S'): (0, 0),
            ('S', 'B'): (0, self.sail_ram_dmg),
            ('B', 'C'): (self.cannon_vs_board_board_loss, self.cannon_vs_board_cannon_loss),
            ('B', 'S'): (self.sail_ram_dmg, 0),
            ('B', 'B'): (self.board_clash_dmg, self.board_clash_dmg),
        }

    def next_cannon_state(self, cd_state: Tuple[int, int], act: str) -> Tuple[int, int]:
        c1, c2 = cd_state
        if act == 'C':
            if c1 == 0:
                c1 = self.cannon_cooldown_turns + 1
            elif c2 == 0:
                c2 = self.cannon_cooldown_turns + 1
        nc1 = max(0, c1 - 1)
        nc2 = max(0, c2 - 1)
        return (min(nc1, nc2), max(nc1, nc2))

    def get_actions(self, cd_state: Tuple[int, int]) -> List[str]:
        c1, c2 = cd_state
        acts = ['S', 'B']
        if c1 == 0 or c2 == 0:
            acts.append('C')
        return sorted(acts)


class CombinatoricsCalculator:
    """Calculates all possible game histories and Nash equilibrium strategies."""

    def __init__(self, game: Optional[RogueSwipeGame] = None):
        self.game = game or RogueSwipeGame()
        self._path_memo: Dict[Tuple, Dict[str, int]] = {}
        self._swipe_memo: Dict[Tuple, Dict[str, int]] = {}
        self._turn_dist_memo: Dict[Tuple, Dict[int, int]] = {}
        self._value_memo: Dict[Tuple, float] = {}
        self._strategy_memo: Dict[Tuple, Tuple[List[str], List[float]]] = {}

    def count_action_games(self) -> Dict[str, Any]:
        """Counts every possible game path at the action level (Cannon, Sail, Board)."""
        self._path_memo.clear()
        t0 = time.time()
        res = self._count_action_paths(self.game.max_hp, self.game.max_hp, (0, 0), (0, 0), 0)
        elapsed = time.time() - t0

        return {
            'total_games': res['TOTAL'],
            'player_wins': res['WIN'],
            'losses': res['LOSS'],
            'mutual_sinkings': res['DRAW'],
            'win_rate_pct': (res['WIN'] / res['TOTAL']) * 100.0 if res['TOTAL'] else 0.0,
            'draw_rate_pct': (res['DRAW'] / res['TOTAL']) * 100.0 if res['TOTAL'] else 0.0,
            'reachable_states': len(self._path_memo),
            'calculation_time_sec': round(elapsed, 4),
        }

    def count_swipe_games(self) -> Dict[str, Any]:
        """Counts every possible game path at the physical swipe level (Port, Starboard, Sail, Board)."""
        self._swipe_memo.clear()
        t0 = time.time()
        res = self._count_swipe_paths(self.game.max_hp, self.game.max_hp, (0, 0), (0, 0), 0)
        elapsed = time.time() - t0

        return {
            'total_swipe_games': res['TOTAL'],
            'player_wins': res['WIN'],
            'losses': res['LOSS'],
            'mutual_sinkings': res['DRAW'],
            'win_rate_pct': (res['WIN'] / res['TOTAL']) * 100.0 if res['TOTAL'] else 0.0,
            'draw_rate_pct': (res['DRAW'] / res['TOTAL']) * 100.0 if res['TOTAL'] else 0.0,
            'calculation_time_sec': round(elapsed, 4),
        }

    def calculate_turn_distribution(self) -> Dict[str, Any]:
        """Calculates turn length distributions across all possible games."""
        self._turn_dist_memo.clear()
        t0 = time.time()
        dist = self._count_turns(self.game.max_hp, self.game.max_hp, (0, 0), (0, 0), 0)
        elapsed = time.time() - t0

        total_games = sum(dist.values())
        avg_turns = sum(turns * count for turns, count in dist.items()) / total_games if total_games else 0.0
        min_turns = min(dist.keys()) if dist else 0
        max_turns = max(dist.keys()) if dist else 0

        return {
            'min_turns': min_turns,
            'max_turns': max_turns,
            'average_turns': round(avg_turns, 2),
            'distribution_by_turns': {str(k): v for k, v in sorted(dist.items())},
            'calculation_time_sec': round(elapsed, 4),
        }

    def solve_optimal_strategy(self) -> Dict[str, Any]:
        """Computes the full Minimax / Nash Equilibrium optimal strategy at all states."""
        self._value_memo.clear()
        self._strategy_memo.clear()
        t0 = time.time()
        start_val = self._evaluate_value(self.game.max_hp, self.game.max_hp, (0, 0), (0, 0), 0)
        elapsed = time.time() - t0

        key = (self.game.max_hp, self.game.max_hp, (0, 0), (0, 0), 0)
        acts, probs = self._strategy_memo.get(key, ([], []))
        action_names = {'C': 'Cannon', 'S': 'Sail', 'B': 'Board'}
        opening_strat = {action_names[a]: round(p * 100.0, 2) for a, p in zip(acts, probs)}

        return {
            'game_value_at_start': round(start_val, 4),
            'opening_strategy_pct': opening_strat,
            'total_states_evaluated': len(self._value_memo),
            'calculation_time_sec': round(elapsed, 4),
        }

    def query_state(
        self,
        player_hp: int,
        enemy_hp: int,
        player_cd: Tuple[int, int] = (0, 0),
        enemy_cd: Tuple[int, int] = (0, 0),
        streak: int = 0
    ) -> Dict[str, Any]:
        """Queries the optimal strategy and win value for an arbitrary game state."""
        p_cd_norm = (min(player_cd), max(player_cd))
        e_cd_norm = (min(enemy_cd), max(enemy_cd))
        val = self._evaluate_value(player_hp, enemy_hp, p_cd_norm, e_cd_norm, streak)
        key = (player_hp, enemy_hp, p_cd_norm, e_cd_norm, streak)
        acts, probs = self._strategy_memo.get(key, ([], []))
        action_names = {'C': 'Cannon', 'S': 'Sail', 'B': 'Board'}

        strat = {action_names[a]: round(p * 100.0, 2) for a, p in zip(acts, probs)}
        # Split Cannon into Port/Starboard if both are ready
        ready_cannons = sum(1 for c in player_cd if c == 0)
        if 'Cannon' in strat:
            if ready_cannons == 2:
                strat['Port Cannon (Left)'] = round(strat['Cannon'] / 2.0, 2)
                strat['Starboard Cannon (Right)'] = round(strat['Cannon'] / 2.0, 2)
            elif ready_cannons == 1:
                strat['Ready Cannon'] = strat['Cannon']

        return {
            'state': {
                'player_hp': player_hp,
                'enemy_hp': enemy_hp,
                'player_cannons': player_cd,
                'enemy_cannons': enemy_cd,
                'sail_streak': streak,
            },
            'state_value': round(val, 4),
            'advantage': 'FAVORABLE' if val > 0.05 else ('DISADVANTAGE' if val < -0.05 else 'EVEN'),
            'optimal_strategy_pct': strat,
        }

    # --- Internal Recursive Methods (with Memoization) ---

    def _count_action_paths(self, p_hp: int, e_hp: int, p_cd: Tuple[int, int], e_cd: Tuple[int, int], streak: int) -> Dict[str, int]:
        if p_hp <= 0 or e_hp <= 0:
            outcome = 'DRAW' if (p_hp <= 0 and e_hp <= 0) else ('WIN' if e_hp <= 0 else 'LOSS')
            res = {'WIN': 0, 'LOSS': 0, 'DRAW': 0, 'TOTAL': 1}
            res[outcome] = 1
            return res

        key = (p_hp, e_hp, p_cd, e_cd, streak)
        if key in self._path_memo:
            return self._path_memo[key]

        p_acts = self.game.get_actions(p_cd)
        e_acts = self.game.get_actions(e_cd)
        totals = {'WIN': 0, 'LOSS': 0, 'DRAW': 0, 'TOTAL': 0}

        for pa in p_acts:
            for ea in e_acts:
                if pa == 'S' and ea == 'S':
                    if streak >= self.game.max_sail_streak:
                        continue
                    n_streak = streak + 1
                else:
                    n_streak = 0

                p_loss, e_loss = self.game.dmg_map[(pa, ea)]
                np_hp = max(0, p_hp - p_loss)
                ne_hp = max(0, e_hp - e_loss)
                np_cd = self.game.next_cannon_state(p_cd, pa)
                ne_cd = self.game.next_cannon_state(e_cd, ea)

                sub = self._count_action_paths(np_hp, ne_hp, np_cd, ne_cd, n_streak)
                for k in totals:
                    totals[k] += sub[k]

        self._path_memo[key] = totals
        return totals

    def _count_swipe_paths(self, p_hp: int, e_hp: int, p_cd: Tuple[int, int], e_cd: Tuple[int, int], streak: int) -> Dict[str, int]:
        if p_hp <= 0 or e_hp <= 0:
            outcome = 'DRAW' if (p_hp <= 0 and e_hp <= 0) else ('WIN' if e_hp <= 0 else 'LOSS')
            res = {'WIN': 0, 'LOSS': 0, 'DRAW': 0, 'TOTAL': 1}
            res[outcome] = 1
            return res

        key = (p_hp, e_hp, p_cd, e_cd, streak)
        if key in self._swipe_memo:
            return self._swipe_memo[key]

        # Multiplicity of actions at the swipe level
        p_c_choices = sum(1 for c in p_cd if c == 0)
        e_c_choices = sum(1 for c in e_cd if c == 0)

        p_acts = [('S', 1), ('B', 1)]
        if p_c_choices > 0:
            p_acts.append(('C', p_c_choices))

        e_acts = [('S', 1), ('B', 1)]
        if e_c_choices > 0:
            e_acts.append(('C', e_c_choices))

        totals = {'WIN': 0, 'LOSS': 0, 'DRAW': 0, 'TOTAL': 0}

        for pa, p_mult in p_acts:
            for ea, e_mult in e_acts:
                if pa == 'S' and ea == 'S':
                    if streak >= self.game.max_sail_streak:
                        continue
                    n_streak = streak + 1
                else:
                    n_streak = 0

                p_loss, e_loss = self.game.dmg_map[(pa, ea)]
                np_hp = max(0, p_hp - p_loss)
                ne_hp = max(0, e_hp - e_loss)
                np_cd = self.game.next_cannon_state(p_cd, pa)
                ne_cd = self.game.next_cannon_state(e_cd, ea)

                sub = self._count_swipe_paths(np_hp, ne_hp, np_cd, ne_cd, n_streak)
                comb_mult = p_mult * e_mult
                for k in totals:
                    totals[k] += sub[k] * comb_mult

        self._swipe_memo[key] = totals
        return totals

    def _count_turns(self, p_hp: int, e_hp: int, p_cd: Tuple[int, int], e_cd: Tuple[int, int], streak: int) -> Dict[int, int]:
        if p_hp <= 0 or e_hp <= 0:
            return {0: 1}

        key = (p_hp, e_hp, p_cd, e_cd, streak)
        if key in self._turn_dist_memo:
            return self._turn_dist_memo[key]

        p_acts = self.game.get_actions(p_cd)
        e_acts = self.game.get_actions(e_cd)
        dist: Dict[int, int] = {}

        for pa in p_acts:
            for ea in e_acts:
                if pa == 'S' and ea == 'S':
                    if streak >= self.game.max_sail_streak:
                        continue
                    n_streak = streak + 1
                else:
                    n_streak = 0

                p_loss, e_loss = self.game.dmg_map[(pa, ea)]
                np_hp = max(0, p_hp - p_loss)
                ne_hp = max(0, e_hp - e_loss)
                np_cd = self.game.next_cannon_state(p_cd, pa)
                ne_cd = self.game.next_cannon_state(e_cd, ea)

                sub = self._count_turns(np_hp, ne_hp, np_cd, ne_cd, n_streak)
                for t, count in sub.items():
                    dist[t + 1] = dist.get(t + 1, 0) + count

        self._turn_dist_memo[key] = dist
        return dist

    def _evaluate_value(self, p_hp: int, e_hp: int, p_cd: Tuple[int, int], e_cd: Tuple[int, int], streak: int) -> float:
        if p_hp <= 0 or e_hp <= 0:
            if p_hp <= 0 and e_hp <= 0:
                return 0.0
            return 1.0 if e_hp <= 0 else -1.0

        key = (p_hp, e_hp, p_cd, e_cd, streak)
        if key in self._value_memo:
            return self._value_memo[key]

        p_acts = self.game.get_actions(p_cd)
        e_acts = self.game.get_actions(e_cd)

        matrix = []
        for pa in p_acts:
            row = []
            for ea in e_acts:
                if pa == 'S' and ea == 'S' and streak >= self.game.max_sail_streak:
                    # Pruned streak treated as draw
                    row.append(0.0)
                    continue

                n_streak = streak + 1 if (pa == 'S' and ea == 'S') else 0
                p_loss, e_loss = self.game.dmg_map[(pa, ea)]
                np_hp = max(0, p_hp - p_loss)
                ne_hp = max(0, e_hp - e_loss)
                np_cd = self.game.next_cannon_state(p_cd, pa)
                ne_cd = self.game.next_cannon_state(e_cd, ea)

                sub_v = self._evaluate_value(np_hp, ne_hp, np_cd, ne_cd, n_streak)
                row.append(sub_v)
            matrix.append(row)

        val, p_strat, _ = SimplexZeroSumSolver.solve(matrix)
        self._value_memo[key] = val
        self._strategy_memo[key] = (p_acts, p_strat)
        return val


def main():
    parser = argparse.ArgumentParser(description="Rogue Swipe Combinatorics & Game Theory Calculator")
    parser.add_argument("--hp", type=int, default=50, help="Initial Max HP (default: 50)")
    parser.add_argument("--max-sail-streak", type=int, default=2, help="Max double-sail streak (default: 2)")
    parser.add_argument("--json", action="store_true", help="Output raw JSON format")
    parser.add_argument(
        "--query",
        nargs=5,
        type=int,
        metavar=("P_HP", "E_HP", "P_READY_CANNONS", "E_READY_CANNONS", "SAIL_STREAK"),
        help="Query optimal strategy for specific state",
    )
    args = parser.parse_args()

    game = RogueSwipeGame(max_hp=args.hp, max_sail_streak=args.max_sail_streak)
    calc = CombinatoricsCalculator(game)

    if args.query:
        p_hp, e_hp, p_ready, e_ready, streak = args.query
        p_cd = (0, 0) if p_ready == 2 else ((0, 1) if p_ready == 1 else (1, 2))
        e_cd = (0, 0) if e_ready == 2 else ((0, 1) if e_ready == 1 else (1, 2))
        res = calc.query_state(p_hp, e_hp, p_cd, e_cd, streak)
        if args.json:
            print(json.dumps(res, indent=2))
        else:
            print("\n" + "=" * 50)
            print("  ROGUE SWIPE — STATE STRATEGY QUERY")
            print("=" * 50)
            print(f"State: Player HP={p_hp}, Enemy HP={e_hp}, Player Ready Cannons={p_ready}, Enemy Ready Cannons={e_ready}")
            print(f"Game State Value: {res['state_value']:.4f} ({res['advantage']})")
            print("Optimal Strategy:")
            for act, pct in res['optimal_strategy_pct'].items():
                print(f"  • {act:<25} : {pct:>6.2f}%")
            print("=" * 50)
        return

    # Full combinatorics and game theory calculation
    action_res = calc.count_action_games()
    swipe_res = calc.count_swipe_games()
    turn_res = calc.calculate_turn_distribution()
    strat_res = calc.solve_optimal_strategy()

    output = {
        'game_settings': {
            'max_hp': game.max_hp,
            'cannon_cooldown_cycle': 3,
            'max_sail_streak': game.max_sail_streak,
            'cannon_damage': game.cannon_dmg,
            'cannon_vs_sail_damage': game.cannon_vs_sail_dmg,
            'cannon_vs_board_cannon_damage': game.cannon_vs_board_cannon_loss,
            'cannon_vs_board_board_damage': game.cannon_vs_board_board_loss,
            'sail_ram_damage': game.sail_ram_dmg,
            'board_clash_damage': game.board_clash_dmg,
        },
        'action_level_combinatorics': action_res,
        'swipe_level_combinatorics': swipe_res,
        'turn_length_statistics': turn_res,
        'game_theory_optimal_strategy': strat_res,
    }

    if args.json:
        print(json.dumps(output, indent=2))
    else:
        print("\n" + "=" * 60)
        print("    ROGUE SWIPE — COMBINATORICS & OPTIMAL STRATEGY REPORT")
        print("=" * 60)
        print("\n1. GAME TREE COMBINATORICS:")
        print(f"  • Total Action-Level Games  : {action_res['total_games']:,}")
        print(f"    - Player Wins             : {action_res['player_wins']:,} ({action_res['win_rate_pct']:.2f}%)")
        print(f"    - Enemy Wins              : {action_res['losses']:,} ({action_res['win_rate_pct']:.2f}%)")
        print(f"    - Mutual Sinking (Draws)  : {action_res['mutual_sinkings']:,} ({action_res['draw_rate_pct']:.2f}%)")
        print(f"  • Total Physical Swipe Games: {swipe_res['total_swipe_games']:,} (~{swipe_res['total_swipe_games']/1e12:.2f} Trillion)")
        print(f"  • Total Reachable States    : {action_res['reachable_states']:,}")
        print(f"  • Game Computation Time     : {action_res['calculation_time_sec']}s")

        print("\n2. TURN LENGTH & PACING:")
        print(f"  • Minimum Possible Game     : {turn_res['min_turns']} turns")
        print(f"  • Maximum Possible Game     : {turn_res['max_turns']} turns")
        print(f"  • Average Game Duration     : {turn_res['average_turns']} turns")
        print("  • Distribution by turns:")
        for t, count in turn_res['distribution_by_turns'].items():
            pct = (count / action_res['total_games']) * 100.0
            bar = "█" * int(pct / 2.5)
            print(f"    Turn {t:>2}: {count:>12,} ({pct:>5.2f}%) {bar}")

        print("\n3. NASH EQUILIBRIUM & OPTIMAL STRATEGY:")
        print(f"  • Game Value at Start       : {strat_res['game_value_at_start']:.4f} (Even)")
        print("  • Optimal Opening Move Probabilities:")
        for act, pct in strat_res['opening_strategy_pct'].items():
            print(f"    - {act:<10}: {pct:>6.2f}%")

        print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
