import sys
from pathlib import Path
import pytest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.append(str(ROOT_DIR))

from app import app, settings  # noqa: E402

client = TestClient(app)


class TestEmailEndpoint:
    @pytest.fixture
    def valid_email(self):
        return {
            "data": {
                "email_subject": "Test Subject",
                "email_sender": "John Doe",
                "email_timestream": str(int(datetime.utcnow().timestamp())),
                "email_content": "This is test content",
            },
            "token": settings.api_token,
        }

    def test_valid_email(self, valid_email):
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "accepted"
        assert "message_id" in data
        assert data["message_id"].startswith("msg_")

    def test_invalid_token(self, valid_email):
        valid_email["token"] = "wrong_token"
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 401

    def test_missing_email_subject(self, valid_email):
        del valid_email["data"]["email_subject"]
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 422

    def test_missing_email_sender(self, valid_email):
        del valid_email["data"]["email_sender"]
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 422

    def test_missing_email_timestream(self, valid_email):
        del valid_email["data"]["email_timestream"]
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 422

    def test_missing_email_content(self, valid_email):
        del valid_email["data"]["email_content"]
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 422

    def test_future_timestamp(self, valid_email):
        future = int((datetime.utcnow() + timedelta(hours=1)).timestamp())
        valid_email["data"]["email_timestream"] = str(future)
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 422

    def test_old_timestamp(self, valid_email):
        old = int((datetime.utcnow() - timedelta(days=10)).timestamp())
        valid_email["data"]["email_timestream"] = str(old)
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 422

    def test_invalid_timestamp_format(self, valid_email):
        valid_email["data"]["email_timestream"] = "not_a_number"
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 422

    def test_empty_subject(self, valid_email):
        valid_email["data"]["email_subject"] = ""
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 422

    def test_oversized_content(self, valid_email):
        valid_email["data"]["email_content"] = "x" * 6000
        response = client.post("/send-email", json=valid_email)
        assert response.status_code == 422

    def test_health_endpoint(self):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "email-api"

    def test_config_endpoint(self):
        response = client.get("/config")
        assert response.status_code == 200
        data = response.json()
        assert data["max_email_content_length"] == 5000
        assert data["max_timestamp_age_days"] == 7

