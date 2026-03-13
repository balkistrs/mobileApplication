<?php
require 'vendor/autoload.php';

use Symfony\Component\Mailer\Transport;
use Symfony\Component\Mailer\Mailer;
use Symfony\Component\Mime\Email;

echo "🔧 TEST D'ENVOI D'EMAIL DIRECT\n";
echo "==============================\n\n";

$email = 'balkistrs@gmail.com';
$password = 'gvklauhcevbslfms'; // TON MOT DE PASSE D'APPLICATION ICI

echo "📧 Test avec :\n";
echo "   - Compte : balkistrs@gmail.com\n";
echo "   - Destinataire : $email\n";
echo "   - Mot de passe : " . substr($password, 0, 4) . "********\n\n";

// Test 1 : Connexion SMTP basique
echo "1️⃣ Test de connexion SMTP...\n";

$dsn = "gmail+smtp://balkistrs@gmail.com:$password@smtp.gmail.com:587?encryption=tls&auth_mode=login";

try {
    $transport = Transport::fromDsn($dsn);
    $mailer = new Mailer($transport);
    
    echo "   ✅ Connexion SMTP établie\n\n";
    
    // Test 2 : Envoi d'email
    echo "2️⃣ Envoi de l'email...\n";
    
    $emailMessage = (new Email())
        ->from('support@smartrestopro.com')
        ->to($email)
        ->subject('🔐 Test Smart Resto - ' . date('H:i:s'))
        ->text('Ceci est un test direct de configuration email.')
        ->html('<h1>Test réussi !</h1><p>Ta configuration email fonctionne parfaitement !</p>');
    
    $mailer->send($emailMessage);
    
    echo "   ✅ Email envoyé avec succès !\n";
    echo "\n🎉 BRAVO ! Vérifie ta boîte mail (et les spams) !\n";
    
} catch (Exception $e) {
    echo "   ❌ ERREUR : " . $e->getMessage() . "\n\n";
    
    // Analyse de l'erreur
    if (strpos($e->getMessage(), '535') !== false) {
        echo "🔍 DIAGNOSTIC :\n";
        echo "   - Code 535 = Authentification échouée\n";
        echo "   - Ton mot de passe d'application est invalide ou a expiré\n";
        echo "   - Génère un NOUVEAU mot de passe sur : https://myaccount.google.com/apppasswords\n";
    } elseif (strpos($e->getMessage(), '334') !== false) {
        echo "🔍 DIAGNOSTIC :\n";
        echo "   - Erreur d'authentification XOAUTH2\n";
        echo "   - Le mot de passe d'application n'est pas accepté\n";
    } elseif (strpos($e->getMessage(), 'Connection could not be established') !== false) {
        echo "🔍 DIAGNOSTIC :\n";
        echo "   - Problème de connexion réseau\n";
        echo "   - Vérifie que le port 587 n'est pas bloqué\n";
    }
}