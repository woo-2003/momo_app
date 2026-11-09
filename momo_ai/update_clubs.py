import openai
import firebase_admin
from firebase_admin import credentials, firestore

# 1. Firebase & OpenAI 초기화
cred = credentials.Certificate("firebase-key.json")
firebase_admin.initialize_app(cred)
db = firestore.client()
openai.api_key = ""

# 2. 클럽 데이터 불러와서 벡터 업데이트하기
clubs = db.collection('clubs').stream()

for club in clubs:
    data = club.to_dict()
    desc = data.get('description')
    
    if desc:
        # OpenAI로 벡터 생성
        client = openai.OpenAI(api_key=openai.api_key)
        response = client.embeddings.create(input=desc, model="text-embedding-3-small")
        vector = response.data[0].embedding
        
        # Firestore 업데이트
        db.collection('clubs').document(club.id).update({'club_vector': vector})
        print(f"'{data['club_name']}' 벡터 저장 완료!")

print("모든 모임 데이터 업데이트 성공!")