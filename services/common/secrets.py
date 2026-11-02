"""Reads secrets from Secret Manager. Credentials come from Workload Identity."""

from google.cloud import secretmanager


def read_secret(project_id: str, secret_id: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
    return client.access_secret_version(name=name).payload.data.decode()
