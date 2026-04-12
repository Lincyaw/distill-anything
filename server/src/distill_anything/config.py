from pathlib import Path

from pydantic import BaseModel


class Settings(BaseModel):
    """Application settings."""

    storage_root: Path = Path("data/raw")
    database_url: str = "sqlite+aiosqlite:///data/distill.db"
    knowledge_base_root: Path = Path("data/knowledge_base")
    host: str = "0.0.0.0"
    port: int = 8000

    # Conversion settings
    funasr_model: str = "paraformer-zh"
    vision_model: str = "qwen-vl-chat"
    llm_model: str = "qwen2.5"
    llm_base_url: str = "http://localhost:11434/v1"


settings = Settings()
