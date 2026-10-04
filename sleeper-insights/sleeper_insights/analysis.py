"""League analysis: standings, power rankings, matchup previews, start/sit, waivers."""

from __future__ import annotations

import math
import statistics
from collections import defaultdict
from dataclasses import dataclass, field

from .api import SleeperClient
from .lineup import (
    INACTIVE_STATUSES,
    RISKY_STATUSES,
    SLOT_ELIGIBILITY,
    eligible,
    optimal_lineup,
    score,
    starting_slots,
)


@dataclass
class Team:
    roster_id: int
    owner_id: str | None
    name: str
    manager: str
    wins: int = 0
    losses: int = 0
    ties: int = 0
    points_for: float = 0.0
    points_against: float = 0.0
    players: list[str] = field(default_factory=list)
    starters: list[str] = field(default_factory=list)
    reserve: list[str] = field(default_factory=list)

    @property
    def record(self) -> str:
        return f"{self.wins}-{self.losses}" + (f"-{self.ties}" if self.ties else "")


@dataclass
class League:
    league: dict
    state: dict
    teams: dict[int, Team]
    players: dict[str, dict]
    matchups: dict[int, list[dict]]  # week -> raw matchup rows, completed weeks only
    current_week: int | None

    @property
    def name(self) -> str:
        return self.league.get("name", "League")

    @property
    def season(self) -> str:
        return str(self.league.get("season"))

    @property
    def scoring(self) -> dict:
        return self.league.get("scoring_settings") or {}

    @property
    def slots(self) -> list[str]:
        return starting_slots(self.league.get("roster_positions") or [])

    def positions(self, pid: str) -> set[str]:
        p = self.players.get(pid) or {}
        return set(p.get("fantasy_positions") or ([p["position"]] if p.get("position") else []))

    def player_name(self, pid: str | None) -> str:
        if not pid or pid == "0":
            return "(empty)"
        p = self.players.get(pid) or {}
        if p.get("position") == "DEF" or (not p and pid.isalpha()):
            return f"{pid} D/ST"
        name = p.get("full_name") or f"{p.get('first_name', '')} {p.get('last_name', '')}".strip()
        return name or pid

    def player_label(self, pid: str | None) -> str:
        if not pid or pid == "0":
            return "(empty)"
        p = self.players.get(pid) or {}
        pos = p.get("position") or "?"
        team = p.get("team") or "FA"
        return f"{self.player_name(pid)} ({pos}, {team})"

    def positions_for_slot(self, slot: str) -> set[str]:
        return SLOT_ELIGIBILITY.get(slot, {slot})

    def injury(self, pid: str) -> str | None:
        return (self.players.get(pid) or {}).get("injury_status")

    def rostered(self) -> set[str]:
        return {pid for t in self.teams.values() for pid in t.players}

    def find_team(self, query: str) -> Team:
        q = query.strip().lower()
        if q.isdigit() and int(q) in self.teams:
            return self.teams[int(q)]
        exact = [t for t in self.teams.values() if q in (t.name.lower(), t.manager.lower())]
        partial = [t for t in self.teams.values() if q in t.name.lower() or q in t.manager.lower()]
        matches = exact or partial
        if len(matches) == 1:
            return matches[0]
        names = ", ".join(f"{t.name} ({t.manager})" for t in self.teams.values())
        if not matches:
            raise ValueError(f"No team matches {query!r}. Teams: {names}")
        raise ValueError(f"{query!r} matches several teams; be more specific. Teams: {names}")


