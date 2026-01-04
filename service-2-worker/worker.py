import logging
import json
import os
import signal
import time
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional
import boto3
from config import settings

# Configure logging
logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

class S3Uploader:
    """Handle S3 uploads"""

    def __init__(self, settings):
        self.settings = settings
        endpoint = settings.s3_endpoint_url or None
        self.s3_client = boto3.client("s3", region_name=settings.aws_region, endpoint_url=endpoint)

    def upload_email(self, email_data: Dict[str, Any], message_id: str) -> bool:
        """
        Upload email to S3

        Path structure: emails/YYYY/MM/DD/message_id.json
        """
        try:
            now = datetime.utcnow()
            s3_key = f"{settings.s3_bucket_prefix}/{now.year}/{now.month:02d}/{now.day:02d}/{message_id}.json"

            if settings.use_mock_s3:
                local_path = Path("./uploads") / s3_key.replace("/", os.sep)
                local_path.parent.mkdir(parents=True, exist_ok=True)

                with open(local_path, "w") as f:
                    json.dump(email_data, f, indent=2)

                logger.info(f"S3 MOCK: Uploaded to {s3_key} ({local_path})")
                print(f"[S3_MOCK] Uploaded: {s3_key}")
                return True

            self.s3_client.put_object(
                Bucket=self.settings.s3_bucket_name,
                Key=s3_key,
                Body=json.dumps(email_data, indent=2),
                ContentType="application/json",
            )
            logger.info(f"S3: Email uploaded to s3://{self.settings.s3_bucket_name}/{s3_key}")
            return True

        except Exception as e:
            logger.error(f"Failed to upload to S3: {str(e)}")
            return False


class SQSConsumer:
    """Handle SQS message consumption"""

    def __init__(self, settings):
        self.settings = settings
        endpoint = settings.sqs_endpoint_url or None
        self.sqs_client = (
            None
            if settings.use_mock_sqs
            else boto3.client("sqs", region_name=settings.aws_region, endpoint_url=endpoint)
        )

    def receive_messages(self, max_messages: int = 10) -> list:
        if self.settings.use_mock_sqs:
            logger.debug("USE_MOCK_SQS enabled: skipping receive_messages")
            return []
        try:
            response = self.sqs_client.receive_message(
                QueueUrl=self.settings.sqs_queue_url,
                MaxNumberOfMessages=min(max_messages, self.settings.max_messages_per_poll),
                WaitTimeSeconds=20,
                MessageAttributeNames=["All"],
            )

            return response.get("Messages", [])

        except Exception as e:
            logger.error(f"Failed to receive messages from SQS: {str(e)}")
            return []

    def delete_message(self, message: Dict[str, Any]) -> bool:
        if self.settings.use_mock_sqs:
            logger.debug("USE_MOCK_SQS enabled: skipping delete_message")
            return True
        try:
            self.sqs_client.delete_message(
                QueueUrl=self.settings.sqs_queue_url,
                ReceiptHandle=message["ReceiptHandle"],
            )
            logger.debug("Message deleted from SQS")
            return True

        except Exception as e:
            logger.error(f"Failed to delete message: {str(e)}")
            return False

    def send_to_dlq(self, message: Dict[str, Any], error: str):
        if self.settings.use_mock_sqs:
            logger.error(f"USE_MOCK_SQS enabled: DLQ send skipped for message: {error}")
            return
        try:
            dlq_message = {
                "original_message": message.get("Body"),
                "error": error,
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }

            self.sqs_client.send_message(
                QueueUrl=self.settings.dlq_queue_url,
                MessageBody=json.dumps(dlq_message),
            )
            logger.error(f"Message sent to DLQ: {error}")

        except Exception as e:
            logger.error(f"Failed to send message to DLQ: {str(e)}")


class EmailWorker:
    """Main worker process"""

    def __init__(self):
        self.sqs = SQSConsumer(settings)
        self.s3 = S3Uploader(settings)
        self.running = True
        self.messages_processed = 0
        self.messages_failed = 0
        self.start_time = datetime.utcnow()
        self.last_processed_id = None

        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)

    def _handle_signal(self, signum, frame):
        logger.info(f"Received signal {signum}. Shutting down gracefully...")
        self.running = False

    def _process_message(self, message: Dict[str, Any]) -> bool:
        try:
            body = json.loads(message["Body"])
            message_id = body.get("message_id", "unknown")

            logger.info(f"Processing message: {message_id}")

            if self.s3.upload_email(body, message_id):
                if self.sqs.delete_message(message):
                    self.messages_processed += 1
                    self.last_processed_id = message_id
                    logger.info(f"Message processed successfully: {message_id}")
                    return True

                logger.warning("Message uploaded but failed to delete from queue")
                return False

            logger.error(f"Failed to upload message to S3: {message_id}")
            return False

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse SQS message: {str(e)}")
            self.messages_failed += 1
            self.sqs.send_to_dlq(message, f"Invalid JSON: {str(e)}")
            return False

        except Exception as e:
            logger.error(f"Error processing message: {str(e)}")
            self.messages_failed += 1
            self.sqs.send_to_dlq(message, f"Processing error: {str(e)}")
            return False

    def _write_health_check(self):
        try:
            uptime = (datetime.utcnow() - self.start_time).total_seconds()

            health_data = {
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "status": "running",
                "messages_processed": self.messages_processed,
                "messages_failed": self.messages_failed,
                "last_processed_id": self.last_processed_id,
                "uptime_seconds": int(uptime),
            }

            health_file = Path("./health") / "worker-status.json"
            health_file.parent.mkdir(exist_ok=True)

            with open(health_file, "w") as f:
                json.dump(health_data, f, indent=2)

            logger.debug(f"Health check written: {self.messages_processed} processed")

        except Exception as e:
            logger.error(f"Failed to write health check: {str(e)}")

    def run(self):
        logger.info("=== Email Worker Starting ===")
        logger.info(f"Poll interval: {settings.poll_interval_seconds}s")
        logger.info(f"SQS Queue: {settings.sqs_queue_url}")
        logger.info(f"S3 Bucket: {settings.s3_bucket_name}")

        health_check_interval = 30
        last_health_check = time.time()

        while self.running:
            try:
                current_time = time.time()

                logger.debug("Polling SQS for messages...")
                messages = self.sqs.receive_messages(settings.max_messages_per_poll)

                if messages:
                    logger.info(f"Received {len(messages)} message(s)")
                    for message in messages:
                        self._process_message(message)
                else:
                    logger.debug("No messages available")

                if current_time - last_health_check >= health_check_interval:
                    self._write_health_check()
                    last_health_check = current_time

                time.sleep(settings.poll_interval_seconds)

            except Exception as e:
                logger.error(f"Error in worker loop: {str(e)}")
                time.sleep(settings.poll_interval_seconds)

        self._write_health_check()
        logger.info("=== Email Worker Stopped ===")
        logger.info(f"Total processed: {self.messages_processed}")
        logger.info(f"Total failed: {self.messages_failed}")


if __name__ == "__main__":
    try:
        worker = EmailWorker()
        worker.run()

    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
        sys.exit(0)

    except Exception as e:
        logger.error(f"Fatal error: {str(e)}")
        sys.exit(1)

