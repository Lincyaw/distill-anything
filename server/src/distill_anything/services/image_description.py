"""Image description via vision model."""

import asyncio
import base64
import logging
from pathlib import Path

from ..config import settings
from ..models.processing import ImageDescriptionResult

logger = logging.getLogger(__name__)


class ImageDescriptionService:
    """Generate text descriptions of images using a vision model."""

    def __init__(self, model_name: str | None = None) -> None:
        self.model_name = model_name or settings.vision_model
        self.base_url = settings.llm_base_url
        self._client = None

    def _get_client(self):
        if self._client is None:
            from openai import AsyncOpenAI
            self._client = AsyncOpenAI(base_url=self.base_url, api_key="not-needed")
        return self._client

    async def describe(self, image_path: Path, event_id: str) -> ImageDescriptionResult:
        """Generate a text description of an image."""
        client = self._get_client()

        image_data = await asyncio.to_thread(image_path.read_bytes)
        base64_image = base64.b64encode(image_data).decode("utf-8")
        suffix = image_path.suffix.lstrip(".").lower()
        mime_type = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png"}.get(
            suffix, "image/jpeg"
        )

        response = await client.chat.completions.create(
            model=self.model_name,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": (
                                "请详细描述这张图片的内容，包括场景、人物、物体、文字等信息。"
                                "用中文回答。"
                            ),
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{base64_image}",
                            },
                        },
                    ],
                }
            ],
            max_tokens=500,
        )

        description = response.choices[0].message.content or ""
        tags = self._extract_tags(description)

        return ImageDescriptionResult(
            event_id=event_id,
            description=description,
            tags=tags,
        )

    @staticmethod
    def _extract_tags(text: str) -> list[str]:
        """Extract simple keyword tags from description text."""
        keywords = []
        for word in text.replace("，", " ").replace("。", " ").replace("、", " ").split():
            if len(word) >= 2 and word not in ("这张", "图片", "可以", "看到", "一个", "一张"):
                keywords.append(word)
        return keywords[:10]
