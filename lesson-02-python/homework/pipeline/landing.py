"""Landing stage — idempotent download of the raw hour into the landing zone.

This module is GIVEN. You do not need to change it. It mirrors the lesson's
"landing zone" idea: the raw file is immutable, so a repeat run that finds the
file already present skips the download.
"""

from __future__ import annotations

import logging
import os
import urllib.request

from . import config

logger = logging.getLogger(__name__)


def land_raw_hour() -> str:
    """Download the configured GitHub Archive hour into the landing zone.

    Returns the local path. Idempotent: if the file already exists it is not
    re-downloaded.
    """
    os.makedirs(config.LANDING_DIR, exist_ok=True)
    if os.path.exists(config.LANDING_FILE):
        logger.info("already present, skip: %s", os.path.basename(config.LANDING_FILE))
        return config.LANDING_FILE

    logger.info("downloading %s ...", config.GH_URL)
    # gharchive.org returns 403 to urllib's default User-Agent.
    req = urllib.request.Request(config.GH_URL, headers={"User-Agent": "de-course-l02/1.0"})
    with urllib.request.urlopen(req) as resp, open(config.LANDING_FILE, "wb") as out:
        while chunk := resp.read(1 << 20):
            out.write(chunk)
    size_mb = os.path.getsize(config.LANDING_FILE) / 1_000_000
    logger.info("saved %s (%.0f MB)", os.path.basename(config.LANDING_FILE), size_mb)
    return config.LANDING_FILE
