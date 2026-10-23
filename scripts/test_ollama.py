"""测试 Ollama 嵌入服务"""

import httpx
import json

# Ollama API 端点（容器内部端口）
BASE_URL = "http://127.0.0.1:11434/v1"
MODEL = "qwen3-embedding:0.6b"

def test_ollama_embedding():
    """测试嵌入 API"""
    
    print("="*60)
    print("Ollama 嵌入服务测试")
    print("="*60)
    
    # 测试文本
    test_texts = [
        "FlowPay 支付平台",
        "Webhook 重试策略",
        "API 版本控制"
    ]
    
    print(f"\n测试模型: {MODEL}")
    print(f"API 地址: {BASE_URL}")
    print(f"\n测试文本数量: {len(test_texts)}")
    
    # 调用嵌入 API
    url = f"{BASE_URL}/embeddings"
    payload = {
        "model": MODEL,
        "input": test_texts
    }
    
    print(f"\n正在调用 API...")
    
    try:
        response = httpx.post(url, json=payload, timeout=30.0)
        response.raise_for_status()
        
        data = response.json()
        
        # 解析结果
        embeddings = data.get("data", [])
        print(f"✓ 成功获取 {len(embeddings)} 个向量\n")
        
        # 检查每个向量
        for i, item in enumerate(embeddings):
            embedding = item["embedding"]
            print(f"[{i+1}] 文本: {test_texts[i]}")
            print(f"    向量维度: {len(embedding)}")
            print(f"    前 5 维: {embedding[:5]}")
            print(f"    范数: {sum(x**2 for x in embedding)**0.5:.4f}")
            
            # 验证维度
            assert len(embedding) == 1024, f"维度错误: 期望 1024，实际 {len(embedding)}"
        
        print("\n✓ Ollama 嵌入服务正常工作！")
        return True
        
    except httpx.HTTPError as e:
        print(f"\n✗ HTTP 错误: {e}")
        return False
    except Exception as e:
        print(f"\n✗ 异常: {e}")
        return False

if __name__ == "__main__":
    success = test_ollama_embedding()
    exit(0 if success else 1)
