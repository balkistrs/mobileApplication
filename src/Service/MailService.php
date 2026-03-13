<?php
// src/Service/MailService.php

namespace App\Service;

use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;

class MailService
{
    private MailerInterface $mailer;

    public function __construct(MailerInterface $mailer)
    {
        $this->mailer = $mailer;
    }
public function sendResetPasswordEmail(string $to, string $resetToken): bool
{
    try {
        // Lien vers ton application Flutter ou Symfony
        $resetLink = "https://e30c-2c0f-f698-c126-5c39-88e5-5df4-3413-200.ngrok-free.app/reset-password?token=" . $resetToken;
        
        $email = (new Email())
            ->from('balkistrs@gmail.com')
            ->to($to)
            ->subject('🔐 Réinitialisation de votre mot de passe - Smart Resto')
            ->html('
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <style>
                        body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
                        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                        h1 { color: #FFB800; }
                        .button { display: inline-block; background: #FFB800; color: black; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold; margin: 20px 0; }
                        .footer { margin-top: 30px; color: #666; font-size: 12px; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1>🔐 Smart Resto Pro</h1>
                        <h2>Réinitialisation de mot de passe</h2>
                        <p>Bonjour,</p>
                        <p>Vous avez demandé la réinitialisation de votre mot de passe.</p>
                        <p>Cliquez sur le bouton ci-dessous pour choisir un nouveau mot de passe :</p>
                        <div style="text-align: center;">
                            <a href="' . $resetLink . '" class="button">CRÉER UN NOUVEAU MOT DE PASSE</a>
                        </div>
                        <p>Ou copiez ce lien :<br>' . $resetLink . '</p>
                        <p>Ce lien est valable <strong>1 heure</strong>.</p>
                        <p>Si vous n\'avez pas demandé cette réinitialisation, ignorez cet email.</p>
                        <div class="footer">
                            <p>Smart Resto Pro - Votre application de restauration</p>
                        </div>
                    </div>
                </body>
                </html>
            ');
        
        $this->mailer->send($email);
        return true;
    } catch (\Exception $e) {
        error_log('❌ Erreur envoi email: ' . $e->getMessage());
        return false;
    }
}
    }