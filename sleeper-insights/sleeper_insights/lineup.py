"""Lineup slot eligibility, league-specific scoring, and lineup optimization."""

from __future__ import annotations

SLOT_ELIGIBILITY: dict[str, set[str]] = {
    "QB": {"QB"},
    "RB": {"RB"},
    "WR": {"WR"},
    "TE": {"TE"},
    "K": {"K"},
    "DEF": {"DEF"},
    "DL": {"DL", "DE", "DT"},
    "LB": {"LB"},
    "DB": {"DB", "CB", "S"},
    "FLEX": {"RB", "WR", "TE"},
    "WRRB_FLEX": {"RB", "WR"},
    "REC_FLEX": {"WR", "TE"},
    "SUPER_FLEX": {"QB", "RB", "WR", "TE"},
    "IDP_FLEX": {"DL", "DE", "DT", "LB", "DB", "CB", "S"},
}
NON_STARTING_SLOTS = {"BN", "IR", "TAXI"}

# Injury designations that mean the player will not play this week.
INACTIVE_STATUSES = {"Out", "IR", "PUP", "Sus", "Suspended", "NA", "COV", "DNR"}
RISKY_STATUSES = {"Questionable", "Doubtful"}

# Sleeper scores defense points-allowed in buckets, but projections carry the raw number.
_PTS_ALLOW_BUCKETS = [
    (0, 0, "pts_allow_0"),
    (1, 6, "pts_allow_1_6"),
    (7, 13, "pts_allow_7_13"),
    (14, 20, "pts_allow_14_20"),
    (21, 27, "pts_allow_21_27"),
    (28, 34, "pts_allow_28_34"),
    (35, 10_000, "pts_allow_35p"),
]


def starting_slots(roster_positions: list[str]) -> list[str]:
    return [s for s in roster_positions if s not in NON_STARTING_SLOTS]


def eligible(slot: str, positions: set[str]) -> bool:
    return bool(SLOT_ELIGIBILITY.get(slot, {slot}) & positions)


def score(stats: dict | None, scoring: dict) -> float:
    """Fantasy points for a stat line under the league's scoring settings."""
    if not stats:
        return 0.0
    pts = sum(v * scoring[k] for k, v in stats.items()
              if k in scoring and isinstance(v, (int, float)))
    if "pts_allow" in stats and not any(key in stats for _, _, key in _PTS_ALLOW_BUCKETS):
        allowed = round(stats["pts_allow"])
        for lo, hi, key in _PTS_ALLOW_BUCKETS:
            if lo <= allowed <= hi:
                pts += scoring.get(key, 0)
                break
    if pts == 0:
        # Stat line uses keys the league doesn't score; fall back to Sleeper's precomputed totals.
        rec = scoring.get("rec", 0)
        key = "pts_ppr" if rec >= 1 else "pts_half_ppr" if rec >= 0.5 else "pts_std"
        pts = stats.get(key) or 0
    return round(pts, 2)


def optimal_lineup(slots: list[str], candidates: dict[str, tuple[set[str], float]]) -> list[tuple[str, str | None, float]]:
    """Best lineup for the given starting slots.

    candidates maps player_id -> (fantasy positions, points). Slots are filled most
    restrictive first (QB before FLEX before SUPER_FLEX) with the highest scorer
    still available, which is optimal for Sleeper's nested slot types.
    Returns [(slot, player_id or None, points)] in the original slot order.
    """
    order = sorted(range(len(slots)), key=lambda i: (len(SLOT_ELIGIBILITY.get(slots[i], {slots[i]})), i))
    used: set[str] = set()
    filled: list[tuple[str, str | None, float]] = [(s, None, 0.0) for s in slots]
    for i in order:
        slot = slots[i]
        best = max(
            (pid for pid, (pos, _) in candidates.items() if pid not in used and eligible(slot, pos)),
            key=lambda pid: candidates[pid][1],
            default=None,
        )
        if best is not None:
            used.add(best)
            filled[i] = (slot, best, candidates[best][1])
    return filled
