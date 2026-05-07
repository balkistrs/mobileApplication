from flask import Flask, request, jsonify
from flask_cors import CORS
import cv2
import numpy as np
from deepface import DeepFace
import base64
import os

app = Flask(__name__)
CORS(app)

# Charger le classificateur de visage
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

# Base de données des plats avec recommandations
menu_recommendations = {
    'happy': [
        {'name': 'Poulet Braisé', 'reason': 'Un plat festif pour célébrer votre bonne humeur !'},
        {'name': 'Thieboudienne', 'reason': 'Le plat traditionnel qui met tout le monde d\'accord'},
        {'name': 'Dégui', 'reason': 'Un dessert doux pour accompagner votre joie'}
    ],
    'sad': [
        {'name': 'Mafé', 'reason': 'Un plat réconfortant qui réchauffe le cœur'},
        {'name': 'Yassa Poulet', 'reason': 'Des saveurs qui remontent le moral'},
        {'name': 'Glace artisanale', 'reason': 'Un remontant sucré pour adoucir la journée'}
    ],
    'angry': [
        {'name': 'Poulet Braisé', 'reason': 'Du piquant pour canaliser votre énergie'},
        {'name': 'Brochettes de Bœuf', 'reason': 'Une grillade pour évacuer la tension'},
        {'name': 'Jus de Bissap', 'reason': 'Une boisson rafraîchissante pour se calmer'}
    ],
    'surprise': [
        {'name': 'Kédjénou', 'reason': 'Un plat surprenant pour une humeur inattendue'},
        {'name': 'Foutou Sauce Graine', 'reason': 'Une découverte culinaire'},
        {'name': 'Tchakpalo', 'reason': 'Une boisson traditionnelle à essayer'}
    ],
    'neutral': [
        {'name': 'Attiéké Poisson', 'reason': 'Un équilibre parfait de saveurs'},
        {'name': 'Aloko', 'reason': 'Un accompagnement classique mais savoureux'},
        {'name': 'Jus de Gingembre', 'reason': 'Une boisson tonique pour rester éveillé'}
    ],
    'obese': [
        {'name': 'Salade César', 'reason': 'Option légère et équilibrée', 'calories': 350},
        {'name': 'Poisson Braisé', 'reason': 'Riche en protéines, faible en matières grasses', 'calories': 400},
        {'name': 'Dégui allégé', 'reason': 'Version légère du dessert traditionnel', 'calories': 200}
    ]
}

@app.route('/detect_mood', methods=['POST'])
def detect_mood():
    try:
        data = request.json
        image_data = data['image'].split(',')[1]  # Enlever le préfixe base64
        image_bytes = base64.b64decode(image_data)
        
        # Convertir en image OpenCV
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # Détecter le visage
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.1, 4)
        
        if len(faces) == 0:
            return jsonify({'error': 'Aucun visage détecté'}), 400
        
        # Analyser l'émotion
        result = DeepFace.analyze(img, actions=['emotion'], enforce_detection=False)
        
        if isinstance(result, list):
            result = result[0]
        
        emotion = result['dominant_emotion']
        confidence = result['emotion'][emotion]
        
        # Vérifier l'obésité (IMC approximatif)
        # Dans une vraie application, vous auriez besoin de plus de données
        is_obese = data.get('height') and data.get('weight')
        bmi = 0
        if is_obese:
            height = data['height'] / 100  # Convertir en mètres
            weight = data['weight']
            bmi = weight / (height * height)
            is_obese = bmi > 30
        
        # Obtenir les recommandations
        if is_obese:
            recommendations = menu_recommendations['obese']
            mood_category = 'obese'
        else:
            mood_category = emotion if emotion in menu_recommendations else 'neutral'
            recommendations = menu_recommendations[mood_category]
        
        return jsonify({
            'success': True,
            'emotion': emotion,
            'confidence': confidence,
            'bmi': bmi,
            'is_obese': is_obese,
            'recommendations': recommendations
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/detect_face', methods=['POST'])
def detect_face():
    try:
        data = request.json
        image_data = data['image'].split(',')[1]
        image_bytes = base64.b64decode(image_data)
        
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.1, 4)
        
        return jsonify({
            'success': True,
            'faces_detected': len(faces)
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)