def load_league(client: SleeperClient, league_id: str, completed_through: int | None = None) -> League:
    league = client.league(league_id)
    state = client.state()
    users = {u["user_id"]: u for u in client.users(league_id)}
    rosters = client.rosters(league_id)
    players = client.players()

    in_season = str(state.get("season")) == str(league.get("season")) and state.get("season_type") == "regular"
    current_week = (int(state.get("display_week") or state.get("week") or 0) or None) if in_season else None
    if completed_through is None:
        settings = league.get("settings") or {}
        completed_through = settings.get("last_scored_leg")
        if completed_through is None:
            completed_through = (current_week - 1) if current_week else settings.get("playoff_week_start", 15) - 1

    teams: dict[int, Team] = {}
    for r in rosters:
        user = users.get(r.get("owner_id")) or {}
        s = r.get("settings") or {}
        manager = user.get("display_name") or f"Team {r['roster_id']}"
        teams[r["roster_id"]] = Team(
            roster_id=r["roster_id"],
            owner_id=r.get("owner_id"),
            name=(user.get("metadata") or {}).get("team_name") or manager,
            manager=manager,
            wins=s.get("wins", 0),
            losses=s.get("losses", 0),
            ties=s.get("ties", 0),
            points_for=s.get("fpts", 0) + s.get("fpts_decimal", 0) / 100,
            points_against=s.get("fpts_against", 0) + s.get("fpts_against_decimal", 0) / 100,
            players=list(r.get("players") or []),
            starters=list(r.get("starters") or []),
            reserve=list(r.get("reserve") or []),
        )

    matchups = {}
    for week in range(1, (completed_through or 0) + 1):
        rows = client.matchups(league_id, week)
        if any(row.get("points") for row in rows):
            matchups[week] = rows

    return League(league, state, teams, players, matchups, current_week)


# --- standings & power rankings -------------------------------------------


@dataclass
class TeamStats:
    team: Team
    weekly: list[float]
    allplay_wins: int
    allplay_losses: int
    expected_wins: float
    actual_wins: float
    optimal_points: float
    actual_points: float

    @property
    def avg(self) -> float:
        return statistics.mean(self.weekly) if self.weekly else 0.0

    @property
    def recent(self) -> float:
        return statistics.mean(self.weekly[-3:]) if self.weekly else 0.0

    @property
    def stdev(self) -> float:
        return statistics.pstdev(self.weekly) if len(self.weekly) > 1 else 0.0

    @property
    def allplay_pct(self) -> float:
        games = self.allplay_wins + self.allplay_losses
        return self.allplay_wins / games if games else 0.0

    @property
    def luck(self) -> float:
        return self.actual_wins - self.expected_wins

    @property
    def efficiency(self) -> float:
        return self.actual_points / self.optimal_points if self.optimal_points else 0.0


def standings(lg: League) -> list[Team]:
    return sorted(lg.teams.values(), key=lambda t: (-t.wins, t.losses, -t.points_for))


def team_stats(lg: League) -> list[TeamStats]:
    weekly: dict[int, list[float]] = defaultdict(list)
    ap_w: dict[int, int] = defaultdict(int)
    ap_l: dict[int, int] = defaultdict(int)
    exp_w: dict[int, float] = defaultdict(float)
    act_w: dict[int, float] = defaultdict(float)
    opt_pts: dict[int, float] = defaultdict(float)
    act_pts: dict[int, float] = defaultdict(float)

    for week, rows in sorted(lg.matchups.items()):
        rows = [r for r in rows if r.get("roster_id") in lg.teams]
        scores = {r["roster_id"]: float(r.get("points") or 0) for r in rows}
        n = len(scores)
        for rid, pts in scores.items():
            weekly[rid].append(pts)
            beat = sum(1 for o, op in scores.items() if o != rid and pts > op)
            tied = sum(1 for o, op in scores.items() if o != rid and pts == op)
            ap_w[rid] += beat
            ap_l[rid] += n - 1 - beat - tied
            if n > 1:
                exp_w[rid] += (beat + tied / 2) / (n - 1)

        by_matchup: dict[int, list[int]] = defaultdict(list)
        for r in rows:
            if r.get("matchup_id") is not None:
                by_matchup[r["matchup_id"]].append(r["roster_id"])
        for pair in by_matchup.values():
            if len(pair) != 2:
                continue
            a, b = pair
            if scores[a] == scores[b]:
                act_w[a] += 0.5
                act_w[b] += 0.5
            else:
                act_w[a if scores[a] > scores[b] else b] += 1

        for r in rows:
            pp = r.get("players_points") or {}
            cands = {pid: (lg.positions(pid), float(p)) for pid, p in pp.items()}
            opt = sum(p for _, _, p in optimal_lineup(lg.slots, cands))
            opt_pts[r["roster_id"]] += max(opt, float(r.get("points") or 0))
            act_pts[r["roster_id"]] += float(r.get("points") or 0)

    return [
        TeamStats(t, weekly[rid], ap_w[rid], ap_l[rid], exp_w[rid], act_w[rid], opt_pts[rid], act_pts[rid])
        for rid, t in lg.teams.items()
    ]


