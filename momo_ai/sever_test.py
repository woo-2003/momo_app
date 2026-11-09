from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from math import radians, sin, cos, sqrt, atan2
import time
import firebase_admin
from firebase_admin import credentials, firestore

app = FastAPI()

# 1. 파이어베이스 초기화 (모임 참여 여부 검증 및 목적지 조회용)
if not firebase_admin._apps:
    try:
        cred = credentials.Certificate("firebase-key.json")
        firebase_admin.initialize_app(cred)
    except Exception:
        pass

db = firestore.client() if firebase_admin._apps else None

# 2. 앱(Flutter)에서 보내주는 데이터 형태 정의 (DTO) - 모임 및 유저 ID 추가
class LocationUpdateRequest(BaseModel):
    meetingId: str
    userId: str
    prev_lat: float
    prev_lon: float
    prev_time: float
    curr_lat: float
    curr_lon: float
    curr_time: float

# 모임방별 유저들의 실시간 위치를 관리할 메모리 저장소
meeting_room_storage = {}

# 하버사인 거리 계산 함수 (단위: 미터)
def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371000  # 지구 반지름
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c

# [API 엔드포인트 1] 모임 참여 검증 및 위치 데이터 수신 후 상태 계산 및 저장
@app.post("/meeting/location")
def update_meeting_location(data: LocationUpdateRequest):
    # 1. 파이어베이스를 통해 모임 참여 여부 및 목적지 좌표 가져오기
    if db:
        meeting_ref = db.collection('meetings').document(data.meetingId)
        meeting_doc = meeting_ref.get()
        if not meeting_doc.exists:
            raise HTTPException(status_code=404, detail="존재하지 않는 모임입니다.")
        
        meeting_data = meeting_doc.to_dict()
        dest_lat = meeting_data.get('latitude')
        dest_lon = meeting_data.get('longitude')
        
        if dest_lat is None or dest_lon is None:
            raise HTTPException(status_code=400, detail="모임의 목적지 좌표가 설정되지 않았습니다.")
    else:
        # 로컬 테스트용 기본 목적지 좌표 (Firebase 연결 전용)
        dest_lat = 37.5665
        dest_lon = 126.9780

    # 2. 목적지까지의 남은 거리 계산
    distance_to_dest = calculate_distance(data.curr_lat, data.curr_lon, dest_lat, dest_lon)

    # 3. 이동 거리 및 속도 계산
    moved_distance = calculate_distance(data.prev_lat, data.prev_lon, data.curr_lat, data.curr_lon)
    time_diff = data.curr_time - data.prev_time

    if time_diff <= 0:
        speed = 0.0
    else:
        speed = moved_distance / time_diff

    # 4. GPS 튐 방지 필터 및 목적지 도달(ARRIVED) 판별
    ARRIVAL_THRESHOLD = 15.0  # 목적지 반경 15미터 이내 도달

    if distance_to_dest <= ARRIVAL_THRESHOLD:
        status = "ARRIVED"
    elif moved_distance > 3 and speed > 0.5:
        status = "MOVING_TO_DEST"
    else:
        status = "STATIONARY"

    # 5. 모임방 메모리 저장소에 현재 유저의 위치 및 상태 반영
    if data.meetingId not in meeting_room_storage:
        meeting_room_storage[data.meetingId] = {}

    meeting_room_storage[data.meetingId][data.userId] = {
        "status": status,
        "curr_lat": data.curr_lat,
        "curr_lon": data.curr_lon,
        "distance_to_dest": round(distance_to_dest, 1),
        "speed": round(speed, 1),
        "updated_at": time.time()
    }

    # 앱으로 결과 반환
    return {
        "result": "success",
        "user_status": status,
        "distance_to_dest": round(distance_to_dest, 1),
        "speed": round(speed, 1)
    }

# [API 엔드포인트 2] 특정 모임방의 모든 멤버 위치 및 상태 조회 (앱 지도 렌더링용)
@app.get("/meeting/{meetingId}/members")
def get_meeting_members(meetingId: str):
    if meetingId not in meeting_room_storage or not meeting_room_storage[meetingId]:
        raise HTTPException(status_code=404, detail="해당 모임방에 접속 중인 유저가 없습니다.")
    
    return {
        "meetingId": meetingId,
        "members": meeting_room_storage[meetingId]
    }