---
aliases:
  - |-
    7장 분산시스템을위한유일 ID 생성기설계
    8장 URL 단축기설계
---
# 7장 분산 시스템을 위한 유일 ID 생성기 설계

## 1단계 문제 이해 및 설계 범위 확정

### 요구사항

- ID는 유일 해야한다. 숫자로만 구성되어야 한다. 64비트로 표현될 수 있는 값이어야 한다. 발급 날짜에 따라 정렬 가능해야 한다.
- 초당 10_000개의 ID를 만들 수 있어야 한다.

## 2단계 개략적 설계안 제시 및 동의 구하기

### 다중 마스터 복제 (multi-master replication)

- 데이터베이스의 `auto_increment` 기능을 활용하는 것. 다음 ID의 값을 구할때, k만큼 증가.

![image.png](attachment:b6834e08-d4f4-4c6a-82e8-75bad5026b38:image.png)

**단점**

- 여러 데이터 센터에 걸쳐 규모를 늘리기 어렵다.
- ID의 유일성은 보장되겠지만 그 값이 시간 흐름에 맞춰 커지도록 보장할 수는 없다.
- 서버를 추가하거나 삭제할 때도 잘 동작하도록 만들기 어렵다.

### UUID

- 각 웹서버에서 별도의 ID 생성기를 사용해 독립적으로 ID를 만들어냄.

![image.png](attachment:ad664c9e-3a19-40ce-9337-c2f4c72e3728:image.png)

**장점**

- UUID를 만드는 것은 단순하다. 서버 사이의 종률이 필요 없으므로 동기화 이슈도 없다.
- 각 서버가 자기가 쓸 ID를 알아서 만드는 구조이므로 규모 확장도 쉽다.

**단점**

- ID가 길다 (128bit). 이번 장에서 다루는 것은 64bit.
- ID를 시간순으로 정렬할 수 없다. (UUIDv7은 타임이 들어감)
- ID에 숫자(numeric)아니 값이 포함될 수 있다.

### 티켓 서버 (ticket server)

- 중앙 집중형으로 `auto_increment` 기능을 갖춘 데이터베이스 서버를 사용하는 것.

![image.png](attachment:51f71f87-ad87-49a1-ab1b-40c88cd36d80:image.png)

**장점**

- 유일성이 보장되는 오직 숫자로만 구성된 ID를 쉽게 만들 수 있다.
- 구현하기 쉽고, 중소 규모 애플리케이션에 적합하다.

**단점**

- 티켓 서버가 SPOF(Single-Point-of-Failure)

### 트위터 스노플레이크 접근법

- 스노플레이크(snowflake)라고 부르는 독창적인 ID 생성 기법을 의미한다.

![image.png](attachment:fba3524c-e3ec-43e7-b7f0-a95f0a89343d:image.png)

- ID 구조
    - sign: 1 bit. 나중에 구분을 위해서 남겨둠.
    - timestamp: 41 bit. epoch(기원 시각) 이후 밀리초 단위에 대해서 남김.
    - 데이터센터 ID: 5 bit.
    - 서버 ID: 5 bit.
    - 일련번호: 12 bit. ID 생성때마다 1만큼 증가. 1ms가 경과할 떄마다 0으로 초기화.

## 3단계 상세 설계

**타임 스템프**

- 시간이 흐름에 따라 점점 큰 값을 가지게 되어 시간순으로 정렬이 가능해짐.

**일련번호**

- 같은 서버에서 밀리초 동안 하나 이상의 ID를 만들어 낸 경우에만 0보다 큰 값을 갖게 된다.

## 4단계 마무리

**추가 논의사항**

- 시계 동기화 (clock synchronization): NTP(Network Time Protocol)을 이용하면 된다.
- 각 section의 길이 최적화
    - 동시성이 낮고 수명이 긴 애플리케이션이라면 일련번호 절의 길이를 줄이고 타임 스템프 절의 길이를 늘리는 것이 효과적일 수 있다.
- 고가용성(high availability): ID 생성기는 필수 불가결(mission critical) 컴포넌트이므로 아주 높은 가용성을 제공해야한다.

# 8장 URL 단축기 설계

## 1단계 문자 이해 및 설계 범위 확정

- 쓰기 연산: 매일 1억 개의 단축 URL 생성
- 초당 쓰기 연산: 1억 / 24 / 3600 = 1160
- 읽기 연산: `읽기:쓰기` = `10:1` => 읽기 연산은 초당 11600
- 10년 운영시 3650억 개의 레코드를 보관
- 축약전 URL의 평균 길이: 100
- 10년동안 필요한 저장 용량: 36.5TB

