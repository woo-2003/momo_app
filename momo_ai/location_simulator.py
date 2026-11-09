import time
from math import radians, sin, cos, sqrt, atan2
import firebase_admin
from firebase_admin import credentials, firestore

# 1. 파이어베이스 초기화 (이미 초기화되어 있다면 생략 가능)
if not firebase_admin._apps:
    cred = credentials.Certificate("firebase-key.json")
    firebase_admin.initialize_app(cred)
db = firestore.client()

# 하버사인 공식을 이용한 정확한 거리 계산 (단위: 미터)
def get_distance(lat1, lon1, lat2, lon2):
    R = 6371000  # 지구 반지름 (미터)
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c

# 이동 상태 판별 알고리즘
def check_movement_status(prev_lat, prev_lon, prev_time, curr_lat, curr_lon, curr_time, dest_lat, dest_lon):
    curr_dist_to_dest = get_distance(curr_lat, curr_lon, dest_lat, dest_lon)
    moved_distance = get_distance(prev_lat, prev_lon, curr_lat, curr_lon)
    time_diff = curr_time - prev_time
    
    if time_diff <= 0:
        return "STATIONARY", curr_dist_to_dest
        
    speed = moved_distance / time_diff  # m/s
    
    # GPS 튐 방지: 3미터 이상 이동했고 속도가 0.5 m/s 이상일 때
    if moved_distance > 3 and speed > 0.5:
        return "MOVING_TO_DEST", curr_dist_to_dest
    else:
        return "STATIONARY", curr_dist_to_dest

# ==========================================
# 2. 테스트 시뮬레이터 실행부
# ==========================================
def run_simulation():
    user_id = "test_user_01"
    user_ref = db.collection('users').document(user_id)
    
    # 목적지 좌표 설정 (예시: 서울의 특정 카페 좌표)
    dest_lat, dest_lon = 37.556, 126.923 
    
    # 시작 좌표 (목적지에서 살짝 떨어진 곳)
    curr_lat, curr_lon = 37.550, 126.920
    curr_time = time.time()
    
    print("🚀 위치 이동 시뮬레이션을 시작합니다!")
    
    # 5번 반복하며 서서히 목적지 쪽으로 좌표를 이동시킴
    for i in range(5):
        prev_lat, prev_lon, prev_time = curr_lat, curr_lon, curr_time
        
        # [시뮬레이션 조작] 위도를 목적지 방향으로 조금씩 이동시킴 (매번 약 200m 전진)
        curr_lat += 0.0018
        curr_lon += 0.0005
        curr_time = time.time()
        
        # 1. DB에 현재 위치 업데이트 (앱이 서버로 위치를 보내는 상황 모사)
        user_ref.set({
            "current_lat": curr_lat,
            "current_lon": curr_lon,
            "last_updated": curr_time
        }, merge=True)
        
        # 2. DB에서 데이터 다시 불러와서 알고리즘 테스트 (백엔드 로직 모사)
        user_data = user_ref.get().to_dict()
        
        if i == 0:
            # 첫 번째 스텝은 비교할 이전 데이터가 없으므로 패스
            print(f"[초기화] 현재 위치 저장 완료. 테스트를 진행합니다...")
            time.sleep(1)
            continue
            
        # 상태 판별 함수 실행
        status, distance_to_dest = check_movement_status(
            prev_lat, prev_lon, prev_time,
            user_data['current_lat'], user_data['current_lon'], user_data['last_updated'],
            dest_lat, dest_lon
        )
        
        print(f"👉 [테스트 Step {i}] 상태: {status} | 남은 목적지 거리: {distance_to_dest:.1f}m")
        time.sleep(1) # 1초 대기

    print("✅ 시뮬레이션이 종료되었습니다. 파이어베이스 콘솔에서 좌표 변화를 확인해보세요!")

if __name__ == "__main__":
    run_simulation()