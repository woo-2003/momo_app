import time
from math import radians, sin, cos, sqrt, atan2
import firebase_admin
from firebase_admin import credentials, firestore

# 1. 파이어베이스 초기화
if not firebase_admin._apps:
    cred = credentials.Certificate("firebase-key.json")
    firebase_admin.initialize_app(cred)
db = firestore.client()

# ==========================================
# [1단계] 하버사인 공식을 이용한 정확한 거리 계산 함수 (단위: 미터)
# ==========================================
def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371000  # 지구 반지름 (미터)
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c

# ==========================================
# [2단계] 이동 상태 판별 알고리즘 (위치 변화, 속도, 튐 방지 필터 적용)
# ==========================================
def evaluate_movement_status(prev_lat, prev_lon, prev_time, curr_lat, curr_lon, curr_time, dest_lat, dest_lon):
    # 목적지까지의 현재 남은 거리
    curr_dist_to_dest = calculate_distance(curr_lat, curr_lon, dest_lat, dest_lon)
    
    # 이전 위치와의 이동 거리 및 시간 차이 계산
    moved_distance = calculate_distance(prev_lat, prev_lon, curr_lat, curr_lon)
    time_diff = curr_time - prev_time
    
    if time_diff <= 0:
        return {"status": "STATIONARY", "distance_to_dest": curr_dist_to_dest, "speed": 0.0}
        
    speed = moved_distance / time_diff  # m/s 단위 속도
    
    # 방어 로직 (GPS 튐 방지: 최소 3미터 이상 이동했고, 속도가 도보/차량 수준일 때)
    if moved_distance > 3 and speed > 0.5:
        status = "MOVING_TO_DEST"
    else:
        status = "STATIONARY"
        
    return {
        "status": status,
        "distance_to_dest": curr_dist_to_dest,
        "speed": speed
    }

# ==========================================
# [실전 적용 함수] DB 데이터를 읽어와서 상태를 판별하고 갱신하는 메인 로직
# ==========================================
def process_user_location(user_id, dest_lat, dest_lon):
    user_ref = db.collection('users').document(user_id)
    user_doc = user_ref.get()
    
    if not user_doc.exists:
        print(f"❌ 유저 ID [{user_id}]를 찾을 수 없습니다.")
        return
        
    data = user_doc.to_dict()
    
    # DB에 저장되어 있는 현재 위치 및 직전 위치 정보 가져오기
    curr_lat = data.get('current_lat')
    curr_lon = data.get('current_lon')
    curr_time = data.get('last_updated', time.time())
    
    prev_lat = data.get('prev_lat', curr_lat)
    prev_lon = data.get('prev_lon', curr_lon)
    prev_time = data.get('prev_time', curr_time)
    
    # 데이터가 부족한 경우 처리
    if curr_lat is None or curr_lon is None:
        print("⚠️ 유저의 현재 좌표 데이터가 존재하지 않습니다.")
        return

    # 이동 상태 판별 함수 호출
    result = evaluate_movement_status(
        prev_lat, prev_lon, prev_time,
        curr_lat, curr_lon, curr_time,
        dest_lat, dest_lon
    )
    
    # 판별된 결과를 다시 DB에 업데이트 (상태 및 남은 거리 반영)
    user_ref.update({
        "movement_status": result["status"],
        "distance_to_dest": result["distance_to_dest"],
        "current_speed": result["speed"]
    })
    
    print(f"🔄 [업데이트 완료] 유저: {user_id} | 상태: {result['status']} | 남은 거리: {result['distance_to_dest']:.1f}m | 속도: {result['speed']:.1f}m/s")
    return result

if __name__ == "__main__":
    # 예시 실행: 특정 유저 ID와 목적지 좌표를 넣고 함수 호출
    # (실제 앱에서 사용자의 위치가 DB에 갱신될 때 이 함수를 백엔드에서 호출하면 됩니다)
    target_user_id = "test_user_01"
    destination_lat = 37.556
    destination_lon = 126.923
    
    process_user_location(target_user_id, destination_lat, destination_lon)