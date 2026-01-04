import os
import sys
import time
import boto3


def main():
    cluster = os.environ["CLUSTER_NAME"]
    services = os.environ["SERVICES"].split(",")
    timeout = int(os.environ.get("HEALTH_TIMEOUT", "360"))
    sleep = 10
    region = os.environ.get("AWS_REGION")

    ecs = boto3.client("ecs", region_name=region)
    start = time.time()

    def healthy():
        resp = ecs.describe_services(cluster=cluster, services=services)
        ok = True
        for svc in resp.get("services", []):
            name = svc.get("serviceName")
            deployments = svc.get("deployments", [])
            primary = next((d for d in deployments if d.get("status") == "PRIMARY"), None)
            if not primary:
                ok = False
                print(f"{name}: no PRIMARY deployment")
                continue
            desired = primary.get("desiredCount", 0)
            running = primary.get("runningCount", 0)
            failed = primary.get("failedTasks", 0)
            if desired == running and failed == 0:
                print(f"{name}: healthy (desired={desired}, running={running}, failed={failed})")
            else:
                ok = False
                print(f"{name}: unhealthy (desired={desired}, running={running}, failed={failed})")
        return ok

    while time.time() - start < timeout:
        if healthy():
            return 0
        time.sleep(sleep)

    print("Health check timed out")
    return 1


if __name__ == "__main__":
    sys.exit(main())

