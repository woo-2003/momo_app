import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
import firebase_admin
from firebase_admin import credentials, firestore

# 1. 파이어베이스 연결
cred = credentials.Certificate("firebase-key.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# 2. 파이어베이스에서 데이터 가져오기
user_doc = db.collection('users').document('test_user_01').get().to_dict()
user_vec = np.array(user_doc['preference_vector'])

club_list = []
club_vecs = []

clubs = db.collection('clubs').stream()
for club in clubs:
    data = club.to_dict()
    club_list.append(data['club_name'])
    club_vecs.append(data['club_vector']) # 파이어베이스에 저장된 숫자 리스트들

# 3. 드디어 아까 그 코드의 핵심 로직 실행
similarities = cosine_similarity([user_vec], club_vecs)

# 4. 결과 출력
for i, score in enumerate(similarities[0]):
    print(f"모임: {club_list[i]} | 유사도 점수: {score:.4f}")