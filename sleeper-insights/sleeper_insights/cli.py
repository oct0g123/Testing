"""Command-line entry point: python -m sleeper_insights <command> ..."""

from __future__ import annotations

import argparse
import os
import sys

from . import analysis
from .api import SleeperClient, SleeperError


def table(headers: list[str], rows: list[list]) -> str:
    cells = [[str(h) for h in headers]] + [[str(c) for c in r] for r in rows]
    widths = [max(len(r[i]) for r in cells) for i in range(len(headers))]

    def line(r):
        return "  ".join(c.rjust(w) if _numeric(c) else c.ljust(w) for c, w in zip(r, widths)).rstrip()

    return "\n".join([line(cells[0]), "  ".join("-" * w for w in widths)] + [line(r) for r in cells[1:]])


def _numeric(s: str) -> bool:
    return s.replace(".", "", 1).replace("-", "", 1).replace("+", "", 1).replace("%", "").isdigit()


def heading(text: str) -> str:
    return f"\n{text}\n{'=' * len(text)}"


def resolve_week(lg: analysis.League, week: int | None) -> int:
    if week:
        return week
    if lg.current_week:
        return lg.current_week
    sys.exit("This league isn't in its regular season right now; pass --week N.")


# --- commands ---------------------------------------------------------------


def cmd_leagues(client: SleeperClient, args) -> str:
    user = client.user(args.username)
    season = args.season or client.state().get("season")
    leagues = client.user_leagues(user["user_id"], season)
    if not leagues:
        return f"No {season} leagues found for {args.username}."
    rows = [[lg["league_id"], lg.get("name", ""), lg.get("total_rosters", ""), lg.get("status", "")] for lg in leagues]
    return heading(f"{user.get('display_name', args.username)}'s {season} leagues") + "\n" + \
        table(["League ID", "Name", "Teams", "Status"], rows)


def cmd_standings(lg: analysis.League) -> str:
    rows = [[i, t.name, t.manager, t.record, f"{t.points_for:.2f}", f"{t.points_against:.2f}"]
            for i, t in enumerate(analysis.standings(lg), 1)]
    return heading(f"{lg.name} - standings") + "\n" + table(["#", "Team", "Manager", "W-L", "PF", "PA"], rows)


def cmd_power(lg: analysis.League) -> str:
    ranked = analysis.power_rankings(lg)
    if not any(s.weekly for _, s in ranked):
        return heading("Power rankings") + "\nNo completed weeks yet."
    rows = [[i, s.team.name, s.team.record, f"{score:.1f}", f"{s.avg:.1f}", f"{s.recent:.1f}",
             f"{s.allplay_wins}-{s.allplay_losses}", f"{s.luck:+.1f}", f"{s.efficiency:.0%}"]
            for i, (score, s) in enumerate(ranked, 1)]
    out = [heading(f"{lg.name} - power rankings (weeks 1-{max(lg.matchups)})"),
           table(["#", "Team", "W-L", "Power", "Avg", "Last3", "All-play", "Luck", "Lineup eff"], rows),
           "",
           "Power = 40% all-play win% + 35% scoring avg + 25% last-3-week form.",
           "Luck = actual wins minus wins expected from all-play. Lineup eff = points scored / best possible lineup."]

    stats = [s for _, s in ranked]
    luckiest = max(stats, key=lambda s: s.luck)
    unluckiest = min(stats, key=lambda s: s.luck)
    hottest = max(stats, key=lambda s: s.recent - s.avg)
    coldest = min(stats, key=lambda s: s.recent - s.avg)
    worst_mgr = min(stats, key=lambda s: s.efficiency or 1)
    steady = min(stats, key=lambda s: s.stdev)
    out += [heading("Storylines"),
            f"- Luckiest: {luckiest.team.name} ({luckiest.luck:+.1f} wins vs. all-play expectation)",
            f"- Unluckiest: {unluckiest.team.name} ({unluckiest.luck:+.1f})",
            f"- Most points left on the bench: {worst_mgr.team.name} "
            f"({worst_mgr.optimal_points - worst_mgr.actual_points:.1f} pts, {worst_mgr.efficiency:.0%} efficiency)",
            f"- Most consistent: {steady.team.name} (weekly std dev {steady.stdev:.1f})"]
    if len(lg.matchups) > 3:
        out.insert(-2, f"- Heating up: {hottest.team.name} (last 3 avg {hottest.recent:.1f} vs season {hottest.avg:.1f})")
        out.insert(-2, f"- Cooling off: {coldest.team.name} (last 3 avg {coldest.recent:.1f} vs season {coldest.avg:.1f})")
    return "\n".join(out)


def cmd_matchups(client: SleeperClient, lg: analysis.League, league_id: str, week: int) -> str:
    projections = client.projections(lg.season, week)
    games = analysis.matchup_preview(lg, week, projections, client.matchups(league_id, week))
    if not games:
        return heading(f"Week {week} matchups") + "\nNo head-to-head matchups found for this week."
    rows = []
    for ta, sa, oa, tb, sb, ob, p in games:
        fav, pct = (ta, p) if p >= 0.5 else (tb, 1 - p)
        odds = "toss-up" if pct < 0.505 else f"{fav.name} {min(pct, 0.99):.0%}"
        rows.append([ta.name, f"{sa:.1f}", f"{oa:.1f}", "vs", tb.name, f"{sb:.1f}", f"{ob:.1f}", odds])
    return heading(f"{lg.name} - week {week} projections") + "\n" + \
        table(["Team", "Proj", "Best", "", "Opponent", "Proj", "Best", "Favorite"], rows) + \
        "\n\nProj = lineup as currently set; Best = optimal lineup from the roster."


