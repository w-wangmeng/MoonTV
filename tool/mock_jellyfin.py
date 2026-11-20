"""Small local Jellyfin-shaped server used for MoonBox integration tests.

Run with:
    python tool/mock_jellyfin.py 8099
Then on Android:
    adb reverse tcp:8099 tcp:8099
Use http://127.0.0.1:8099 in MoonBox.
"""

from __future__ import annotations

import json
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
SAMPLE = Path(__file__).with_name("sample.mp4")
MOCK_ART = Path(__file__).with_name("mock_art")

MOVIE = {
    "Id": "movie-1",
    "Name": "月光放映室",
    "Type": "Movie",
    "Overview": "一部用于验证 MoonBox 媒体库模式测试电影。连接、浏览、详情和播放进度都会经过这里。",
    "ProductionYear": 2026,
    "RunTimeTicks": 6000000000,
    "OfficialRating": "PG-13",
    "CommunityRating": 8.6,
    "Genres": ["剧情", "科幻"],
    "ImageTags": {"Primary": "movie-tag"},
    "BackdropImageTags": ["backdrop-tag"],
    "MediaSources": [{"Id": "source-movie-1", "Container": "mp4"}],
    "UserData": {"PlaybackPositionTicks": 1800000000, "Played": False},
}

MOVIE_2 = {
    **MOVIE,
    "Id": "movie-2",
    "Name": "第二部测试电影",
    "ProductionYear": 2025,
    "RunTimeTicks": 5400000000,
    "ImageTags": {"Primary": "movie-tag-2"},
    "MediaSources": [{"Id": "source-movie-2", "Container": "mp4"}],
    "UserData": {"Played": False},
}

PLEX_MOVIE = {
    "ratingKey": "100",
    "type": "movie",
    "title": "Plex 测试电影",
    "summary": "用于验证 MoonBox Plex 模式的测试电影。",
    "year": 2026,
    "duration": 60000,
    "contentRating": "PG",
    "rating": 8.1,
    "thumb": "/library/metadata/100/thumb/1",
    "art": "/library/metadata/100/art/1",
    "viewOffset": 12000,
    "viewCount": 0,
    "Media": [{"Part": [{"id": "part-100"}]}],
}

PLEX_SHOW = {
    "ratingKey": "200",
    "type": "show",
    "title": "Plex 测试剧集",
    "summary": "用于验证 Plex 季与集列表。",
    "year": 2026,
    "thumb": "/library/metadata/200/thumb/1",
    "art": "/library/metadata/200/art/1",
    "viewCount": 0,
}

PLEX_SEASON = {
    "ratingKey": "201",
    "type": "season",
    "title": "第 1 季",
    "parentRatingKey": "200",
    "index": 1,
    "thumb": "/library/metadata/201/thumb/1",
}

PLEX_EPISODE = {
    "ratingKey": "202",
    "type": "episode",
    "title": "Plex 第 1 集",
    "summary": "Plex 测试剧集的第一集。",
    "grandparentRatingKey": "200",
    "grandparentTitle": "Plex 测试剧集",
    "parentRatingKey": "201",
    "parentTitle": "第 1 季",
    "index": 1,
    "parentIndex": 1,
    "duration": 30000,
    "viewOffset": 4000,
    "thumb": "/library/metadata/202/thumb/1",
    "viewCount": 0,
    "Media": [{"Part": [{"id": "part-202"}]}],
}

SERIES = {
    "Id": "series-1",
    "Name": "测试剧集",
    "Type": "Series",
    "Overview": "用于验证季与集列表的迷你剧。",
    "ProductionYear": 2026,
    "ImageTags": {"Primary": "series-tag"},
    "BackdropImageTags": ["series-backdrop"],
    "UserData": {"Played": False},
}

SEASON = {
    "Id": "season-1",
    "Name": "第 1 季",
    "Type": "Season",
    "SeriesId": "series-1",
    "IndexNumber": 1,
    "ImageTags": {"Primary": "season-tag"},
}