def power_rankings(lg: League) -> list[tuple[float, TeamStats]]:
    """Blend of all-play win %, season scoring average, and last-3-week form (0-100)."""
    stats = team_stats(lg)
    max_avg = max((s.avg for s in stats), default=0) or 1
    max_recent = max((s.recent for s in stats), default=0) or 1
    ranked = [
        (round(100 * (0.40 * s.allplay_pct + 0.35 * s.avg / max_avg + 0.25 * s.recent / max_recent), 1), s)
        for s in stats
    ]
    return sorted(ranked, key=lambda x: -x[0])


# --- weekly projections -----------------------------------------------------


@dataclass
class PlayerProjection:
    pid: str
    points: float
    raw_points: float
    status: str | None
    note: str = ""


def project_players(lg: League, projections: dict[str, dict], pids) -> dict[str, PlayerProjection]:
    out = {}
    for pid in pids:
        raw = score(projections.get(pid), lg.scoring)
        status = lg.injury(pid)
        p = lg.players.get(pid) or {}
        note = ""
        if status in INACTIVE_STATUSES:
            note = f"{status} - do not start"
        elif status in RISKY_STATUSES:
            note = f"{status} - monitor before kickoff"
        elif pid not in projections and p.get("position") != "DEF":
            note = "no projection (bye or inactive?)"
        elif not p.get("team") and p.get("position") != "DEF":
            note = "free agent in NFL"
        pts = 0.0 if status in INACTIVE_STATUSES else raw
        out[pid] = PlayerProjection(pid, pts, raw, status, note)
    return out


@dataclass
class StartSitReport:
    team: Team
    week: int
    current: list[tuple[str, str | None, float]]
    optimal: list[tuple[str, str | None, float]]
    swaps: list[tuple[str, str, float]]  # (start, sit, gain)
    flags: list[tuple[str, str]]
    bench: list[tuple[str, float]]

    @property
    def current_total(self) -> float:
        return round(sum(p for _, _, p in self.current), 2)

    @property
    def optimal_total(self) -> float:
        return round(sum(p for _, _, p in self.optimal), 2)


def current_starters(lg: League, team: Team, week_matchups: list[dict]) -> list[str]:
    for row in week_matchups:
        if row.get("roster_id") == team.roster_id and row.get("starters"):
            return list(row["starters"])
    return list(team.starters)


