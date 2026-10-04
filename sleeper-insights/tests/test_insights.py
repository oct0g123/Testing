import io
import unittest
from contextlib import redirect_stdout
from unittest import mock

from sleeper_insights import analysis, cli
from sleeper_insights.lineup import optimal_lineup, score

SCORING = {"pass_yd": 0.04, "pass_td": 4, "pass_int": -1, "rush_yd": 0.1, "rush_td": 6,
           "rec": 1, "rec_yd": 0.1, "rec_td": 6, "fum_lost": -2, "def_td": 6, "sack": 1,
           "pts_allow_0": 10, "pts_allow_7_13": 4, "pts_allow_14_20": 1, "pts_allow_21_27": 0}

PLAYERS = {
    "q1": {"full_name": "Alpha QB", "position": "QB", "fantasy_positions": ["QB"], "team": "BUF"},
    "q2": {"full_name": "Bravo QB", "position": "QB", "fantasy_positions": ["QB"], "team": "KC"},
    "r1": {"full_name": "Charlie RB", "position": "RB", "fantasy_positions": ["RB"], "team": "SF"},
    "r2": {"full_name": "Delta RB", "position": "RB", "fantasy_positions": ["RB"], "team": "DET",
           "injury_status": "Out"},
    "r3": {"full_name": "Echo RB", "position": "RB", "fantasy_positions": ["RB"], "team": "MIA"},
    "w1": {"full_name": "Foxtrot WR", "position": "WR", "fantasy_positions": ["WR"], "team": "CIN"},
    "w2": {"full_name": "Golf WR", "position": "WR", "fantasy_positions": ["WR"], "team": "DAL",
           "injury_status": "Questionable"},
    "w3": {"full_name": "Hotel WR", "position": "WR", "fantasy_positions": ["WR"], "team": "LAR"},
    "t1": {"full_name": "India TE", "position": "TE", "fantasy_positions": ["TE"], "team": "KC"},
    "fa1": {"full_name": "Juliet WR", "position": "WR", "fantasy_positions": ["WR"], "team": "NYJ"},
    "fa2": {"full_name": "Kilo RB", "position": "RB", "fantasy_positions": ["RB"], "team": "NE"},
    "BUF": {"position": "DEF", "fantasy_positions": ["DEF"], "team": "BUF"},
}

# 4 teams; roster positions QB RB WR TE FLEX DEF + bench
ROSTER_POSITIONS = ["QB", "RB", "WR", "TE", "FLEX", "DEF", "BN", "BN", "BN"]


def proj(**stats):
    return stats


PROJECTIONS = {
    "q1": proj(pass_yd=275, pass_td=2, pass_int=1, rush_yd=20),  # 20
    "r1": proj(rush_yd=90, rush_td=1, rec=3, rec_yd=20),         # 20
    "r2": proj(rush_yd=80, rush_td=1),                           # 14 but Out
    "r3": proj(rush_yd=50, rec=2, rec_yd=10),                    # 8
    "w1": proj(rec=7, rec_yd=90, rec_td=1),                      # 22
    "w2": proj(rec=4, rec_yd=50),                                # 9
    "w3": proj(rec=5, rec_yd=70),                                # 12
    "t1": proj(rec=5, rec_yd=55),                                # 10.5
    "BUF": proj(sack=3, pts_allow=17),                           # 3 + 1
    "fa1": proj(rec=6, rec_yd=80),                               # 14
    "fa2": proj(rush_yd=30),                                     # 3
    "q2": proj(pass_yd=250, pass_td=2),                          # 18
}


