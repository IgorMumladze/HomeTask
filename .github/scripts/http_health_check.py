import os
import sys
import time
import json
import logging
import urllib.request

logging.basicConfig(level=logging.INFO, format="%(levelname)s\t%(message)s")
log = logging.getLogger("http-health-check")


def fetch(url, timeout):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read().decode("utf-8")
        status = resp.getcode()
    return status, body


def check_endpoint(url, per_request_timeout):
    try:
        status, body = fetch(url, per_request_timeout)
        if status != 200:
            log.warning("Endpoint %s returned %s", url, status)
            return False
        # try json parse for optional status/healthy fields
        try:
            data = json.loads(body)
            if isinstance(data, dict):
                if "status" in data and data["status"] not in ("healthy", "ok", "accepted"):
                    log.warning("Endpoint %s json status not healthy: %s", url, data.get("status"))
                    return False
        except Exception:
            pass
        log.info("Endpoint %s is healthy", url)
        return True
    except Exception as e:
        log.warning("Endpoint %s check failed: %s", url, e)
        return False


def main():
    endpoints = os.environ.get("HEALTH_ENDPOINTS", "").replace(" ", "").split(",")
    endpoints = [e for e in endpoints if e]
    if not endpoints:
        log.info("No endpoints provided; skipping health check.")
        return 0

    timeout = int(os.environ.get("HEALTH_TIMEOUT", "360"))
    per_request_timeout = int(os.environ.get("HEALTH_PER_REQUEST_TIMEOUT", "10"))
    min_success = int(os.environ.get("HEALTH_MIN_SUCCESS", "1"))  # number of consecutive passes

    start = time.time()
    consecutive = 0
    while time.time() - start < timeout:
        all_ok = True
        for url in endpoints:
            if not check_endpoint(url, per_request_timeout):
                all_ok = False
        if all_ok:
            consecutive += 1
            if consecutive >= min_success:
                log.info("All endpoints healthy.")
                return 0
        else:
            consecutive = 0
        time.sleep(10)

    log.error("Health check timed out after %ss", timeout)
    return 1


if __name__ == "__main__":
    sys.exit(main())