## 2단계 개략적 설계안 제시 및 동의 구하기

### API 엔드포인트

1. URL 단축용 엔드포인트

- `POST /api/v1/data/shorten`
    - 인자: `{longUrl: longURLstring}`
    - 반환: 단축 URL

1. URL 디리렉션용 엔드포인트

- `GET /api/v1/shortUrl`
    - 반환: HTTP 리디렉션 목적지가 될 원래 URL

### URL 리디렉션

![image.png](attachment:572810c0-ed6e-4628-8035-f336e9276a32:image.png)

입력된 URL에 매칭되는 원래 URL로 바꾸어서 301이나 302로 응답을 넣어서 동작하게된다.

- 301 Permanently Move 응답
    - 해당 URL에 대한 HTTP 요청 처리 책임이 영구적으로 Location 헤더에 반환된 URL로 이전되었다는 응답.
    - 영구적으로 이전되었으므로, 브라우저는 이 응답을 캐시하여 사용하게 된다.
- 302 Found 응답
    - 주어진 URL로의 요청이 '일시적으로' Location 헤더가 지정하는 URL에 의해 처리되어야 한다는 응답.
    - 클라이언트에서는 언제나 단축 URL 서버에 먼저 보내진 후에 원래 URL로 리디렉션 되어야 한다.

### URL 단축 플로

URL을 해시값으로 대응할 수 있는 함수를 찾는것이 중요하다.

해시 함수에서 만족되어야하는 요구사항

- 입력으로 주어지는 긴 URL이 다른 값이면 해시 값도 달라야 한다.
- 계산된 해시 값은 원래 입력으로 주어졌던 긴 URL로 복원될 수 있어야 한다.

## 3단계 상세 설계

### 데이터 모델

RDB에 <단축 URL, 원래 URL> 순서쌍을 저장. 컬럼은 `id`, `shortURL`, `longURL`

### 해시 함수

- hashValue: 해시 함수가 계산하는 단축 URL 값

**해시 값 길이**

`[0-9,a-z,A-Z]` 의 문자로 구성되며, 개수는 62개 3650개의 URL을 만들어 낼 수 있어야 하기에 62^7 개 정도면 가능하다. 따라서 `len(hashValue) = 7`

**충돌 해소 방법**

**1. 해시 후 충돌 해소**

![image.png](attachment:7d035775-8095-46d1-bbcb-3b34c0350fd3:image.png)

해시 함수를 이용하여 결과값을 저장한다. 충돌이 일어날 경우, 사전에 정의한 문자열을 해시 값에 덧붙여 피한다.

**2. base-62 변환**

62진법으로 변경하여 데이터를 저장하는 것.

### URL 단축기 상세 설계

![image.png](attachment:632a6089-8df4-4c5a-a7de-acfd686e6afb:image.png)

### URL 리디렉션 상세 설계

![image.png](attachment:283e1526-1558-4ca7-bf03-64eb6b0d1d8d:image.png)

- 이런건가여..?
    
    ![image.png](attachment:840aad5a-24ac-4e41-ba2e-86adb6413457:image.png)
    

## 4단계 마무리

**더 이야기할만한 것들**

- 처리율 제한 장치
- 웹 서버 규모 확장
- 데이터베이스의 규모 확장
- 데이터 분석 솔루션
- 가용성, 데이터 일관성, 안정성

### 상세 구현 사례

[https://velog.io/@yarogono/Java-Spring-shorten-URL-직접-구현해보자](https://velog.io/@yarogono/Java-Spring-shorten-URL-%EC%A7%81%EC%A0%91-%EA%B5%AC%ED%98%84%ED%95%B4%EB%B3%B4%EC%9E%90)

[](https://velog.io/@yarogono/Java-Spring-shorten-URL-%EC%A7%81%EC%A0%91-%EA%B5%AC%ED%98%84%ED%95%B4%EB%B3%B4%EC%9E%90)[https://velog.io/@yarogono/Java-Spring-shorten-URL-직접-구현해보자](https://velog.io/@yarogono/Java-Spring-shorten-URL-%EC%A7%81%EC%A0%91-%EA%B5%AC%ED%98%84%ED%95%B4%EB%B3%B4%EC%9E%90)url이 항상 살아있는게 보장되지 않음!

비틀리?라는 곳이 url을 지우는 작업을 함 [https://bitly.com/](https://bitly.com/)