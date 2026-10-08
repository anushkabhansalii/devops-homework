from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "TaskBoard API"
    app_version: str = "dev"          # set to the git SHA by the image build
    environment: str = "local"        # local / dev / prod (from the ConfigMap in Kubernetes)
    database_url: str = "postgresql+psycopg://taskboard:taskboard@localhost:5432/taskboard"
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
