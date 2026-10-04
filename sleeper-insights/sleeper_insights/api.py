"""Thin client for the public Sleeper API (https://docs.sleeper.com).

Sleeper's API is read-only and needs no authentication. Only the standard
library is used so the tool runs anywhere Python 3.9+ is installed.
"""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

BASE_URL = "https://api.sleeper.app"
PLAYERS_CACHE_TTL = 24 * 60 * 60  # the players dump is ~5MB; Sleeper asks callers to fetch it at most daily
SKILL_POSITIONS = ["QB", "RB", "WR", "TE", "K", "DEF", "DL", "LB", "DB"]


class SleeperError(RuntimeError):
    pass


class SleeperClient:
    def __init__(self, cache_dir: str | os.PathLike | None = None, timeout: float = 20):
        default_cache = Path.home() / ".cache" / "sleeper-insights"
        self.cache_dir = Path(cache_dir or os.environ.get("SLEEPER_CACHE_DIR") or default_cache)
        self.timeout = timeout

    def _get(self, path: str, params: dict | None = None):
        url = BASE_URL + path
        if params:
            url += "?" + urllib.parse.urlencode(params, doseq=True)
        req = urllib.request.Request(url, headers={"User-Agent": "sleeper-insights/0.1"})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            raise SleeperError(f"GET {url} failed: HTTP {e.code}") from e
        except urllib.error.URLError as e:
            raise SleeperError(f"GET {url} failed: {e.reason}") from e

    # --- core endpoints -------------------------------------------------

    def state(self) -> dict:
        return self._get("/v1/state/nfl")

    def user(self, username_or_id: str) -> dict:
        user = self._get(f"/v1/user/{urllib.parse.quote(username_or_id)}")
        if not user:
            raise SleeperError(f"Sleeper user {username_or_id!r} not found")
        return user

    def user_leagues(self, user_id: str, season: str | int) -> list[dict]:
        return self._get(f"/v1/user/{user_id}/leagues/nfl/{season}") or []

    def league(self, league_id: str) -> dict:
        league = self._get(f"/v1/league/{league_id}")
        if not league:
            raise SleeperError(f"League {league_id!r} not found")
        return league

    def users(self, league_id: str) -> list[dict]:
        return self._get(f"/v1/league/{league_id}/users") or []

    def rosters(self, league_id: str) -> list[dict]:
        return self._get(f"/v1/league/{league_id}/rosters") or []

    def matchups(self, league_id: str, week: int) -> list[dict]:
        return self._get(f"/v1/league/{league_id}/matchups/{week}") or []

    def transactions(self, league_id: str, week: int) -> list[dict]:
        return self._get(f"/v1/league/{league_id}/transactions/{week}") or []

    def trending(self, kind: str = "add", lookback_hours: int = 24, limit: int = 50) -> list[dict]:
        return self._get(f"/v1/players/nfl/trending/{kind}",
                         {"lookback_hours": lookback_hours, "limit": limit}) or []

    def players(self) -> dict:
        """All NFL players keyed by player_id, cached on disk for a day."""
        cache = self.cache_dir / "players_nfl.json"
        if cache.exists() and time.time() - cache.stat().st_mtime < PLAYERS_CACHE_TTL:
            with cache.open() as f:
                return json.load(f)
        data = self._get("/v1/players/nfl") or {}
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        tmp = cache.with_suffix(".tmp")
        with tmp.open("w") as f:
            json.dump(data, f)
        tmp.replace(cache)
        return data

    # --- undocumented endpoints used by the Sleeper app -----------------

    def projections(self, season: str | int, week: int, season_type: str = "regular") -> dict[str, dict]:
        """Weekly projected stat lines keyed by player_id."""
        rows = self._get(f"/projections/nfl/{season}/{week}",
                         {"season_type": season_type, "position[]": SKILL_POSITIONS}) or []
        return {r["player_id"]: r.get("stats") or {} for r in rows if r.get("player_id")}

    def stats(self, season: str | int, week: int, season_type: str = "regular") -> dict[str, dict]:
        """Actual weekly stat lines keyed by player_id."""
        rows = self._get(f"/stats/nfl/{season}/{week}",
                         {"season_type": season_type, "position[]": SKILL_POSITIONS}) or []
        return {r["player_id"]: r.get("stats") or {} for r in rows if r.get("player_id")}