def start_sit(lg: League, team: Team, week: int, projections: dict[str, dict],
              week_matchups: list[dict] | None = None) -> StartSitReport:
    active = [pid for pid in team.players if pid not in set(team.reserve)]
    proj = project_players(lg, projections, active)
    slots = lg.slots
    starters = current_starters(lg, team, week_matchups or [])

    current = []
    for i, slot in enumerate(slots):
        pid = starters[i] if i < len(starters) and starters[i] not in (None, "0") else None
        current.append((slot, pid, proj[pid].points if pid in proj else 0.0))

    cands = {pid: (lg.positions(pid), proj[pid].points) for pid in active}
    optimal = optimal_lineup(slots, cands)

    cur_set = {pid for _, pid, _ in current if pid}
    opt_set = {pid for _, pid, _ in optimal if pid}
    to_start = sorted(opt_set - cur_set, key=lambda p: -proj[p].points)
    to_sit = sorted(cur_set - opt_set, key=lambda p: proj[p].points if p in proj else 0)
    swaps = []
    for s_in in to_start:
        # Pair each newcomer with the weakest outgoing starter at the same position,
        # else one sharing a slot type (e.g. FLEX), else whoever is left.
        same_pos = [s for s in to_sit if lg.positions(s) & lg.positions(s_in)]
        shared_slot = [s for s in to_sit if any(eligible(slot, lg.positions(s_in)) and eligible(slot, lg.positions(s))
                                                for slot in slots)]
        match = (same_pos or shared_slot or to_sit or [None])[0]
        if match:
            to_sit.remove(match)
            gain = proj[s_in].points - (proj[match].points if match in proj else 0)
            swaps.append((s_in, match, round(gain, 2)))
        else:
            swaps.append((s_in, "(empty slot)", round(proj[s_in].points, 2)))

    flags = [(pid, proj[pid].note) for pid in sorted(cur_set | opt_set) if pid in proj and proj[pid].note]
    bench = sorted(((pid, proj[pid].points) for pid in active if pid not in opt_set), key=lambda x: -x[1])
    return StartSitReport(team, week, current, optimal, swaps, flags, bench)


def win_probability(proj_a: float, proj_b: float) -> float:
    """Normal approximation; each team's weekly score varies by roughly 20% of its projection."""
    sd = math.hypot(0.2 * proj_a, 0.2 * proj_b) or 1
    return 0.5 * (1 + math.erf((proj_a - proj_b) / (sd * math.sqrt(2))))


def matchup_preview(lg: League, week: int, projections: dict[str, dict], week_matchups: list[dict]):
    """[(team_a, set_a, opt_a, team_b, set_b, opt_b, p_a_wins)] for the week's head-to-head games."""
    by_id: dict[int, list[int]] = defaultdict(list)
    for r in week_matchups:
        if r.get("matchup_id") is not None and r.get("roster_id") in lg.teams:
            by_id[r["matchup_id"]].append(r["roster_id"])
    games = []
    for mid in sorted(by_id):
        if len(by_id[mid]) != 2:
            continue
        sides = []
        for rid in by_id[mid]:
            rep = start_sit(lg, lg.teams[rid], week, projections, week_matchups)
            sides.append((lg.teams[rid], rep.current_total, rep.optimal_total))
        (ta, sa, oa), (tb, sb, ob) = sides
        games.append((ta, sa, oa, tb, sb, ob, win_probability(sa or oa, sb or ob)))
    return games


def waiver_targets(lg: League, team: Team, projections: dict[str, dict], trending: list[dict],
                   limit: int = 10) -> list[tuple[str, float, float, int]]:
    """Free agents who out-project the team's weakest starter at their position.

    Returns [(player_id, projection, upgrade over team's worst eligible starter, trending adds)].
    """
    rostered = lg.rostered()
    slot_positions = set().union(*(lg.positions_for_slot(s) for s in lg.slots)) if lg.slots else set()
    trend = {t["player_id"]: t.get("count", 0) for t in trending}
    rep = start_sit(lg, team, 0, projections)
    starter_pts = [(pid, pts) for _, pid, pts in rep.optimal if pid]

    out = []
    for pid, stats in projections.items():
        if pid in rostered:
            continue
        p = lg.players.get(pid) or {}
        pos = lg.positions(pid)
        if not pos & slot_positions or (not p.get("team") and p.get("position") != "DEF"):
            continue
        if p.get("injury_status") in INACTIVE_STATUSES:
            continue
        pts = score(stats, lg.scoring)
        if pts <= 0:
            continue
        comparable = [sp for spid, sp in starter_pts if lg.positions(spid) & pos]
        floor = min(comparable) if comparable else 0.0
        upgrade = pts - floor
        if upgrade > 0 or trend.get(pid):
            out.append((pid, pts, round(upgrade, 2), trend.get(pid, 0)))
    out.sort(key=lambda x: (-x[2], -x[3]))
    return out[:limit]
