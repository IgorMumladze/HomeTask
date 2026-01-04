from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field, field_validator
from datetime import datetime
import uuid
import logging
import json
import boto3
from typing import Optional, Dict, Any
from config import settings

# Configure logging
logging.basicConfig(level=settings.log_level)
logger = logging.getLogger(__name__)

# Initialize AWS SQS client (will use mock if configured)
if not settings.use_mock_sqs:
    sqs_client = boto3.client("sqs", region_name=settings.aws_region)


app = FastAPI(
    title="Email Ingestion API",
    version=settings.api_version,
    description="REST API for ingesting email data",
)


class EmailData(BaseModel):
    email_subject: str = Field(..., min_length=1, max_length=255)
    email_sender: str = Field(..., min_length=1, max_length=255)
    email_timestream: str = Field(..., description="Unix timestamp as string")
    email_content: str = Field(..., min_length=1, max_length=5000)

    @field_validator("email_timestream")
    def validate_timestamp(cls, v: str) -> str:
        try:
            timestamp = int(v)
        except ValueError:
            raise ValueError("email_timestream must be valid Unix timestamp (numeric string)")

        now = int(datetime.utcnow().timestamp())

        if timestamp > now:
            raise ValueError("email_timestream cannot be in the future")

        age_days = (now - timestamp) / (60 * 60 * 24)
        if age_days > settings.max_timestamp_age_days:
            raise ValueError(f"email_timestream cannot be older than {settings.max_timestamp_age_days} days")

        return v


class EmailRequest(BaseModel):
    data: EmailData
    token: str


class EmailResponse(BaseModel):
    status: str
    message_id: str
    timestamp: str
    queue_url: Optional[str] = None


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    timestamp: str
    sqs_available: bool


class ErrorResponse(BaseModel):
    status: str
    error_code: str
    message: str
    timestamp: str


class ConfigResponse(BaseModel):
    service_name: str
    api_version: str
    max_email_subject_length: int
    max_email_sender_length: int
    max_email_content_length: int
    max_timestamp_age_days: int


def verify_token(token: str) -> bool:
    return token == settings.api_token


def publish_to_sqs(message: Dict[str, Any], message_id: str) -> bool:
    try:
        if settings.use_mock_sqs:
            log_entry = {
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "operation": "SQS_MOCK_PUBLISH",
                "message_id": message_id,
                "sender": message.get("data", {}).get("email_sender"),
                "subject": message.get("data", {}).get("email_subject"),
                "body": message,
            }
            print("\n" + "=" * 80)
            print("SQS MESSAGE PUBLISHED (MOCK)")
            print("=" * 80)
            print(json.dumps(log_entry, indent=2))
            print("=" * 80 + "\n")
            logger.info(f"Mock SQS: Message published {message_id}")
            return True

        response = sqs_client.send_message(
            QueueUrl=settings.sqs_queue_url,
            MessageBody=json.dumps(message),
            MessageAttributes={
                "message_id": {"StringValue": message_id, "DataType": "String"},
                "sender": {"StringValue": message.get("data", {}).get("email_sender"), "DataType": "String"},
                "subject": {"StringValue": message.get("data", {}).get("email_subject"), "DataType": "String"},
            },
        )
        logger.info(f"Message published to SQS: {response.get('MessageId')}")
        return True

    except Exception as e:
        logger.error(f"Failed to publish message to SQS: {str(e)}")
        return False


@app.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(
        status="healthy",
        service="email-api",
        version=settings.api_version,
        timestamp=datetime.utcnow().isoformat() + "Z",
        sqs_available=not settings.use_mock_sqs,
    )


@app.get("/config", response_model=ConfigResponse)
async def get_config():
    return ConfigResponse(
        service_name="email-api",
        api_version=settings.api_version,
        max_email_subject_length=settings.max_email_subject_length,
        max_email_sender_length=settings.max_email_sender_length,
        max_email_content_length=settings.max_email_content_length,
        max_timestamp_age_days=settings.max_timestamp_age_days,
    )


@app.post("/send-email", response_model=EmailResponse, status_code=200)
async def send_email(request: EmailRequest):
    try:
        if not verify_token(request.token):
            logger.warning("Invalid token provided")
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication token")

        message_id = f"msg_{uuid.uuid4().hex[:16]}"
        timestamp = datetime.utcnow().isoformat() + "Z"

        sqs_message = {"message_id": message_id, "timestamp": timestamp, "data": request.data.model_dump()}

        if not publish_to_sqs(sqs_message, message_id):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to publish message to queue",
            )

        logger.info(f"Email received and queued: {message_id} from {request.data.email_sender}")

        return EmailResponse(
            status="accepted",
            message_id=message_id,
            timestamp=timestamp,
            queue_url=settings.sqs_queue_url if not settings.use_mock_sqs else None,
        )

    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Internal server error")


@app.exception_handler(ValueError)
async def value_error_handler(request, exc):
    return ErrorResponse(
        status="error",
        error_code="VALIDATION_ERROR",
        message=str(exc),
        timestamp=datetime.utcnow().isoformat() + "Z",
    )


if __name__ == "__main__":
    import uvicorn

    logger.info(f"Starting Email API on {settings.api_host}:{settings.api_port}")
    if settings.use_mock_sqs:
        logger.info("Using MOCK SQS (not connected to AWS)")
    logger.info("Token validation enabled")

    uvicorn.run(
        app,
        host=settings.api_host,
        port=settings.api_port,
        log_level=settings.log_level.lower(),
    )

