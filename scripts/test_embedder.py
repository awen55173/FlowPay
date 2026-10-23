"""测试嵌入服务封装"""

import asyncio
import sys
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass
import numpy as np
from backend.src.flowpay.core.knowledge.embedder import EmbeddingService

async def test_embedder():
    """测试嵌入服务"""
    
    print("="*60)
    print("嵌入服务封装测试")
    print("="*60)
    
    # 创建服务实例
    async with EmbeddingService() as embedder:
        
        # 测试 1: 单个文本
        print("\n[测试 1] 单个文本嵌入")
        text = "FlowPay 是一个支付平台"
        vector = await embedder.embed_text(text)
        
        print(f"  文本: {text}")
        print(f"  向量维度: {len(vector)}")
        print(f"  前 5 维: {vector[:5]}")
        assert len(vector) == 1024
        print("  ✓ 通过")
        
        # 测试 2: 批量嵌入
        print("\n[测试 2] 批量嵌入")
        texts = [
            "支付成功",
            "退款失败", 
            "订阅续费"
        ]
        vectors = await embedder.embed_batch(texts)
        
        print(f"  文本数: {len(texts)}")
        print(f"  向量数: {len(vectors)}")
        assert len(vectors) == len(texts)
        print("  ✓ 通过")
        
        # 测试 3: 语义相似度
        print("\n[测试 3] 语义相似度计算")
        
        vec1 = await embedder.embed_text("支付成功")
        vec2 = await embedder.embed_text("支付完成")
        vec3 = await embedder.embed_text("退款申请")
        
        # 计算余弦相似度
        def cosine_similarity(a, b):
            a = np.array(a)
            b = np.array(b)
            return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))
        
        sim_12 = cosine_similarity(vec1, vec2)
        sim_13 = cosine_similarity(vec1, vec3)
        
        print(f"  '支付成功' vs '支付完成': {sim_12:.4f}")
        print(f"  '支付成功' vs '退款申请': {sim_13:.4f}")
        
        assert sim_12 > sim_13, "语义相近的文本应该有更高的相似度"
        print("  ✓ 语义相似度正确")
        
        # 测试 4: 空输入处理
        print("\n[测试 4] 边界情况")
        empty_result = await embedder.embed_batch([])
        assert empty_result == []
        print("  空列表: ✓")
        
        single_result = await embedder.embed_batch(["单个"])
        assert len(single_result) == 1
        print("  单个元素: ✓")
    
    print("\n" + "="*60)
    print("✓ 嵌入服务封装测试全部通过")
    print("="*60)

if __name__ == "__main__":
    asyncio.run(test_embedder())
