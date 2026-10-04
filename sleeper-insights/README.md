# sleeper-insights

Analyze your [Sleeper](https://sleeper.com) fantasy football league from the command line:
standings, power rankings, luck, lineup efficiency, weekly win probabilities,
start/sit recommendations, and waiver targets, all scored with **your league's own
scoring settings and roster slots**.

It uses Sleeper's public read-only API, so it needs no login or API key, just your league ID.
It runs on the Python standard library (3.9+) with no dependencies.

## Find your league ID

Open your league on sleeper.com. The ID is the long number in the URL
(`https://sleeper.com/leagues/<LEAGUE_ID>/...`). Or look it up by username:

```sh
python -m sleeper_insights leagues <your_sleeper_username>
```

## Usage

```sh
cd sleeper-insights
export SLEEPER_LEAGUE_ID=123456789012345678
export SLEEPER_TEAM="your team or username"   # optional default for --team

python -m sleeper_insights summary            # everything below, for the current week
python -m sleeper_insights standings
python -m sleeper_insights power              # power rankings + storylines
python -m sleeper_insights matchups [--week N]
python -m sleeper_insights startsit --team alice [--week N]
python -m sleeper_insights waivers  --team alice [--limit 15]
```

`pip install .` also installs a `sleeper-insights` command.

## What the numbers mean

| Metric | How it's computed |
| --- | --- |
| **All-play** | Your record if you played every team every week. It strips out schedule luck. |
| **Luck** | Actual wins minus the wins your all-play % predicts. Positive means a soft schedule. |
| **Lineup eff** | Points you scored ÷ points your best possible lineup would have scored. |
| **Power** | 40% all-play win % + 35% season scoring average + 25% last-3-week average (0–100). |
| **Proj / Best** | Projected points for the lineup as currently set vs. the optimal lineup. |
| **Win %** | Normal approximation, assuming each team's score varies about ±20% of its projection. |

Start/sit uses Sleeper's weekly player projections, rescored with your league's
scoring settings. It fills slots most-restrictive first (QB → RB/WR/TE → FLEX →
SUPER_FLEX). Players listed as Out/IR/Suspended are projected at 0. Questionable
and Doubtful players are flagged.

Waiver targets are unrostered players who out-project your weakest starter at
their position, plus players trending in adds across Sleeper over the last 24h.

## Notes

- The full NFL player list (~5 MB) is cached in `~/.cache/sleeper-insights` for 24h
  (override with `SLEEPER_CACHE_DIR`).
- Projections come from an undocumented endpoint the Sleeper app uses
  (`api.sleeper.app/projections/...`). It works today but could change without notice.

## Tests

```sh
python -m unittest discover -s tests -t .
```
