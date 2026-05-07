<?php
// src/Controller/Api/ResetPasswordController.php

namespace App\Controller\Api;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Annotation\Route;

class ResetPasswordController extends AbstractController
{
    #[Route('/reset-password', name: 'app_reset_password_form', methods: ['GET'])]
    public function showResetForm(Request $request, EntityManagerInterface $em): Response
    {
        // Gestion de l'en-tête ngrok
        if ($request->headers->has('ngrok-skip-browser-warning')) {
            // On continue normalement
        }
        
        $token = $request->query->get('token');
        
        if (!$token) {
            return $this->redirect('https://e30c-2c0f-f698-c126-5c39-88e5-5df4-3413-200.ngrok-free.app');
        }
        
        // Vérifier si le token existe toujours (avec injection de doctrine)
        $user = $em->getRepository(User::class)->findOneBy(['resetToken' => $token]);
        
        if (!$user) {
            return new Response('
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <title>Token invalide</title>
                    <style>
                        body { font-family: Arial, sans-serif; background: #f5f5f5; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
                        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 400px; text-align: center; }
                        h1 { color: #FFB800; }
                        .error { color: red; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1>🔐 Smart Resto</h1>
                        <p class="error">❌ Ce lien de réinitialisation n\'est pas valide.</p>
                        <p>Il a peut-être déjà été utilisé ou a expiré.</p>
                        <p><a href="https://e30c-2c0f-f698-c126-5c39-88e5-5df4-3413-200.ngrok-free.app">Retour à l\'accueil</a></p>
                    </div>
                </body>
                </html>
            ');
        }
        
        // Vérifier l'expiration
        $now = new \DateTime();
        if ($user->getResetTokenExpiresAt() < $now) {
            return new Response('
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <title>Token expiré</title>
                    <style>
                        body { font-family: Arial, sans-serif; background: #f5f5f5; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
                        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 400px; text-align: center; }
                        h1 { color: #FFB800; }
                        .error { color: orange; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1>🔐 Smart Resto</h1>
                        <p class="error">⚠️ Ce lien a expiré.</p>
                        <p>Les liens de réinitialisation sont valables 1 heure.</p>
                        <p><a href="https://e30c-2c0f-f698-c126-5c39-88e5-5df4-3413-200.ngrok-free.app">Retour à l\'accueil</a></p>
                    </div>
                </body>
                </html>
            ');
        }
        
        // Affiche un formulaire HTML simple avec en-tête ngrok
        return new Response('
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Réinitialisation mot de passe - Smart Resto</title>
                <style>
                    body { font-family: Arial, sans-serif; background: #f5f5f5; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
                    .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 400px; width: 100%; }
                    h1 { color: #FFB800; text-align: center; }
                    input { width: 100%; padding: 12px; margin: 10px 0; border: 1px solid #ddd; border-radius: 5px; box-sizing: border-box; }
                    button { background: #FFB800; color: black; padding: 15px; border: none; border-radius: 5px; width: 100%; font-weight: bold; cursor: pointer; }
                    button:hover { background: #e6a600; }
                    .success { color: green; text-align: center; }
                    .error { color: red; text-align: center; }
                    .info { color: #666; text-align: center; font-size: 0.9em; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🔐 Smart Resto</h1>
                    <h2>Nouveau mot de passe</h2>
                    <form id="resetForm">
                        <input type="hidden" name="token" value="' . htmlspecialchars($token) . '">
                        <input type="password" name="password" id="password" placeholder="Nouveau mot de passe" required minlength="6">
                        <input type="password" name="confirmPassword" id="confirmPassword" placeholder="Confirmer le mot de passe" required minlength="6">
                        <button type="submit">CHANGER MON MOT DE PASSE</button>
                    </form>
                    <div id="message"></div>
                    <p class="info">Le mot de passe doit contenir au moins 6 caractères.</p>
                </div>
                <script>
                    document.getElementById("resetForm").addEventListener("submit", async function(e) {
                        e.preventDefault();
                        
                        const password = document.getElementById("password").value;
                        const confirmPassword = document.getElementById("confirmPassword").value;
                        const token = document.querySelector("input[name=\'token\']").value;
                        
                        if (password !== confirmPassword) {
                            document.getElementById("message").innerHTML = \'<p class="error">❌ Les mots de passe ne correspondent pas</p>\';
                            return;
                        }
                        
                        if (password.length < 6) {
                            document.getElementById("message").innerHTML = \'<p class="error">❌ Le mot de passe doit faire au moins 6 caractères</p>\';
                            return;
                        }
                        
                        try {
                            const response = await fetch("/api/reset-password", {
                                method: "POST",
                                headers: { 
                                    "Content-Type": "application/json",
                                    "ngrok-skip-browser-warning": "true"
                                },
                                body: JSON.stringify({
                                    token: token,
                                    password: password
                                })
                            });
                            
                            const data = await response.json();
                            
                            if (data.success) {
                                document.getElementById("message").innerHTML = \'<p class="success">✅ Mot de passe modifié avec succès !</p>\';
                                // Redirection vers l\'accueil après 3 secondes
                                setTimeout(() => { 
                                    window.location.href = "https://e30c-2c0f-f698-c126-5c39-88e5-5df4-3413-200.ngrok-free.app"; 
                                }, 3000);
                            } else {
                                document.getElementById("message").innerHTML = \'<p class="error">❌ \' + (data.error || "Erreur inconnue") + \'</p>\';
                            }
                        } catch (error) {
                            document.getElementById("message").innerHTML = \'<p class="error">❌ Erreur de connexion</p>\';
                        }
                    });
                </script>
            </body>
            </html>
        ');
    }

    #[Route('/api/reset-password', name: 'api_reset_password', methods: ['POST'])]
    public function resetPassword(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $passwordHasher): JsonResponse
    {
        try {
            $data = json_decode($request->getContent(), true);
            
            if (!isset($data['token']) || !isset($data['password'])) {
                return $this->json(['success' => false, 'error' => 'Token et mot de passe requis'], 400);
            }
            
            $token = $data['token'];
            $newPassword = $data['password'];
            
            if (strlen($newPassword) < 6) {
                return $this->json(['success' => false, 'error' => 'Le mot de passe doit contenir au moins 6 caractères'], 400);
            }
            
            $user = $em->getRepository(User::class)->findOneBy(['resetToken' => $token]);
            
            if (!$user) {
                return $this->json(['success' => false, 'error' => 'Token invalide'], 400);
            }
            
            $now = new \DateTime();
            if ($user->getResetTokenExpiresAt() < $now) {
                return $this->json(['success' => false, 'error' => 'Token expiré'], 400);
            }
            
            // Hasher le nouveau mot de passe
            $hashedPassword = $passwordHasher->hashPassword($user, $newPassword);
            $user->setPassword($hashedPassword);
            $user->setResetToken(null);
            $user->setResetTokenExpiresAt(null);
            
            $em->flush();
            
            return $this->json([
                'success' => true, 
                'message' => 'Mot de passe modifié avec succès'
            ]);
            
        } catch (\Exception $e) {
            return $this->json([
                'success' => false, 
                'error' => 'Erreur serveur: ' . $e->getMessage()
            ], 500);
        }
    }
}