class FakeClient:
    def __init__(self):
        self.calls = []

    def state(self):
        return {"season": "2026", "season_type": "regular", "week": 5, "display_week": 5}

    def league(self, league_id):
        return {"league_id": league_id, "name": "Test League", "season": "2026",
                "roster_positions": ROSTER_POSITIONS, "scoring_settings": SCORING,
                "settings": {"last_scored_leg": 3}}

    def users(self, league_id):
        return [
            {"user_id": "u1", "display_name": "alice", "metadata": {"team_name": "Alice's Aces"}},
            {"user_id": "u2", "display_name": "bob", "metadata": {}},
            {"user_id": "u3", "display_name": "cara", "metadata": {"team_name": "Cara Crushers"}},
            {"user_id": "u4", "display_name": "dan", "metadata": {}},
        ]

    def rosters(self, league_id):
        def st(w, l, pf, pa):
            return {"wins": w, "losses": l, "ties": 0, "fpts": int(pf), "fpts_decimal": round(pf % 1 * 100),
                    "fpts_against": int(pa), "fpts_against_decimal": round(pa % 1 * 100)}
        return [
            {"roster_id": 1, "owner_id": "u1", "settings": st(2, 1, 330.5, 300.0),
             "players": ["q1", "r1", "r2", "r3", "w1", "w2", "w3", "t1", "BUF"],
             "starters": ["q1", "r2", "w2", "t1", "r3", "BUF"]},
            {"roster_id": 2, "owner_id": "u2", "settings": st(1, 2, 290.0, 310.0),
             "players": ["q2"], "starters": ["q2", "0", "0", "0", "0", "0"]},
            {"roster_id": 3, "owner_id": "u3", "settings": st(3, 0, 360.0, 280.0), "players": [], "starters": []},
            {"roster_id": 4, "owner_id": "u4", "settings": st(0, 3, 250.0, 340.0), "players": [], "starters": []},
        ]

    def matchups(self, league_id, week):
        self.calls.append(("matchups", week))
        scores = {1: [110, 100, 120.5], 2: [90, 105, 95], 3: [130, 115, 115], 4: [80, 95, 75]}
        if week <= 3:
            pairs = {1: (1, 2, 3, 4), 2: (1, 3, 2, 4), 3: (1, 4, 2, 3)}[week]
            mids = {pairs[0]: 1, pairs[1]: 1, pairs[2]: 2, pairs[3]: 2}
            rows = []
            for rid in (1, 2, 3, 4):
                row = {"roster_id": rid, "matchup_id": mids[rid], "points": scores[rid][week - 1]}
                if rid == 1:
                    # Alice left w1 (25 pts) on the bench in favor of w2 (5 pts) every week;
                    # starters (q1 r1 w2 t1 r3 BUF) sum to the week's team score.
                    row["players_points"] = {"q1": scores[1][week - 1] - 44, "r1": 15, "w1": 25, "w2": 5,
                                             "t1": 10, "r3": 8, "BUF": 6}
                rows.append(row)
            return rows
        if week == 5:
            return [
                {"roster_id": 1, "matchup_id": 1, "points": 0, "starters": ["q1", "r2", "w2", "t1", "r3", "BUF"]},
                {"roster_id": 2, "matchup_id": 1, "points": 0, "starters": ["q2", "0", "0", "0", "0", "0"]},
                {"roster_id": 3, "matchup_id": 2, "points": 0, "starters": []},
                {"roster_id": 4, "matchup_id": 2, "points": 0, "starters": []},
            ]
        return []

    def players(self):
        return PLAYERS

    def projections(self, season, week, season_type="regular"):
        return PROJECTIONS

    def trending(self, kind="add", lookback_hours=24, limit=50):
        return [{"player_id": "fa2", "count": 12000}, {"player_id": "fa1", "count": 5000}]

    def user(self, username):
        return {"user_id": "u1", "display_name": username}

    def user_leagues(self, user_id, season):
        return [{"league_id": "123", "name": "Test League", "total_rosters": 4, "status": "in_season"}]


def load():
    client = FakeClient()
    return client, analysis.load_league(client, "123")


class ScoringTests(unittest.TestCase):
    def test_league_scoring(self):
        self.assertEqual(score(PROJECTIONS["w1"], SCORING), 22.0)
        self.assertEqual(score(PROJECTIONS["q1"], SCORING), 20.0)

    def test_defense_points_allowed_bucket(self):
        self.assertEqual(score(PROJECTIONS["BUF"], SCORING), 4.0)

    def test_fallback_to_precomputed_points(self):
        self.assertEqual(score({"pts_ppr": 12.3, "pts_std": 9.0}, SCORING), 12.3)
        self.assertEqual(score({"pts_ppr": 12.3, "pts_std": 9.0}, {"rec": 0, "pass_td": 4}), 9.0)

    def test_empty(self):
        self.assertEqual(score(None, SCORING), 0.0)


class LineupTests(unittest.TestCase):
    def test_flex_filled_after_fixed_slots(self):
        cands = {"r1": ({"RB"}, 20), "r2": ({"RB"}, 15), "w1": ({"WR"}, 18), "w2": ({"WR"}, 16), "t1": ({"TE"}, 5)}
        lineup = optimal_lineup(["RB", "WR", "FLEX", "TE"], cands)
        self.assertEqual([pid for _, pid, _ in lineup], ["r1", "w1", "w2", "t1"])

    def test_superflex_takes_qb(self):
        cands = {"q1": ({"QB"}, 22), "q2": ({"QB"}, 19), "r1": ({"RB"}, 12)}
        lineup = optimal_lineup(["QB", "SUPER_FLEX", "RB"], cands)
        self.assertEqual([pid for _, pid, _ in lineup], ["q1", "q2", "r1"])

    def test_empty_slot_when_no_eligible_player(self):
        lineup = optimal_lineup(["K"], {"r1": ({"RB"}, 10)})
        self.assertEqual(lineup, [("K", None, 0.0)])


