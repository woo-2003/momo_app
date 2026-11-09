import openai
from firebase_admin import credentials, firestore, initialize_app

cred = credentials.Certificate("firebase-key.json")
initialize_app(cred)
db = firestore.client()
openai.api_key = ""

# 2. 벡터 변환 함수
def get_embedding(text):
    client = openai.OpenAI(api_key=openai.api_key)
    response = client.embeddings.create(input=text, model="text-embedding-3-small")
    return response.data[0].embedding

# 3. 데이터 저장
user_id = "test_user_01"
user_answer = "나는 조용한 카페에서 책 읽는 걸 좋아해."
vector = get_embedding(user_answer)

db.collection('users').document(user_id).set({
    'answer': user_answer,
    'preference_vector': vector
})

print("데이터 저장 성공!")