EPISODES = [
    {
        "Id": f"episode-{n}",
        "Name": f"第 {n} 集 · 测试章节",
        "Type": "Episode",
        "SeriesId": "series-1",
        "SeriesName": "测试剧集",
        "SeasonId": "season-1",
        "SeasonName": "第 1 季",
        "IndexNumber": n,
        "ParentIndexNumber": 1,
        "RunTimeTicks": 2400000000,
        "Overview": "这一集用于验证应用内的选集与播放进度。",
        "ImageTags": {"Primary": f"episode-tag-{n}"},
        "MediaSources": [{"Id": f"source-episode-{n}", "Container": "mp4"}],
        "UserData": {"PlaybackPositionTicks": 0, "Played": False},
    }
    for n in (1, 2, 3)
]


def json_bytes(value):
    return json.dumps(value, ensure_ascii=False).encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    server_version = "MockJellyfin/1.0"

    def log_message(self, fmt, *args):
        sys.stderr.write(f"[mock] {self.address_string()} {fmt % args}\n")

    def _send(self, value, status=200):
        body = json_bytes(value)
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _path(self):
        parsed = urlparse(self.path)
        return parsed.path.rstrip("/") or "/", parse_qs(parsed.query)

    def do_POST(self):
        path, _ = self._path()
        length = int(self.headers.get("Content-Length", "0"))
        if length:
            self.rfile.read(length)
        if path == "/Users/AuthenticateByName":
            self._send(
                {
                    "AccessToken": "mock-token",
                    "User": {"Id": "user-1", "Name": "Demo"},
                    "ServerId": "mock-server",
                }
            )
            return
        if path.startswith("/Sessions/Playing"):
            self.send_response(204)
            self.end_headers()
            return
        self._send({"error": "not found"}, 404)

    def do_HEAD(self):
        path, _ = self._path()
        if path.startswith("/Videos/") and SAMPLE.exists():
            size = SAMPLE.stat().st_size
            self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header("Content-Length", str(size))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
            return
        self.send_response(404)
        self.end_headers()

    def _send_image(self, path):
        wide = "Backdrop" in path or "/art/" in path
        if "movie-1" in path or "/100/" in path:
            name = "movie1"
        elif "movie-2" in path or "/101/" in path:
            name = "movie2"
        elif "series-1" in path or "/200/" in path or "/201/" in path:
            name = "series"
        elif "episode" in path or "/202/" in path:
            name = "episode"
        else:
            name = "movie1"
        target = MOCK_ART / f"{name}{'-wide' if wide else ''}.png"
        if not target.exists():
            self.send_response(404)
            self.end_headers()
            return
        body = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "public, max-age=3600")
        self.end_headers()
        self.wfile.write(body)

    def _send_video(self):
        if not SAMPLE.exists():
            self._send({"error": "sample.mp4 missing"}, 404)
            return
        size = SAMPLE.stat().st_size
        range_header = self.headers.get("Range", "")
        start, end = 0, size - 1
        match = re.match(r"bytes=(\d+)-(\d*)", range_header)
        if match:
            start = int(match.group(1))
            if match.group(2):
                end = min(int(match.group(2)), size - 1)
            self.send_response(206)
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        else:
            self.send_response(200)
        length = max(0, end - start + 1)
        self.send_header("Content-Type", "video/mp4")
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        with SAMPLE.open("rb") as media:
            media.seek(start)
            remaining = length
            while remaining > 0:
                chunk = media.read(min(64 * 1024, remaining))
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    break
                remaining -= len(chunk)

    def do_GET(self):
        path, query = self._path()
        if path == "/":
            self._send(
                {
                    "MediaContainer": {
                        "friendlyName": "Mock Plex",
                        "version": "1.40.0",
                    }
                }
            )
            return
        if path == "/library/sections":
            self._send(
                {
                    "MediaContainer": {
                        "Directory": [
                            {"key": "1", "title": "Plex 电影", "type": "movie"},
                            {"key": "2", "title": "Plex 剧集", "type": "show"},
                        ]
                    }
                }
            )
            return
        if path == "/library/sections/1/all":
            self._send(
                {
                    "MediaContainer": {
                        "size": 1,
                        "totalSize": 1,
                        "Video": [PLEX_MOVIE],
                    }
                }
            )
            return
        if path == "/library/sections/2/all":
            self._send(
                {
                    "MediaContainer": {
                        "size": 1,
                        "totalSize": 1,
                        "Directory": [PLEX_SHOW],
                    }
                }
            )
            return
        if path in ("/library/sections/1/search", "/library/sections/2/search"):
            if path.startswith("/library/sections/1"):
                payload = {"size": 1, "totalSize": 1, "Video": [PLEX_MOVIE]}
            else:
                payload = {"size": 1, "totalSize": 1, "Directory": [PLEX_SHOW]}
            self._send({"MediaContainer": payload})
            return
        if path == "/library/onDeck":
            self._send(
                {"MediaContainer": {"size": 1, "Video": [PLEX_EPISODE]}}
            )
            return
        if path == "/library/metadata/100":
            self._send({"MediaContainer": {"Video": [PLEX_MOVIE]}})
            return
        if path == "/library/metadata/200":
            self._send({"MediaContainer": {"Directory": [PLEX_SHOW]}})
            return
        if path == "/library/metadata/200/children":
            self._send({"MediaContainer": {"Directory": [PLEX_SEASON]}})
            return
        if path == "/library/metadata/201/children":
            self._send({"MediaContainer": {"Video": [PLEX_EPISODE]}})
            return
        if path == "/library/metadata/202":
            self._send({"MediaContainer": {"Video": [PLEX_EPISODE]}})
            return
        if path == "/:/timeline":
            self._send({"MediaContainer": {"size": 0}})
            return
        if path.startswith("/library/parts/"):
            self._send_video()
            return
        if path == "/System/Info/Public":
            self._send(
                {
                    "ServerName": "Mock Jellyfin",
                    "Version": "10.9.0",
                    "Id": "mock-server",
                }
            )
            return
        if path == "/Users/user-1/Views":
            self._send(
                {
                    "Items": [
                        {
                            "Id": "lib-movies",
                            "Name": "电影",
                            "Type": "CollectionFolder",
                            "CollectionType": "movies",
                        },
                        {
                            "Id": "lib-tv",
                            "Name": "剧集",
                            "Type": "CollectionFolder",
                            "CollectionType": "tvshows",
                        },
                    ]
                }
            )
            return
        if path == "/Users/user-1/Items/Resume":
            self._send({"Items": [MOVIE], "TotalRecordCount": 1})
            return
        if path == "/Users/user-1/Items":
            parent = (query.get("ParentId") or [""])[0]
            search = (query.get("SearchTerm") or [""])[0].lower()
            if parent == "lib-movies":
                items = [MOVIE, MOVIE_2]
            elif parent == "lib-tv":
                items = [SERIES]
            else:
                items = [MOVIE, MOVIE_2, SERIES]
            if search:
                items = [item for item in items if search in item["Name"].lower()]
            self._send(
                {
                    "Items": items,
                    "TotalRecordCount": len(items),
                    "StartIndex": 0,
                }
            )
            return
        if path == "/Users/user-1/Items/movie-1":
            self._send(MOVIE)
            return
        if path == "/Users/user-1/Items/movie-2":
            self._send(MOVIE_2)
            return
        if path == "/Users/user-1/Items/series-1":
            self._send(SERIES)
            return
        if path == "/Shows/series-1/Seasons":
            self._send({"Items": [SEASON], "TotalRecordCount": 1})
            return
        if path == "/Shows/series-1/Episodes":
            self._send({"Items": EPISODES, "TotalRecordCount": len(EPISODES)})
            return
        if "/Images/" in path or "/thumb/" in path or "/art/" in path:
            self._send_image(path)
            return
        if path.startswith("/Videos/"):
            self._send_video()
            return
        self._send({"error": "not found", "path": path}, 404)


if __name__ == "__main__":
    print(f"Mock Jellyfin listening on http://127.0.0.1:{PORT}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