def cmd_startsit(client: SleeperClient, lg: analysis.League, league_id: str, week: int, team_query: str) -> str:
    team = lg.find_team(team_query)
    projections = client.projections(lg.season, week)
    rep = analysis.start_sit(lg, team, week, projections, client.matchups(league_id, week))
    out = [heading(f"{team.name} - week {week} start/sit")]
    rows = [[slot, lg.player_label(cur), f"{cp:.1f}", lg.player_label(opt), f"{op:.1f}"]
            for (slot, cur, cp), (_, opt, op) in zip(rep.current, rep.optimal)]
    out.append(table(["Slot", "Current", "Proj", "Recommended", "Proj"], rows))
    out.append(f"\nProjected: {rep.current_total:.1f} as set -> {rep.optimal_total:.1f} optimal "
               f"({rep.optimal_total - rep.current_total:+.1f})")
    if rep.swaps:
        out.append(heading("Moves"))
        out += [f"- START {lg.player_label(i)} over {lg.player_label(o) if o != '(empty slot)' else o} ({g:+.1f})"
                for i, o, g in rep.swaps]
    else:
        out.append("\nYour lineup is already optimal by projection.")
    if rep.flags:
        out.append(heading("Watch list"))
        out += [f"- {lg.player_label(pid)}: {note}" for pid, note in rep.flags]
    if rep.bench:
        out.append(heading("Bench"))
        out.append(table(["Player", "Proj"], [[lg.player_label(p), f"{pts:.1f}"] for p, pts in rep.bench]))
    return "\n".join(out)


def cmd_waivers(client: SleeperClient, lg: analysis.League, week: int, team_query: str, limit: int) -> str:
    team = lg.find_team(team_query)
    projections = client.projections(lg.season, week)
    trending = client.trending("add", 24, 100)
    targets = analysis.waiver_targets(lg, team, projections, trending, limit)
    if not targets:
        return heading(f"{team.name} - week {week} waiver targets") + "\nNo free agents out-project your starters."
    rows = [[lg.player_label(pid), f"{pts:.1f}", f"{up:+.1f}", f"{adds:,}" if adds else ""] for pid, pts, up, adds in targets]
    return heading(f"{team.name} - week {week} waiver targets") + "\n" + \
        table(["Free agent", "Proj", "vs your worst starter", "Adds (24h)"], rows)


def cmd_summary(client: SleeperClient, lg: analysis.League, league_id: str, team_query: str | None) -> str:
    parts = [cmd_standings(lg)]
    if lg.matchups:
        parts.append(cmd_power(lg))
    if lg.current_week:
        parts.append(cmd_matchups(client, lg, league_id, lg.current_week))
        if team_query:
            parts.append(cmd_startsit(client, lg, league_id, lg.current_week, team_query))
            parts.append(cmd_waivers(client, lg, lg.current_week, team_query, 8))
    return "\n".join(parts)


# --- argument parsing -------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="sleeper-insights", description="Insights for a Sleeper fantasy football league.")
    sub = p.add_subparsers(dest="command", required=True)

    lp = sub.add_parser("leagues", help="find your league IDs by Sleeper username")
    lp.add_argument("username")
    lp.add_argument("--season")

    def league_cmd(name, help_text, team=False, team_required=False, week=False):
        sp = sub.add_parser(name, help=help_text)
        sp.add_argument("--league", default=os.environ.get("SLEEPER_LEAGUE_ID"),
                        help="league ID (default: $SLEEPER_LEAGUE_ID)")
        if team:
            sp.add_argument("--team", default=os.environ.get("SLEEPER_TEAM"), required=False,
                            help="team name, manager name, or roster number (default: $SLEEPER_TEAM)")
            sp.set_defaults(team_required=team_required)
        if week:
            sp.add_argument("--week", type=int, help="NFL week (default: current week)")
        return sp

    league_cmd("summary", "standings, power rankings, this week's matchups (+ your start/sit with --team)", team=True)
    league_cmd("standings", "league standings")
    league_cmd("power", "power rankings, luck, lineup efficiency")
    league_cmd("matchups", "projected matchups and win probabilities", week=True)
    league_cmd("startsit", "start/sit recommendations for a team", team=True, team_required=True, week=True)
    wp = league_cmd("waivers", "free agents who would upgrade a team", team=True, team_required=True, week=True)
    wp.add_argument("--limit", type=int, default=15)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    client = SleeperClient()
    try:
        if args.command == "leagues":
            print(cmd_leagues(client, args))
            return 0
        if not args.league:
            sys.exit("Pass --league <id> or set SLEEPER_LEAGUE_ID. "
                     "Find it in the Sleeper league URL, or run: sleeper-insights leagues <username>")
        if getattr(args, "team_required", False) and not args.team:
            sys.exit("Pass --team <name> or set SLEEPER_TEAM.")

        lg = analysis.load_league(client, args.league)
        if args.command == "summary":
            out = cmd_summary(client, lg, args.league, args.team)
        elif args.command == "standings":
            out = cmd_standings(lg)
        elif args.command == "power":
            out = cmd_power(lg)
        elif args.command == "matchups":
            out = cmd_matchups(client, lg, args.league, resolve_week(lg, args.week))
        elif args.command == "startsit":
            out = cmd_startsit(client, lg, args.league, resolve_week(lg, args.week), args.team)
        else:
            out = cmd_waivers(client, lg, resolve_week(lg, args.week), args.team, args.limit)
        print(out)
        return 0
    except (SleeperError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
