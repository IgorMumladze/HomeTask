from pydantic_settings import BaseSettings
import os


class Settings(BaseSettings):
    # API Configuration
    api_port: int = int(os.getenv("API_PORT", 5000))
    api_host: str = "0.0.0.0"
    api_version: str = "1.0.0"

    # Security & Token
    api_token: str = os.getenv("API_TOKEN", "default_secret_token")

    # AWS Configuration
    aws_region: str = os.getenv("AWS_REGION", "us-east-1")
    sqs_queue_url: str = os.getenv("SQS_QUEUE_URL", "")
    use_mock_sqs: bool = os.getenv("USE_MOCK_SQS", "true").lower() == "true"

    # Email Validation
    max_email_subject_length: int = 255
    max_email_sender_length: int = 255
    max_email_content_length: int = 5000
    max_timestamp_age_days: int = 7

    # Logging
    log_level: str = os.getenv("LOG_LEVEL", "INFO")

    class Config:
        env_file = ".env"


settings = Settings()

