import os
import sys
import json
from pathlib import Path
from datetime import datetime
import pytest

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.append(str(ROOT_DIR))

from worker import S3Uploader, settings  # noqa: E402


@pytest.fixture
def temp_cwd(tmp_path):
    original_cwd = Path.cwd()
    os.chdir(tmp_path)
    try:
        yield tmp_path
    finally:
        os.chdir(original_cwd)


def test_mock_upload_creates_file(temp_cwd):
    uploader = S3Uploader(settings)
    message_id = "msg_test"
    now = datetime.utcnow()
    payload = {"message_id": message_id, "timestamp": now.isoformat() + "Z", "data": {"email_subject": "Hello"}}

    assert settings.use_mock_s3 is True
    assert uploader.upload_email(payload, message_id) is True

    expected_key = f"{settings.s3_bucket_prefix}/{now.year}/{now.month:02d}/{now.day:02d}/{message_id}.json"
    expected_path = temp_cwd / "uploads" / expected_key.replace("/", os.sep)

    assert expected_path.exists()
    with open(expected_path) as f:
        saved = json.load(f)

    assert saved["message_id"] == message_id