class LeagueTests(unittest.TestCase):
    def test_load_league(self):
        client, lg = load()
        self.assertEqual(lg.current_week, 5)
        self.assertEqual(sorted(lg.matchups), [1, 2, 3])
        self.assertEqual(lg.teams[1].name, "Alice's Aces")
        self.assertEqual(lg.teams[2].name, "bob")
        self.assertAlmostEqual(lg.teams[1].points_for, 330.5)

    def test_find_team(self):
        _, lg = load()
        self.assertEqual(lg.find_team("alice").roster_id, 1)
        self.assertEqual(lg.find_team("crushers").roster_id, 3)
        self.assertEqual(lg.find_team("4").roster_id, 4)
        with self.assertRaises(ValueError):
            lg.find_team("zzz")

    def test_standings_order(self):
        _, lg = load()
        self.assertEqual([t.roster_id for t in analysis.standings(lg)], [3, 1, 2, 4])

    def test_allplay_and_luck(self):
        _, lg = load()
        stats = {s.team.roster_id: s for s in analysis.team_stats(lg)}
        cara = stats[3]
        self.assertEqual(cara.weekly, [130, 115, 115])
        self.assertEqual(cara.allplay_wins + cara.allplay_losses, 9)
        # Dan scored the fewest points every week.
        dan = stats[4]
        self.assertEqual(dan.allplay_wins, 0)
        self.assertAlmostEqual(dan.expected_wins, 0.0)
        self.assertEqual(dan.actual_wins, 0)

    def test_lineup_efficiency_flags_bench_points(self):
        _, lg = load()
        alice = next(s for s in analysis.team_stats(lg) if s.team.roster_id == 1)
        # Optimal swaps w2 (5) for w1 (25) each week: 20 pts/week left on the bench.
        self.assertAlmostEqual(alice.optimal_points - alice.actual_points, 60)
        self.assertLess(alice.efficiency, 1)

    def test_power_rankings_top_team(self):
        _, lg = load()
        ranked = analysis.power_rankings(lg)
        self.assertEqual(ranked[0][1].team.roster_id, 3)
        self.assertEqual(ranked[-1][1].team.roster_id, 4)


class StartSitTests(unittest.TestCase):
    def setUp(self):
        self.client, self.lg = load()
        self.team = self.lg.teams[1]
        self.rep = analysis.start_sit(self.lg, self.team, 5, PROJECTIONS, self.client.matchups("123", 5))

    def test_benches_injured_and_weak_players(self):
        optimal = [pid for _, pid, _ in self.rep.optimal]
        self.assertEqual(optimal, ["q1", "r1", "w1", "t1", "w3", "BUF"])
        started = {i for i, _, _ in self.rep.swaps}
        sat = {o for _, o, _ in self.rep.swaps}
        self.assertEqual(started, {"r1", "w1", "w3"})
        self.assertEqual(sat, {"r2", "w2", "r3"})
        pairs = {i: o for i, o, _ in self.rep.swaps}
        self.assertEqual(pairs, {"r1": "r2", "w1": "w2", "w3": "r3"})

    def test_projected_gain(self):
        self.assertEqual(self.rep.current_total, 20 + 0 + 9 + 10.5 + 8 + 4)
        self.assertEqual(self.rep.optimal_total, 20 + 20 + 22 + 10.5 + 12 + 4)

    def test_flags_injuries(self):
        notes = dict(self.rep.flags)
        self.assertIn("Out", notes["r2"])
        self.assertIn("Questionable", notes["w2"])

    def test_waiver_targets(self):
        targets = analysis.waiver_targets(self.lg, self.team, PROJECTIONS, self.client.trending())
        ids = [t[0] for t in targets]
        self.assertEqual(ids[0], "fa1")  # 14 pts beats Alice's worst WR starter (w3, 12)
        self.assertIn("fa2", ids)        # trending even though not an upgrade
        self.assertNotIn("q2", ids)      # rostered by Bob

    def test_matchup_preview(self):
        games = analysis.matchup_preview(self.lg, 5, PROJECTIONS, self.client.matchups("123", 5))
        self.assertEqual(len(games), 2)
        ta, sa, oa, tb, sb, ob, p = games[0]
        self.assertEqual((ta.roster_id, tb.roster_id), (1, 2))
        self.assertGreater(p, 0.9)

    def test_win_probability_symmetry(self):
        self.assertAlmostEqual(analysis.win_probability(100, 100), 0.5)
        self.assertAlmostEqual(analysis.win_probability(110, 100) + analysis.win_probability(100, 110), 1)


class CliTests(unittest.TestCase):
    def run_cli(self, *argv):
        buf = io.StringIO()
        with mock.patch.object(cli, "SleeperClient", FakeClient), redirect_stdout(buf):
            code = cli.main(list(argv))
        return code, buf.getvalue()

    def test_every_command_renders(self):
        for argv in (["summary", "--league", "123", "--team", "alice"],
                     ["standings", "--league", "123"],
                     ["power", "--league", "123"],
                     ["matchups", "--league", "123"],
                     ["startsit", "--league", "123", "--team", "alice"],
                     ["waivers", "--league", "123", "--team", "alice"],
                     ["leagues", "someone"]):
            code, out = self.run_cli(*argv)
            self.assertEqual(code, 0, argv)
            self.assertTrue(out.strip(), argv)

    def test_startsit_output(self):
        _, out = self.run_cli("startsit", "--league", "123", "--team", "alice")
        self.assertIn("START Foxtrot WR (WR, CIN) over", out)
        self.assertIn("Delta RB (RB, DET): Out - do not start", out)

    def test_unknown_team_is_an_error(self):
        code, _ = self.run_cli("startsit", "--league", "123", "--team", "nobody")
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
