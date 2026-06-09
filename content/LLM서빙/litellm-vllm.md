# LiteLLM & vLLM - LLM 서빙 스택

## 개념 구분

| | LiteLLM | vLLM |
|--|--|--|
| **역할** | 여러 LLM API를 감싸는 통합 인터페이스 | LLM 추론과 서빙을 최적화하는 엔진 |
| **레이어** | 애플리케이션 레이어 | 인프라 레이어 |
| **쓰는 이유** | 코드 변경 없이 provider 교체 | GPU 처리량 극대화 (PagedAttention 등) |
| **GPU 필요** | 불필요 (클라우드 API 호출) | 필요 (로컬 추론) |

## 아키텍처

```
클라이언트
    ↓
LiteLLM (통합 인터페이스)
    ↓              ↓              ↓
vLLM 서버    OpenAI API    HuggingFace API
(로컬)       (클라우드)     (클라우드)
```

LiteLLM의 핵심: **어디서 모델을 가져오든 동일한 코드로 호출 가능**

## vLLM 서버 실행 (GPU 환경)

```bash
# GPU 있을 때
pip install vllm
python -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2.5-0.5B-Instruct \
  --port 8000
```

## vLLM 서버 실행 (CPU 환경 - WSL2)

CPU-only 환경에서 vLLM은 **소스 빌드 필요** (PyPI wheel은 CUDA 컴파일됨)

### 필요 조건
- gcc/g++ >= 12.3
- cmake, ninja-build
- torch CPU 버전 (PyTorch 공식 인덱스에서)
- python3-dev

### 설치 순서

```bash
# 1. 시스템 의존성
sudo apt install gcc-12 g++-12 cmake ninja-build python3-dev

# 2. torch CPU 버전 (PyPI가 아닌 PyTorch 인덱스)
pip install "torch==2.11.0" --extra-index-url https://download.pytorch.org/whl/cpu

# 3. 빌드 도구
pip install ninja setuptools_rust setuptools_scm packaging wheel

# 4. vLLM 소스 빌드
git clone https://github.com/vllm-project/vllm.git
cd vllm
export CC=/usr/bin/gcc-12
export CXX=/usr/bin/g++-12
VLLM_TARGET_DEVICE=cpu pip install -v . --no-build-isolation \
  --extra-index-url https://download.pytorch.org/whl/cpu
```

### 삽질 포인트

- `libcuda.so.1 not found` → PyPI wheel은 CUDA 전용, 소스 빌드 필요
- `float8_e8m0fnu` 없음 → torch 버전이 낮음 (2.5+ 필요)
- `ninja not found` → cmake 캐시 문제. `rm -rf build/ .deps/ CMakeCache.txt CMakeFiles/`
- `gcc >= 12.3 required` → `sudo apt install gcc-12 g++-12` 후 CC/CXX 환경변수 설정
- `CMAKE_ARGS` 공백 파싱 → setup.py가 `.split()`으로 처리. 대신 CC/CXX 직접 설정

## LiteLLM으로 vLLM 서버 호출

```python
import litellm

response = litellm.completion(
    model="openai/Qwen2.5-0.5B-Instruct",  # openai/ 접두사 필수
    messages=[{"role": "user", "content": "안녕?"}],
    api_base="http://localhost:8000/v1",
    api_key="fake-key"  # vLLM은 키 불필요하지만 litellm이 요구
)
print(response.choices[0].message.content)
```

vLLM은 OpenAI 호환 API를 제공 → LiteLLM이 OpenAI처럼 호출 가능

## 왜 함께 쓰나?

- **vLLM만**: 직접 HTTP 호출, provider 교체 시 코드 변경 필요
- **LiteLLM만**: 로컬 추론 최적화 없음
- **둘 다**: 로컬 고성능 서빙 + 멀티 provider 통합 인터페이스
