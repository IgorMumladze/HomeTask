from pydantic_settings import BaseSettings
import os


class WorkerSettings(BaseSettings):
    # Worker Configuration
    poll_interval_seconds: int = int(os.getenv("POLL_INTERVAL_SECONDS", 10))
    max_messages_per_poll: int = 10
    visibility_timeout: int = 60
    use_mock_sqs: bool = os.getenv("USE_MOCK_SQS", "true").lower() == "true"
    sqs_endpoint_url: str = os.getenv("SQS_ENDPOINT_URL", "")

    # AWS Configuration
    aws_region: str = os.getenv("AWS_REGION", "us-east-1")
    sqs_queue_url: str = os.getenv("SQS_QUEUE_URL", "")
    dlq_queue_url: str = os.getenv("DLQ_QUEUE_URL", "")
    s3_bucket_name: str = os.getenv("S3_BUCKET_NAME", "email-data-bucket")
    s3_bucket_prefix: str = os.getenv("S3_BUCKET_PREFIX", "emails")
    s3_endpoint_url: str = os.getenv("S3_ENDPOINT_URL", "")

    # Error Handling
    max_retries: int = int(os.getenv("MAX_RETRIES", 3))
    use_mock_s3: bool = os.getenv("USE_MOCK_S3", "true").lower() == "true"

    # Logging
    log_level: str = os.getenv("LOG_LEVEL", "INFO")

    class Config:
        env_file = ".env"


settings = WorkerSettings()

