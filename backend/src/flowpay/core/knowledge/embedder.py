"""嵌入服务：文本向量化"""

import httpx
from typing import List
import asyncio

class EmbeddingService:
    """Ollama 嵌入服务客户端"""
    
    def __init__(
        self,
        base_url: str = "http://127.0.0.1:11434/v1",
        model: str = "qwen3-embedding:0.6b",
        dimensions: int = 1024,
        timeout: float = 30.0
    ):
        """
        初始化嵌入服务
        
        Args:
            base_url: Ollama API 地址
            model: 嵌入模型名称
            dimensions: 向量维度
            timeout: 请求超时时间（秒）
        """
        self.base_url = base_url.rstrip('/')
        self.model = model
        self.dimensions = dimensions
        self.timeout = timeout
        self._client: httpx.AsyncClient | None = None
    
    async def _get_client(self) -> httpx.AsyncClient:
        """获取或创建 HTTP 客户端"""
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=self.timeout)
        return self._client
    
    async def embed_text(self, text: str) -> List[float]:
        """
        将单个文本转换为向量
        
        Args:
            text: 输入文本
            
        Returns:
            768 维向量
        """
        vectors = await self.embed_batch([text])
        return vectors[0]
    
    async def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """
        批量嵌入多个文本
        
        Args:
            texts: 文本列表
            
        Returns:
            向量列表，每个向量 768 维
            
        Raises:
            httpx.HTTPError: API 调用失败
            ValueError: 向量维度不匹配
        """
        if not texts:
            return []
        
        client = await self._get_client()
        url = f"{self.base_url}/embeddings"
        payload = {
            "model": self.model,
            "input": texts
        }
        
        response = await client.post(url, json=payload)
        response.raise_for_status()
        
        data = response.json()
        embeddings = [item["embedding"] for item in data["data"]]
        
        # 验证维度
        for i, emb in enumerate(embeddings):
            if len(emb) != self.dimensions:
                raise ValueError(
                    f"向量 {i} 维度不匹配: 期望 {self.dimensions}, 实际 {len(emb)}"
                )
        
        return embeddings
    
    async def close(self):
        """关闭 HTTP 客户端"""
        if self._client:
            await self._client.aclose()
            self._client = None
    
    async def __aenter__(self):
        """支持 async with 语法"""
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """自动关闭客户端"""
        await self.close()


# 同步包装器（可选）
class SyncEmbeddingService:
    """同步版本的嵌入服务"""
    
    def __init__(self, **kwargs):
        self._async_service = EmbeddingService(**kwargs)
    
    def embed_text(self, text: str) -> List[float]:
        """同步嵌入单个文本"""
        return asyncio.run(self._async_service.embed_text(text))
    
    def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """同步批量嵌入"""
        return asyncio.run(self._async_service.embed_batch(texts))
